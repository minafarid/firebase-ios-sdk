/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <FirebaseCore/FIRLogger.h>
#import <Foundation/NSObject.h>
#import <GRPCClient/GRPCCall+ChannelArg.h>
#import <GRPCClient/GRPCCall+Tests.h>
#import <XCTest/XCTest.h>

//#import "FIRFieldPath.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Public/FIRFirestoreSettings.h"

#import "FIRApp.h"
#import "FIRCollectionReference.h"
#import "FIRDocumentReference.h"
#import "FIRDocumentSnapshot.h"
#import "FIRQuerySnapshot.h"

#import "Firestore/Source/Core/FSTQuery.h"
//#import "Firestore/Source/Public/FIRFirestore.h"
#import "Firestore/Source/Remote/FSTBufferedWriter.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"

#include "LibFuzzer/FuzzerDefs.h"
#include "LibFuzzer/FuzzerIO.h"

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::remote::Serializer;

namespace {

// Global static objects. Initialized before fuzzing starts.
static Serializer *serializer;
static FIRFirestore *firestore;
static FSTBufferedWriter *writer;
static FSTUserDataConverter *converter;
static NSMutableSet *processedStrings;

enum FuzzingTarget {
  SERIALIZER = 0,
  FIELD_PATH = 1,
  FIELD_VALUE = 2,
  COLLECTION_REFERENCE = 3,
  FIRQUERY = 4,
  BACKEND = 5
};

static FuzzingTarget fuzzing_target = SERIALIZER;

FIRFirestore *GetFriendlyEatsFirestore() {
  if (firestore != nil) {
    return firestore;
  }
  [FIRApp configure];
  firestore = [FIRFirestore firestore];
  FIRFirestoreSettings *settings = [firestore settings];
  settings.timestampsInSnapshotsEnabled = @YES;
  firestore.settings = settings;
  return firestore;
}

FIRFirestore *GetTestFirestore() {
  static FIRFirestore *sharedInstance = nil;
  static dispatch_once_t onceToken;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRFirestore alloc] initWithProjectID:"abc"
                                                    database:"abc"
                                              persistenceKey:@"db123"
                                         credentialsProvider:nil
                                         workerDispatchQueue:nil
                                                 firebaseApp:nil];
  });
#pragma clang diagnostic pop
  return sharedInstance;
}

FIRFirestoreSettings *settings() {
  FIRFirestoreSettings *settings = [[FIRFirestoreSettings alloc] init];
  NSString *host = [[NSProcessInfo processInfo] environment][@"DATASTORE_HOST"];
  settings.sslEnabled = YES;
  if (!host) {
    // If host is nil, there is no GoogleService-Info.plist. Check if a hexa integration test
    // configuration is configured. The first bundle location is used by bazel builds. The
    // second is used for github clones.
    host = @"localhost:8081";
    settings.sslEnabled = YES;
    NSLog(@"Bundle path = %@", [[NSBundle mainBundle] bundlePath]);
    NSString *certsPath =
        [[NSBundle mainBundle] pathForResource:@"PlugIns/Firestore_FuzzTests_iOS.xctest/CAcert"
                                        ofType:@"pem"];
    if (certsPath == nil) {
      NSLog(@"Cannot connect to Hexa machine: unable to find CAcert.pem file");
      throw std::exception();
    }

    unsigned long long fileSize =
        [[[NSFileManager defaultManager] attributesOfItemAtPath:certsPath error:nil] fileSize];

    if (fileSize == 0) {
      NSLog(
          @"The cert is not properly configured. Make sure setup_integration_tests.py "
           "has been run.");
    }
    [GRPCCall useTestCertsPath:certsPath testName:@"test_cert_2" forHost:host];
  }
  settings.host = host;
  settings.persistenceEnabled = YES;
  settings.timestampsInSnapshotsEnabled = YES;
  NSLog(@"Configured integration test for %@ with SSL: %@", settings.host,
        settings.sslEnabled ? @"YES" : @"NO");
  return settings;
}

FIRFirestore *GetHexaFirestore() {
  NSString *persistenceKey = @"fuzzing-db-1";

  FSTDispatchQueue *workerDispatchQueue = [FSTDispatchQueue
      queueWith:dispatch_queue_create("com.google.firebase.firestore", DISPATCH_QUEUE_SERIAL)];

  FIRSetLoggerLevel(FIRLoggerLevelDebug);
  // HACK: FIRFirestore expects a non-nil app, but for tests we cheat.
  FIRApp *app = nil;
  std::unique_ptr<CredentialsProvider> credentials_provider =
      absl::make_unique<firebase::firestore::auth::EmptyCredentialsProvider>();

  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:util::MakeStringView(@"fuzzing")
                                                           database:DatabaseId::kDefault
                                                     persistenceKey:persistenceKey
                                                credentialsProvider:std::move(credentials_provider)
                                                workerDispatchQueue:workerDispatchQueue
                                                        firebaseApp:app];

  firestore.settings = settings();

  //[_firestores addObject:firestore];
  return firestore;
}

// Fuzz-test the deserialization process in Firestore. The Serializer reads raw
// bytes and converts them to a model object.
void FuzzTestDeserialization(const uint8_t *data, size_t size) {
  @try {
    serializer->DecodeFieldValue(data, size);
  } @catch (...) {
  }

  @
  try {
    serializer->DecodeMaybeDocument(data, size);
  } @catch (...) {
  }
}

// Fuzz-test creating a FieldPath reference.
void FuzzTestFieldPath(const uint8_t *data, size_t size) {
  @autoreleasepool {
    // Convert the bytes to a string with UTF-8 format.
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    @try {
      NSArray *stringArray = [NSArray arrayWithObjects:string, nil];
      FIRFieldPath *fp1 = [[FIRFieldPath alloc] initWithFields:stringArray];
    } @catch (NSException *exception) {
    }

    @
    try {
      FIRFieldPath *fp2 = [FIRFieldPath pathWithDotSeparatedString:string];
    } @catch (NSException *exception) {
    }
  }
}

// Fuzz-test CollectionReference.
void FuzzTestCollectionReference(const uint8_t *data, size_t size) {
  @autoreleasepool {
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    @try {
      FIRCollectionReference *col1 = [firestore collectionWithPath:string];
    } @catch (...) {
    }

    @
    try {
      FIRDocumentReference *doc1 = [firestore documentWithPath:string];
    } @catch (...) {
    }
  }
}

// Fuzz-test FIRQuery.
void FuzzTestFIRQuery(const uint8_t *data, size_t size) {
  //  @autoreleasepool {
  NSData *d = [NSData dataWithBytes:data length:size];
  NSString *string =
      [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];
  NSArray *stringArray =
      [string componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                       characterSetWithCharactersInString:@".,_ "]];
  if ([string length] == 0) return;
  try {
    FIRFieldPath *fp = [[FIRFieldPath alloc] initWithFields:stringArray];
    @try {
      ResourcePath resource_path = ResourcePath::FromString(util::MakeStringView(string));
      FSTQuery *fst_q = [FSTQuery queryWithPath:resource_path];
      FIRQuery *fir_q = [FIRQuery referenceWithQuery:fst_q firestore:firestore];

      NSPredicate *predicate = [NSPredicate predicateWithFormat:string];
      FIRQuery *q0 = [fir_q queryFilteredUsingPredicate:predicate];

      FIRQuery *q1 = [fir_q queryWhereField:string isEqualTo:string];
      FIRQuery *q2 = [fir_q queryWhereField:string isGreaterThan:string];
      FIRQuery *q3 = [fir_q queryWhereField:string isGreaterThanOrEqualTo:string];
      FIRQuery *q4 = [fir_q queryWhereField:string isLessThan:string];
      FIRQuery *q5 = [fir_q queryWhereField:string isLessThanOrEqualTo:string];
      FIRQuery *q6 = [fir_q queryOrderedByField:string];
      FIRQuery *q7 = [fir_q queryLimitedTo:d.hash];
      FIRQuery *q8 = [fir_q queryWhereField:string arrayContains:@([string hash])];

      FIRQuery *q1_ = [fir_q queryWhereFieldPath:fp isEqualTo:string];
      FIRQuery *q2_ = [fir_q queryWhereFieldPath:fp isGreaterThan:string];
      FIRQuery *q3_ = [fir_q queryWhereFieldPath:fp isGreaterThanOrEqualTo:string];
      FIRQuery *q4_ = [fir_q queryWhereFieldPath:fp isLessThan:string];
      FIRQuery *q5_ = [fir_q queryWhereFieldPath:fp isLessThanOrEqualTo:string];
      FIRQuery *q6_ = [fir_q queryOrderedByFieldPath:fp];
      // q7 N/A.
      FIRQuery *q8_ = [fir_q queryWhereFieldPath:fp arrayContains:@([string hash])];
    } @catch (id ex) {
      // NSLog(@"Something happened. %@", [ex reason]);
    }
  } catch (const std::exception &e) {
    // Catch artificial exception.
  } catch (...) {
  }
  //  }
}

// Fuzz-test FieldValue.
NSArray *GetPossibleValuesForBytes(const uint8_t *data, size_t size) {
  NSMutableArray *vals = [[NSMutableArray alloc] init];

  // Convert to NSData.
  NSData *bytes = [NSData dataWithBytes:data length:size];

  // Try casting to an NSDictionary.
  NSDictionary *dict =
      [NSJSONSerialization JSONObjectWithData:bytes options:NSJSONReadingMutableLeaves error:nil];

  // TODO: Post-process strings with a prefix "DATE" and convert
  // them to a Date.

  if (dict != nil) {
    [vals addObject:dict];
  }

  // Try casting to an array.
  NSArray *arr = [NSKeyedUnarchiver unarchiveObjectWithData:bytes];
  if (arr != nil && [arr count] > 0) {
    [vals addObject:arr];
  }

  // Cast as a string.
  NSString *str = [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];

  if (str != nil && [str length] > 0) {
    [vals addObject:str];
  }

  // Cast as an integer -> use hash value of the data.
  [vals addObject:@([bytes hash])];

  // Cast as a double -> divide hash value by size.
  [vals addObject:@([bytes hash] / size)];

  return vals;
}

NSArray *InterpretUsingFirstByte(uint8_t first_byte, const uint8_t *data, size_t size) {
  NSMutableArray *vals = [[NSMutableArray alloc] init];
  uint8_t number_conditions = 4;
  switch (first_byte % number_conditions) {
      // Number.
    case 0:
      [vals addObject:[NSNumber numberWithUnsignedChar:*data]];
      break;
    case 1:
      NSLog(@"Integer");
      break;
    case 2:
      NSLog(@"Blob");
      break;
    case 3:
      NSLog(@"Date");
      break;
    default:
      break;
  }
  return vals;
}

NSArray *FieldValueInterpreter(const uint8_t *original_data, size_t original_size) {
  if (original_size < 2) return nil;

  // Extract the first byte in the byte array to guide interpretation.
  uint8_t first_byte = original_data[0];

  // Skip the first byte.
  const uint8_t *data = (const_cast<uint8_t *>(original_data)) + 1;
  size_t size = original_size - 1;

  NSArray *vals = GetPossibleValuesForBytes(original_data, original_size);
  // InterpretUsingFirstByte(first_byte, data, size);

  return vals;
}

void FuzzTestFieldValue(const uint8_t *data, size_t size) {
  @autoreleasepool {
    @try {
      NSArray *vals = FieldValueInterpreter(data, size);
      for (id val in vals) {
        @try {
          [converter parsedQueryValue:val];
        } @catch (...) {
        }

        if ([val isKindOfClass:[NSDictionary class]]) {
          @try {
            [converter parsedSetData:val];
          } @catch (...) {
          }

          @
          try {
            [converter parsedMergeData:val fieldMask:nil];
          } @catch (...) {
          }

          @
          try {
            [converter parsedUpdateData:val];
          } @catch (...) {
          }
        }
      }
    } @catch (NSException *exception) {
      // NSLog(@"Exception caught: %@", [exception reason]);
    }
  }
}

void FuzzTestQuerying(const uint8_t *data, size_t size) {
  // Cast data as an NSString.
  NSString *string =
      [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];
  if (string == nil) {
    return;
  }

  NSData *bytes = [NSData dataWithBytes:data length:size];
  // NSLog(@"Bytes (%ld) = %@ String = %@", size, [bytes description], string);

  // Fixed collection.
  FIRCollectionReference *col = [firestore collectionWithPath:@"fuzzing"];

  // Initialize all expectations as an array.
  NSMutableArray *expectations = [NSMutableArray array];

  /*/ ---------------------------------------------------------------------------
  @try {
    // Test 1: Get document with the string path.
    XCTestExpectation *doc_ex = [[XCTestExpectation alloc]
  initWithDescription:@"document_reference"]; FIRDocumentReference *doc = [restaurants
  documentWithPath:string]; [expectations addObject:doc_ex]; [doc
  getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      //NSLog(@"document exists? %d", [snapshot exists]);
      [doc_ex fulfill];
    }];
  } @catch (...) {}
  //*/

  /* ---------------------------------------------------------------------------
  @try {
    // Test 2: Create document with the data, retrieve it, then delete it.
   NSDictionary *dictionary=[NSJSONSerialization
       JSONObjectWithData:bytes
       options:NSJSONReadingMutableLeaves
       error:nil];
    if (dictionary) {
      NSLog(@"^^^ writing doc ^^^");
      // Create a new doc reference with auto id.
      FIRDocumentReference *new_doc = [col documentWithAutoID];

      XCTestExpectation *new_ex = [[XCTestExpectation alloc] initWithDescription:@"create_doc"];
      [expectations addObject:new_ex];
      [new_doc setData:dictionary completion:^(NSError * _Nullable error) {
        [new_ex fulfill];
      }];

      XCTestExpectation *query_ex = [[XCTestExpectation alloc] initWithDescription:@"query_doc"];
      [expectations addObject:query_ex];
      [new_doc getDocumentWithSource:FIRFirestoreSourceServer completion:^(FIRDocumentSnapshot *
  _Nullable snapshot, NSError * _Nullable error) { [query_ex fulfill];
      }];

      XCTestExpectation *delete_ex = [[XCTestExpectation alloc] initWithDescription:@"delete_doc"];
      [expectations addObject:delete_ex];
      [new_doc deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        [delete_ex fulfill];
      }];
    }
  } @catch (...) {}
  //*///------------------------------------------------------------------------

  /*-------------------------------------------------------- queryOrderByField
  @try {
    XCTestExpectation *query_ex = [[XCTestExpectation alloc] initWithDescription:@"querying"];
    [expectations addObject:query_ex];
    [[restaurants queryOrderedByField:string]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error)
  { [query_ex fulfill];
     }
     ];
  } @catch (...) {}
  //*///------------------------------------------------------------------------

  //*-------------------------------------------------------- collectionWithPath
  @try {
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@"col_ex"];
    FIRCollectionReference *col = [firestore collectionWithPath:string];
    FIRDocumentReference *doc = [col documentWithAutoID];
    [expectations addObject:ex];
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      [ex fulfill];
      NSLog(@"1. collectionWithPath snapshot exists? %d", snapshot.exists ? 1 : 0);
    }];
  } @catch (NSException *e) {
    // NSLog(@"1. exception: %@", [e reason]);
  } @catch (...) {
    // NSLog(@"1. Something went really wrong");
  }
  //*///------------------------------------------------------------------------

  //*---------------------------------------------------------- documentWithPath
  @
  try {
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@"doc_ex"];
    FIRDocumentReference *doc = [col documentWithPath:string];
    [expectations addObject:ex];
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      [ex fulfill];
      NSLog(@"2. Document exists? %d", snapshot.exists ? 1 : 0);
    }];
  } @catch (NSException *e) {
    // NSLog(@"2. exception: %@", [e reason]);
  } @catch (...) {
    // NSLog(@"2. Something went really wrong");
  }
  //*///------------------------------------------------------------------------

  //*---------------------------------- documentWithPath directly from firestore
  @
  try {
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@"doc_ex2"];
    [expectations addObject:ex];
    [[firestore documentWithPath:string]
        getDocumentWithCompletion:^(FIRDocumentSnapshot *_Nullable snapshot,
                                    NSError *_Nullable error) {
          [ex fulfill];
          NSLog(@"3. Document exists? %d", snapshot.exists ? 1 : 0);
        }];
  } @catch (NSException *e) {
    // NSLog(@"3. exception: %@", [e reason]);
  } @catch (...) {
    // NSLog(@"3. Something went really wrong");
  }
  //*///------------------------------------------------------------------------

  Boolean string_contains_null = NO;
  for (int i = 0; i < size; i++) {
    if (data[i] == 0x00) {
      string_contains_null = YES;
    }
  }

  //*-----------------------------------------------------------
  if (!string_contains_null) {
    @try {
      XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@"q1_ex"];
      [expectations addObject:ex];
      [[col queryWhereField:string isEqualTo:string]
          getDocumentsWithCompletion:^(FIRQuerySnapshot *_Nullable snapshot,
                                       NSError *_Nullable error) {
            [ex fulfill];

            NSLog(@"4. query = nil");
          }];
    } @catch (NSException *e) {
      // NSLog(@"4. exception: %@", [e reason]);
    } @catch (...) {
      // NSLog(@"4 Something went really wrong");
    }
  }
  //*///------------------------------------------------------------------------

  XCTWaiterResult waiterResult =
      [XCTWaiter waitForExpectations:expectations timeout:5 enforceOrder:NO];
  NSLog(@"Waiter result = %ld", (long)waiterResult);
}

// Contains the code to be fuzzed. Called by the fuzzing library with
// different argument values for `data` and `size`.
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  switch (fuzzing_target) {
    case SERIALIZER:
      FuzzTestDeserialization(data, size);
      break;
    case FIELD_PATH:
      FuzzTestFieldPath(data, size);
      break;
    case FIELD_VALUE:
      FuzzTestFieldValue(data, size);
      break;
    case COLLECTION_REFERENCE:
      FuzzTestCollectionReference(data, size);
      break;
    case FIRQUERY:
      FuzzTestFIRQuery(data, size);
      break;
    case BACKEND:
      FuzzTestQuerying(data, size);
      break;
    default:
      NSLog(@"Error - invalid fuzzing target: %ud", fuzzing_target);
      break;
  }

  return 0;
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
int RunFuzzTestingMain() {
  // Get dictionary file path from resources and convert to a program argument.
  NSString *plugins_path = [[NSBundle mainBundle] builtInPlugInsPath];

  NSString *dict_location = @"Firestore_FuzzTests_iOS.xctest/FuzzingResources";

  switch (fuzzing_target) {
    case SERIALIZER:
      dict_location = [dict_location stringByAppendingPathComponent:@"Serializer/serializer.dictionary"]
      break;
    case FIELD_PATH:
      FuzzTestFieldPath(data, size);
      break;
    case FIELD_VALUE:
      FuzzTestFieldValue(data, size);
      break;
    case COLLECTION_REFERENCE:
      FuzzTestCollectionReference(data, size);
      break;
    case FIRQUERY:
      FuzzTestFIRQuery(data, size);
      break;
    case BACKEND:
      FuzzTestQuerying(data, size);
      break;
    default:
      NSLog(@"Error - invalid fuzzing target: %@", fuzzing_target);
      return 0;
  }


   =
  ;
  NSString *dict_path = [plugins_path stringByAppendingPathComponent:dict_location];
  const char *dict_arg = [[NSString stringWithFormat:@"-dict=%@", dict_path] UTF8String];

  // Get corpus and convert to a program argument.
  NSString *corpus_location = @"FuzzTestsCorpus";
  NSString *corpus_path = [plugins_path stringByAppendingPathComponent:corpus_location];
  const char *corpus_arg = [corpus_path UTF8String];

  NSLog(@"plugins_path = %@", plugins_path);
  NSLog(@"dict_path = %@", dict_path);
  NSLog(@"corpus_location = %@", corpus_path);

  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc.
  char *program_args[] = {
      // First arg is program name.
      const_cast<char *>("RunFuzzTestingMain"),
      // Write crashing inputs to /tmp/.
      const_cast<char *>("-artifact_prefix=/tmp/"),
      // No memory limit for libFuzzer.
      const_cast<char *>("-rss_limit_mb=0"),
      // Treat some new values as new coverage.
      const_cast<char *>("-use_value_profile=0"),
      // Print stats at exit.
      const_cast<char *>("-print_final_stats=1"),
      // Max size should be high to generate large input.
      const_cast<char *>("-max_len=100000000"),

      // const_cast<char *>("-detect_leaks=0"),  // disable outside testing ---.

      // Only ASCII.
      // const_cast<char *>("-only_ascii=1"),

      // Limit the runs/time to collect coverage statistics.
      const_cast<char *>("-runs=1000"),
      // const_cast<char *>("-max_total_time=10"),

      const_cast<char *>(dict_arg),              // Dictionary arg.
      const_cast<char *>(corpus_arg)             // Corpus must be the last arg.


      // Use a dictionary and a corpus.
      // Serialization
      // const_cast<char
      // *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/serialization.dict"),
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/BinaryProtos")

      // Querying backend.
      // const_cast<char
      // *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/"
      //                   "FuzzTests/Corpus/Backend/backend.dictionary"),
      // const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/"
      //                   "FuzzTests/Corpus/Backend/Inputs")
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Backend/CrashingInputs/release-nonexistent-query-no-nulls")
      // const_cast<char *>("/tmp/crash-5ba93c9db0cff93f52b521d7420e43f6eda2784f")

      // FIRQuery.
      // const_cast<char
      // *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/firquery.dict"),
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/Inputs")

      // FieldPath
      // const_cast<char
      // *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/fieldpath.dict"),
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/Inputs")

      // FieldVlaue.
      // const_cast<char *>([[@"-dict=" stringByAppendingString:dictionaryFilePath] UTF8String]),
      /// Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/fv.dict"),
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/Inputs")

      // Run specific individual crashes.
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/01-SEGV")
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/02-StackOverflow")
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/03-StackBufferOverflow")
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/04-SIGABRT")
      // const_cast<char
      // *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/CrashingInputs/01-NSPredicate-flex_scanner_jammed")
  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);

  // Initialize static objects.
  DatabaseId database_id{"project", DatabaseId::kDefault};
  serializer = new Serializer(database_id);

  // Firestore connection.
  // [FIRApp configure];
  //firestore =
      // GetTestFirestore();
      // GetFriendlyEatsFirestore();
      //GetHexaFirestore();

  // User data converter. No modification to the original input.
  converter = [[FSTUserDataConverter alloc] initWithDatabaseID:&database_id
                                                  preConverter:^id _Nullable(id _Nullable input) {
                                                    return input;
                                                  }];

  // cache
  processedStrings = [NSMutableSet set];

  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
}

void RunSingleTesting() {
  // Configure Firestore.
  [FIRApp configure];
  FIRFirestore *firestore = [FIRFirestore firestore];
  FIRFirestoreSettings *settings = [firestore settings];
  settings.timestampsInSnapshotsEnabled = @YES;
  firestore.settings = settings;

  FIRCollectionReference *restaurants = [firestore collectionWithPath:@"restaurants"];

  XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@"query"];
  [[firestore collectionWithPath:@"restaurants"]
      getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        NSLog(@"************** RETURNED ***********");
        if (error != nil) {
          NSLog(@"Error getting documents: %@", error);
        } else {
          NSLog(@"*************************");
          for (FIRDocumentSnapshot *document in snapshot.documents) {
            NSLog(@"%@ => %@", document.documentID, document.data);
          }
          NSLog(@"*************************");
        }
        [ex fulfill];
      }];

  FIRDocumentReference *docRef =
      [[firestore collectionWithPath:@"restaurants"] documentWithPath:@"HQuh3J5vFzaOGIcLvot9"];
  [docRef getDocumentWithSource:FIRFirestoreSourceServer
                     completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
                       if (snapshot != NULL) {
                         // The document data was found in the cache.
                         NSLog(@"Cached document data: %@", snapshot.data);
                       } else {
                         // The document data was not found in the cache.
                         NSLog(@"Document does not exist in cache: %@", error);
                       }
                     }];

  NSArray *expectations = [NSArray arrayWithObject:ex];
  [XCTWaiter waitForExpectations:expectations timeout:2];
}

}  // namespace

/**
 * This class is registered as the NSPrincipalClass in the
 * Firestore_FuzzTests_iOS bundle's Info.plist. XCTest instantiates this class
 * to perform one-time setup for the test bundle, as documented here:
 *
 *   https://developer.apple.com/documentation/xctest/xctestobservationcenter
 */
@interface FSTFuzzTestsPrincipal : NSObject
@end

@implementation FSTFuzzTestsPrincipal

- (instancetype)init {
  self = [super init];
  RunFuzzTestingMain();
  // RunSingleTesting();
  return self;
}

@end
