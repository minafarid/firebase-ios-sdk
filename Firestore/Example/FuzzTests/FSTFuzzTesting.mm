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

#import <Foundation/Foundation.h>

#import "fuzz_test.h"

#import "Firestore/Source/API/FSTUserDataConverter.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"

using firebase::firestore::model::DatabaseId;

@implementation FuzzTesting

+ (void)validateParsedData:(id)fv originalData:(NSData *)data {
  if (![fv isKindOfClass:[FSTFieldValue class]]) {
    NSLog(@"Crash!");
    NSLog(@"Data bytes length = %lu. Data = %@", [data length], data);
    __builtin_trap();
  }
}

+ (void)testFuzzingUserDataConverter:(NSData *)data {
  @autoreleasepool {
    // Create UserDataConverter object to be used with different data types.
    static DatabaseId database_id{"project", DatabaseId::kDefault};

    // Do not modify the input data; no-op converter.
    FSTUserDataConverter *converter =
        [[FSTUserDataConverter alloc] initWithDatabaseID:&database_id
                                            preConverter:^id _Nullable(id _Nullable input) {
                                              return input;
                                            }];

    @try {
      // Parse as a String and validate.
      id str = [FuzzTesting testFuzzingUserDataConverter_NSString:data withConverter:converter];
      [FuzzTesting validateParsedData:str originalData:data];

      // Parse as a Dictionary and validate.
      id dict =
          [FuzzTesting testFuzzingUserDataConverter_NSDictionary:data withConverter:converter];
      [FuzzTesting validateParsedData:dict originalData:data];

      // Parse as an Array and validate.
      id arr = [FuzzTesting testFuzzingUserDataConverter_NSArray:data withConverter:converter];
      [FuzzTesting validateParsedData:arr originalData:data];

    } @catch (NSException *exception) {
      // NSLog(@"Exception: %@", exception.reason);
    }
  }
}

+ (id)testFuzzingUserDataConverter_NSString:(NSData *)data
                              withConverter:(FSTUserDataConverter *)converter {
  NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  id fv = [converter parsedQueryValue:dataStr];
  return fv;
}

+ (id)testFuzzingUserDataConverter_NSArray:(NSData *)data
                             withConverter:(FSTUserDataConverter *)converter {
  NSArray *dataArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  id fv = [converter parsedQueryValue:dataArray];
  return fv;
}

+ (id)testFuzzingUserDataConverter_NSDictionary:(NSData *)data
                                  withConverter:(FSTUserDataConverter *)converter {
  NSError *error;
  NSDictionary *dataDict =
      [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
  id fv = [converter parsedQueryValue:dataDict];
  return fv;
}

@end
