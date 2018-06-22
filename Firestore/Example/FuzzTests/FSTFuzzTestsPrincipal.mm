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

//#import "FIRFieldPath.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"

#import "FIRApp.h"
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
    NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    if ([string length] == 0) return;
    try {
      @try {
        ResourcePath resource_path = ResourcePath::FromString(util::MakeStringView(string));
        FSTQuery *fst_q = [FSTQuery queryWithPath:resource_path];
        FIRQuery *fir_q = [FIRQuery referenceWithQuery:fst_q firestore:firestore];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:string];
        FIRQuery *q0 = [fir_q queryFilteredUsingPredicate:predicate];

        //FIRQuery *q1 = [fir_q queryWhereField:string isEqualTo:string];
        //FIRQuery *q2 = [fir_q queryWhereField:string isGreaterThan:string];
        //FIRQuery *q3 = [fir_q queryWhereField:string isGreaterThanOrEqualTo:string];
        //FIRQuery *q4 = [fir_q queryWhereField:string isLessThan:string];
        FIRQuery *q5 = [fir_q queryWhereField:string isLessThanOrEqualTo:string];
        FIRQuery *q6 = [fir_q queryOrderedByField:string];
        FIRQuery *q7 = [fir_q queryLimitedTo:d.hash];
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

  // Try casting as an NSDictionary.
  NSDictionary *dict=[NSJSONSerialization
                            JSONObjectWithData:bytes
                            options:NSJSONReadingMutableLeaves
                            error:nil];
  if (dict != nil) {
    [vals addObject:dict];
  }

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
      FSTFieldValue *fv = [converter parsedQueryValue:val];
    }
  } @catch (NSException *exception) {
    //NSLog(@"Exception caught: %@", [exception reason]);
  }
}
}

//  // Fuzz-test buffered writer
//void FuzzTestBufferedWriter(const uint8_t *data, size_t size) {
//  NSData *d = [NSData dataWithBytes:data length:size];
//  [writer writeValue:d];
//}

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
      const_cast<char *>("-use_value_profile=1"),
      // Print stats at exit.
      const_cast<char *>("-print_final_stats=1"),

      // Limit the runs/time to collect coverage statistics.
      //const_cast<char *>("-runs=1000000"),
      //const_cast<char *>("-max_total_time=100"),

      // Use a dictionary and a corpus.
      // Serialization
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/serialization.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/BinaryProtos")

      // FieldPath
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/fieldpath.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/Inputs")

      // FIRQuery.
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/firquery.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FIRQuery/Inputs")

      // FieldVlaue.
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/fv.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/Inputs")
      const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldValue/Inputs/01-dict")

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

  // User data converter. No modification to the original input.
  converter = [[FSTUserDataConverter alloc]
                    initWithDatabaseID:&database_id
                    preConverter:^id _Nullable(id _Nullable input) {
                      return input;
                    }];

  // Configure Firestore connection.
  //[FIRApp configure];
  //firestore = [FIRFirestore firestore];
  firestore = FSTTestFirestore();

  // FSTBufferedWriter object.
  // writer = [[FSTBufferedWriter alloc] init];
  // [writer setState:GRXWriterStateStarted];

  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
}

void RunSingleTesting() {
  //{0x52, 0x01, 0x8a, 0x8a, 0x01, 0x48};
  /*
  DatabaseId database_id{"p", "d"};
  Serializer *serializer = new Serializer(database_id);
  std::vector<uint8_t> bytes
      //{0x8a, 0x01}; // used to crash - fixed wrong api call to close stream.
      {0x52};
      //{0x52, 0x01, 0x8a, 0x8a, 0x01, 0x48};
  //fuzzer::Unit U = fuzzer::FileToVector("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/02-StackOverflow");
  //serializer->DecodeFieldValue(U.data(), U.size());
  serializer->DecodeFieldValue(bytes);

  //serializer->DecodeMaybeDocument(bytes);
  */

  /*
  NSString *string = @"__name__";
  ResourcePath resource_path = ResourcePath::FromString(util::MakeStringView(@"field.subfield"));
  FSTQuery *fst_q = [FSTQuery queryWithPath:resource_path];
  FIRQuery *fir_q = [FIRQuery referenceWithQuery:fst_q firestore:firestore];
  FIRQuery *fir_q1 = [fir_q queryWhereField:string isEqualTo:string];
   */

  /*
  @try {
    NSLog(@"trying predicate 0...:");
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"0 = a"];
  } @catch (NSException *exception) {
    NSLog(@"0 Crash: %@", [exception reason]);
  }

  @try {
    NSLog(@"trying predicate 1...:");
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ssf awy && ss *"];
  } @catch (NSException *exception) {
    NSLog(@"1 Crash: %@", [exception reason]);
  }

  @try {
    NSLog(@"trying predicate 2...:");
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"`/\\"];
  } @catch (NSException *exception) {
    NSLog(@"2 Crash: %@", [exception reason]);
  }
  */

  NSString* str = @"teststring";
  NSData *bytesData = [str dataUsingEncoding:NSUTF8StringEncoding];
  DatabaseId database_id{"project", DatabaseId::kDefault};
  converter = [[FSTUserDataConverter alloc]
               initWithDatabaseID:&database_id
               preConverter:^id _Nullable(id _Nullable input) {
                 return input;
               }];
  //id value = @1;
  FSTFieldValue *fv = [converter parsedQueryValue:bytesData];
  NSLog(@"fv = %@", fv);
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
