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

//#import "FIRFieldPath.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"

#import "FIRApp.h"
#import "FIRDocumentReference.h";
#import "FIRCollectionReference.h"
#import "FIRDocumentSnapshot.h"
#import "FIRQuerySnapshot.h"
#import "FIRFirestoreSettings.h"
#import "Firestore/Source/Core/FSTQuery.h"
//#import "Firestore/Source/Public/FIRFirestore.h"
#import "Firestore/Source/Remote/FSTBufferedWriter.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"

#include "LibFuzzer/FuzzerDefs.h"
#include "LibFuzzer/FuzzerIO.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::remote::Serializer;

namespace {

// Global static objects. Initialized before fuzzing starts.
static Serializer *serializer;
static FIRFirestore *firestore;
static FSTBufferedWriter *writer;
static FSTUserDataConverter *converter;

FIRFirestore *FSTTestFirestore() {
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

// Fuzz-test the deserialization process in Firestore. The Serializer reads raw
// bytes and converts them to a model object.
void FuzzTestDeserialization(const uint8_t *data, size_t size) {
  @try {
    serializer->DecodeFieldValue(data, size);
  } @catch (...) {}

  @try {
    serializer->DecodeMaybeDocument(data, size);
  } @catch (...) {}
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
    } @catch (NSException *exception) {}

    @try {
      FIRFieldPath *fp2 = [FIRFieldPath pathWithDotSeparatedString:string];
    } @catch (NSException *exception) {}
  }
}

// Fuzz-test CollectionReference.
void FuzzTestCollectionReference(const uint8_t *data, size_t size) {
  @autoreleasepool {
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    @try {
      FIRCollectionReference *col1 = [firestore collectionWithPath:string];
    } @catch (...) {}

    @try {
      FIRDocumentReference *doc1 = [firestore documentWithPath:string];
    } @catch (...) {}
  }
}

// Fuzz-test FIRQuery.
void FuzzTestFIRQuery(const uint8_t *data, size_t size) {
//  @autoreleasepool {
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *string = [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];
    NSArray *stringArray = [string componentsSeparatedByCharactersInSet:
                            [NSCharacterSet characterSetWithCharactersInString:@".,_ "]];
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
      } @catch(id ex) {
        //NSLog(@"Something happened. %@", [ex reason]);
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
  NSDictionary *dict=[NSJSONSerialization
                            JSONObjectWithData:bytes
                            options:NSJSONReadingMutableLeaves
                            error:nil];

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
  NSString *str =
    [[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding];

  if (str != nil && [str length] > 0) {
    [vals addObject:str];
  }

  // Cast as an integer -> use hash value of the data.
  [vals addObject:@([bytes hash])];

  // Cast as a double -> divide hash value by size.
  [vals addObject:@([bytes hash]/size)];

  return vals;
}

NSArray *InterpretUsingFirstByte(uint8_t first_byte, const uint8_t *data, size_t size) {
  NSMutableArray *vals = [[NSMutableArray alloc] init];
  uint8_t number_conditions = 4;
  switch (first_byte % number_conditions) {
      // Number.
    case 0:
      [vals addObject: [NSNumber numberWithUnsignedChar:*data]];
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
  if (original_size < 2)
    return nil;

  // Extract the first byte in the byte array to guide interpretation.
  uint8_t first_byte = original_data[0];

  // Skip the first byte.
  const uint8_t *data = (const_cast<uint8_t *>(original_data)) + 1;
  size_t size = original_size - 1;

  NSArray *vals =
    GetPossibleValuesForBytes(original_data, original_size);
    //InterpretUsingFirstByte(first_byte, data, size);

  return vals;
}

void FuzzTestFieldValue(const uint8_t *data, size_t size) {
  @autoreleasepool {
    @try {
      NSArray *vals = FieldValueInterpreter(data, size);
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
    } @catch (NSException *exception) {
      //NSLog(@"Exception caught: %@", [exception reason]);
    }
  }
}

// Contains the code to be fuzzed. Called by the fuzzing library with
// different argument values for `data` and `size`.
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  //FuzzTestDeserialization(data, size);
  //FuzzTestFieldPath(data, size);
  //FuzzTestCollectionReference(data, size);
  //FuzzTestFIRQuery(data, size);
  FuzzTestFieldValue(data, size);
  //FuzzTestBufferedWriter(data, size);  // Doesn't work.
  return 0;
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
int RunFuzzTestingMain() {

  // Get the dictionary file.
  NSString *dictionaryFilePath = [[[NSBundle mainBundle] resourcePath]
       stringByAppendingPathComponent:@"PlugIns/Firestore_FuzzTests_iOS.xctest/fv.dictionary"];

  const char *dictArg = [[[NSString
                        stringWithCString:"-dict="
                        encoding:NSUTF8StringEncoding]
                       stringByAppendingString:dictionaryFilePath] UTF8String];

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
      const_cast<char *>("-use_value_profile=1")  ,
      // Print stats at exit.
      const_cast<char *>("-print_final_stats=1"),
      // Max size should be high to generate large input.
      const_cast<char *>("-max_len=10000"),

      // Only ASCII.
      //const_cast<char *>("-only_ascii=1"),

      // Limit the runs/time to collect coverage statistics.
      //const_cast<char *>("-runs=1000000"),
      const_cast<char *>("-max_total_time=100"),

      // Use a dictionary and a corpus.
      // Serialization
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/serialization.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/BinaryProtos")

      // FIRQuery.
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/firquery.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/Inputs")

      // FieldPath
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/fieldpath.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/Inputs")

      // FieldVlaue.
      const_cast<char *>([[@"-dict=" stringByAppendingString:dictionaryFilePath] UTF8String]),
                         ///Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/fv.dict"),
      const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/Inputs")

      // Run specific individual crashes.
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/01-SEGV")
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/02-StackOverflow")
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/03-StackBufferOverflow")
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/04-SIGABRT")
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/CrashingInputs/01-NSPredicate-flex_scanner_jammed")
  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);

  // Initialize static objects.
  DatabaseId database_id{"project", DatabaseId::kDefault};
  serializer = new Serializer(database_id);

  // Firestore connection.
  firestore = FSTTestFirestore();

  // User data converter. No modification to the original input.
  converter = [[FSTUserDataConverter alloc]
                    initWithDatabaseID:&database_id
                    preConverter:^id _Nullable(id _Nullable input) {
                      return input;
                    }];

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
  [XCTWaiter waitForExpectations:expectations timeout:10];
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
  //RunSingleTesting();
  return self;
}

@end
