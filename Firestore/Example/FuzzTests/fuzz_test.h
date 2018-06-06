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

#ifndef FIRESTORE_FUZZ_TEST_H
#define FIRESTORE_FUZZ_TEST_H

#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "FIRFirestore.h"

@interface FuzzTesting : NSObject


+ (FIRFirestore *) getFirestore;

//---------- UserDataConverter Fuzz Testing ------------------------------------
+ (void)testFuzzingUserDataConverter:(NSData *)data;

+ (void)validateParsedData:(id)fv originalData:(NSData *)data;

+ (id)testFuzzingUserDataConverter_NSString:(NSData *)data
                              withConverter:(FSTUserDataConverter *)converter;

+ (id)testFuzzingUserDataConverter_NSArray:(NSData *)data
                             withConverter:(FSTUserDataConverter *)converter;

+ (id)testFuzzingUserDataConverter_NSDictionary:(NSData *)data
                                  withConverter:(FSTUserDataConverter *)converter;

//---------- General Fuzz Testing ----------------------------------------------

+ (void)testFuzzFIRQuery:(NSData *) data;

//---------- Serialization Fuzz Testing ----------------------------------------
+ (void)testFuzzFIRQuery:(NSData *) data;

@end

#endif /* FIRESTORE_FUZZ_TEST_H */
