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

#include "LibFuzzer/FuzzerDefs.h"
//#include "fuzz_test.h"

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"

#include "absl/types/optional.h"


using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::Status;

namespace {

void FuzzTestSerialization(const uint8_t *data, size_t size) {
  DatabaseId database_id{"project", DatabaseId::kDefault};
  Serializer *serializer = new Serializer(database_id);

  @try {
    //NSLog(@"Going to decode...");
    // StatusOr<FieldValue> decoding_status =
    serializer->DecodeFieldValue(data, size);
    //NSLog(@"Decoding status: %@ (code = %d)", decoding_status.ok()? @"OK" : @"NOT OK", decoding_status.status().code());
  } @catch (NSException *exception) {
    NSLog(@"DecodeFieldValue -  Caught exception: %@", exception.reason);
  }

  @try {
    //serializer->DecodeMaybeDocument(data, size);
  } @catch (NSException *exception) {
    NSLog(@"DecodeMaybeDocument - Caught exception: %@", exception.reason);
  }
}

// Contains the code to be fuzzed. Called by the fuzzing library with
// different argument values for `data` and `size`.
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  FuzzTestSerialization(data, size);
  return 0;
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
int RunFuzzTestingMain() {
  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc.
  char *program_args[] = {
    const_cast<char *>("RunFuzzTestingMain"),  // First argument is program name.
    const_cast<char *>("-artifact_prefix=/tmp/"),  // Write crashing inputs to /tmp/.

    // Serialization Corpus.
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/Corpus/Serialization/BinaryProtos")

    // Individual crashes.
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/01-SEGV")
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/02-StackOverflow")
    //const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/03-StackBufferOverflow")
    const_cast<char *>("/Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Example/FuzzTests/CrashingInputs/04-SIGABRT")
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
