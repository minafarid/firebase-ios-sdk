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

// Global serializer object. Initialized before fuzzing starts.
static Serializer *serializer;

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

void FuzzTestFirestore(const uint8_t *data, size_t size) {
  [FIRFirestore]
}
  
// Fuzz-test CollectionReference.
void FuzzTestCollectionReference(const uint8_t *data, size_t size) {
  @autoreleasepool {
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    @try {
      const ResourcePath path = ResourcePath::FromString(util::MakeStringView(string));
      FIRCollectionReference *ref = [FIRCollectionReference referenceWithPath:path firestore:nil];

      FIRDocumentReference *doc1 = [ref documentWithPath:string];
      FIRDocumentReference *doc2 = [ref documentWithAutoID];
    } @catch (NSException *exception) {}
  }
}

// Contains the code to be fuzzed. Called by the fuzzing library with
// different argument values for `data` and `size`.
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  //FuzzTestDeserialization(data, size);
  //FuzzTestFieldPath(data, size);
  FuzzTestCollectionReference(data, size);
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
      //const_cast<char *>("-runs=1000000"),
      //const_cast<char *>("-max_total_time=30"),
      // Jobs and workers.
      // const_cast<char *>("-jobs=4"), const_cast<char *>("-workers=4"),
      // Print stats at exit.
      const_cast<char *>("-print_final_stats=1"),
      // Use the following Dictionary and corpus.
      // Serialization
      //const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/serialization.dict"),
      //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/BinaryProtos")

      // FieldPath
      const_cast<char *>("-dict=/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/fieldpath.dict"),
      const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/FieldPath/Inputs")

    // Individual crashes.
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/01-SEGV")
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/02-StackOverflow")
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/03-StackBufferOverflow")
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/04-SIGABRT")


  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);

  // Initialize the main serializer object.
  DatabaseId database_id{"project", DatabaseId::kDefault};
  serializer = new Serializer(database_id);

  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
}

void RunSingleTesting() {
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
