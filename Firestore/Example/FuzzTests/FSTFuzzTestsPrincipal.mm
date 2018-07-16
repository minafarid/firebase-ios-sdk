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

#import <Foundation/NSObject.h>
#import <XCTest/XCTest.h>

// From pods.
#import <FirebaseCore/FIRLogger.h>
#import <GRPCClient/GRPCCall+Tests.h>

#include "LibFuzzer/FuzzerDefs.h"

// Public.
#import "FIRApp.h"
#import "FIRCollectionReference.h"
#import "FIRDocumentReference.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Public/FIRDocumentSnapshot.h"
#import "Firestore/Source/Public/FIRFirestoreSettings.h"
#import "Firestore/Source/Public/FIRQuerySnapshot.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

// Internal.
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

// C++.
#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::Serializer;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::model::ResourcePath;

namespace {

enum FuzzingTarget {
  SERIALIZER = 0,
  FIELD_PATH = 1,
  FIELD_VALUE = 2,
  COLLECTION_REFERENCE = 3,
  FIRQUERY = 4,
  BACKEND = 5
};

static FuzzingTarget fuzzing_target = BACKEND;

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

// Fuzz test FieldValue.
void FuzzTestFieldValue(const uint8_t *data, size_t size) {
  @autoreleasepool {
    DatabaseId database_id{"project", DatabaseId::kDefault};
    FSTUserDataConverter *converter = [[FSTUserDataConverter alloc]
                                       initWithDatabaseID:&database_id
                                       preConverter:^id _Nullable(id _Nullable input) {
                                         return input;
                                       }];
    @try {
      NSArray *vals = GetPossibleValuesForBytes(data, size);
      for (id val in vals) {
        @try {
          [converter parsedQueryValue:val];
        } @catch (...) {}

        if ([val isKindOfClass:[NSDictionary class]]) {
          @try {
            [converter parsedSetData:val];
          } @catch (...) {}

          @try {
            [converter parsedMergeData:val fieldMask:nil];
          } @catch (...) {}

          @try {
            [converter parsedUpdateData:val];
          } @catch (...) {}
        }
      }
    } @catch (...) {}
  }
}

// Creates a FIRFirestoreSettings object that connects to a remote Hexa machine
// with credentials that are retrieved from a local CAcert.pem file, similar to
// the integration tests.
FIRFirestoreSettings *FirestoreHexaSettings() {
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

// Creates an instance of FIRFirestore that connects to a Hexa machine, similar
// to integration tests.
FIRFirestore *GetHexaFirestore() {
  NSString *persistenceKey = @"fuzzing-db-1";

  FSTDispatchQueue *workerDispatchQueue = [FSTDispatchQueue
                                           queueWith:dispatch_queue_create("com.google.firebase.firestore", DISPATCH_QUEUE_SERIAL)];

  FIRSetLoggerLevel(FIRLoggerLevelDebug);
  // HACK: FIRFirestore expects a non-nil app, but for tests we cheat.
  FIRApp *app = nil;
  std::unique_ptr<CredentialsProvider> credentials_provider =
  absl::make_unique<firebase::firestore::auth::EmptyCredentialsProvider>();

  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:firebase::firestore::util::MakeStringView(@"fuzzing")
                                                           database:DatabaseId::kDefault
                                                     persistenceKey:persistenceKey
                                                credentialsProvider:std::move(credentials_provider)
                                                workerDispatchQueue:workerDispatchQueue
                                                        firebaseApp:app];

  firestore.settings = FirestoreHexaSettings();

  //[_firestores addObject:firestore];
  return firestore;
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
    } @catch (...) {}

    @try {
      FIRFieldPath *fp2 = [FIRFieldPath pathWithDotSeparatedString:string];
    } @catch (...) {}
  }
}

// Fuzz test creating collection reference.
void FuzzTestCollectionReference(const uint8_t *data, size_t size) {
  static FIRFirestore *firestore = GetHexaFirestore();
  @autoreleasepool {
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    @try {
      FIRCollectionReference *col1 = [firestore collectionWithPath:string];
    } @catch (...) {
    }

    @try {
      FIRDocumentReference *doc1 = [firestore documentWithPath:string];
    } @catch (...) {
    }
  }
}

// Fuzz-test the deserialization process in Firestore. The Serializer reads raw
// bytes and converts them to a model object.
void FuzzTestDeserialization(const uint8_t *data, size_t size) {
  Serializer serializer{DatabaseId{"project", DatabaseId::kDefault}};

  @autoreleasepool {
    @try {
      serializer.DecodeFieldValue(data, size);
    } @catch (...) {
      // Caught exceptions are ignored because the input might be malformed and
      // the deserialization might throw an error as intended. Fuzzing focuses on
      // runtime errors that are detected by the sanitizers.
    }

    @try {
      serializer.DecodeMaybeDocument(data, size);
    } @catch (...) {
      // Ignore caught exceptions.
    }
  }
}

void FuzzTestFIRQuery(const uint8_t *data, size_t size) {
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
      ResourcePath resource_path = ResourcePath::FromString(firebase::firestore::util::MakeStringView(string));
      FSTQuery *fst_q = [FSTQuery queryWithPath:resource_path];
      FIRQuery *fir_q = [FIRQuery referenceWithQuery:fst_q firestore:nil];

      NSPredicate *predicate = [NSPredicate predicateWithFormat:string];
      FIRQuery *q0 = [fir_q queryFilteredUsingPredicate:predicate];

      FIRQuery *q1 = [fir_q queryWhereField:string isEqualTo:string];
      FIRQuery *q2 = [fir_q queryWhereField:string isGreaterThan:string];
      FIRQuery *q3 = [fir_q queryWhereField:string isGreaterThanOrEqualTo:string];
      FIRQuery *q4 = [fir_q queryWhereField:string isLessThan:string];
      FIRQuery *q5 = [fir_q queryWhereField:string isLessThanOrEqualTo:string];
      FIRQuery *q6 = [fir_q queryOrderedByField:string];
      FIRQuery *q7 = [fir_q queryLimitedTo:d.hash];

      FIRQuery *q1_ = [fir_q queryWhereFieldPath:fp isEqualTo:string];
      FIRQuery *q2_ = [fir_q queryWhereFieldPath:fp isGreaterThan:string];
      FIRQuery *q3_ = [fir_q queryWhereFieldPath:fp isGreaterThanOrEqualTo:string];
      FIRQuery *q4_ = [fir_q queryWhereFieldPath:fp isLessThan:string];
      FIRQuery *q5_ = [fir_q queryWhereFieldPath:fp isLessThanOrEqualTo:string];
      FIRQuery *q6_ = [fir_q queryOrderedByFieldPath:fp];
      // q7 N/A.
    } @catch (id ex) {
      // NSLog(@"Something happened. %@", [ex reason]);
    }
  } catch (const std::exception &e) {
    // Catch artificial exception.
  } catch (...) {
  }
}


void FuzzTestBackend(const uint8_t *data, size_t size) {
  static FIRFirestore *firestore = GetHexaFirestore();
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

  //*/ ---------------------------------------------------------------------------
  @try {
    // Test 1: Get document with the string path.
    XCTestExpectation *doc_ex = [[XCTestExpectation alloc] initWithDescription:@"document_reference"];
    FIRDocumentReference *doc = [col documentWithPath:string]; [expectations addObject:doc_ex];
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      [doc_ex fulfill];
    }];
  } @catch (...) {}
  //*/

  /* ---------------------------------------------------------------------------
  @try {
    // Test 2: Create document with the data, retrieve it, then delete it.
    NSDictionary *dictionary=[NSJSONSerialization JSONObjectWithData:bytes
                                                             options:NSJSONReadingMutableLeaves
                                                               error:nil];
    if (dictionary) {
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
    [[col queryOrderedByField:string]
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
      FuzzTestBackend(data, size);
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

  NSString *resources_location = @"Firestore_FuzzTests_iOS.xctest/FuzzingResources";
  NSString *dict_location;
  NSString *corpus_location;

  switch (fuzzing_target) {
    case SERIALIZER:
      dict_location = [resources_location stringByAppendingPathComponent:@"Serializer/serializer.dictionary"];
      corpus_location = @"FuzzTestsCorpus";
      break;
    case COLLECTION_REFERENCE:  // Uses FieldPath for now.
    case FIELD_PATH:
      dict_location = [resources_location stringByAppendingPathComponent:@"FieldPath/fieldpath.dictionary"];
      corpus_location = [resources_location stringByAppendingPathComponent:@"FieldPath/Corpus"];
      break;
    case FIELD_VALUE:
      dict_location = [resources_location stringByAppendingPathComponent:@"FieldValue/fieldvalue.dictionary"];
      corpus_location = [resources_location stringByAppendingPathComponent:@"FieldValue/Corpus"];
      break;
    case FIRQUERY:
      dict_location = [resources_location stringByAppendingPathComponent:@"FIRQuery/firquery.dictionary"];
      corpus_location = [resources_location stringByAppendingPathComponent:@"FIRQuery/Corpus"];
      break;
    case BACKEND:
      dict_location = [resources_location stringByAppendingPathComponent:@"Backend/backend.dictionary"];
      corpus_location = [resources_location stringByAppendingPathComponent:@"Backend/Corpus"];
      break;
    default:
      NSLog(@"Error - invalid fuzzing target: %ud", fuzzing_target);
      return 0;
  }

  // Convert dictionary and corpus locations into paths and program arguments.
  NSString *dict_path = [plugins_path stringByAppendingPathComponent:dict_location];
  NSString *corpus_path = [plugins_path stringByAppendingPathComponent:corpus_location];

  const char *dict_arg = [[NSString stringWithFormat:@"-dict=%@", dict_path] UTF8String];
  const char *corpus_arg = [corpus_path UTF8String];

  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc. The FuzzerDriver of
  // libFuzzer expects the non-const argument 'char ***argv' and it does not
  // modify it throughout the method.
  char *program_args[] = {
      const_cast<char *>("RunFuzzTestingMain"),      // 1st arg is program name.
      const_cast<char *>("-artifact_prefix=/tmp/"),  // Write crashes to /tmp.
      const_cast<char *>("-rss_limit_mb=0"),         // No memory limit.
      const_cast<char *>("-use_value_profile=1"),
      const_cast<char *>("-print_final_stats=1"),
      const_cast<char *>("-max_len=1000000"),
      //const_cast<char *>("-runs=100"),
      // const_cast<char *>("-max_total_time=10"),
      const_cast<char *>(dict_arg),                  // Dictionary arg.
      const_cast<char *>(corpus_arg)                 // Corpus arg must be last.
  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);



  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
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
  return self;
}

@end
