#!/bin/bash

# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Directory that contains the text protos to convert to binary.
text_protos_dir="$PWD/TextProtos"
binary_protos_dir="$PWD/BinaryProtos"
echo "Converting text proto files in directory: $text_protos_dir"
echo "Writing binary proto files to directory: $binary_protos_dir"
# Go to project root directory.
cd ../../../../../

# Run proto conversion command for each file content.
for text_proto_file in $text_protos_dir/*
do
  file_content=`cat $text_proto_file`
  file_name=$(basename -- "$text_proto_file")
  message_type="Value"
  if [[ $file_name == doc-* ]]; then
    message_type="Document"
  elif [[ $file_name == fv-* ]]; then
    message_type="Value"
  elif [[ $file_name == arr-* ]]; then
    message_type="ArrayValue"
  elif [[ $file_name == map-* ]]; then
    message_type="MapValue"
  fi
  echo "Converting file: $file_name (type: $message_type)"
  # TODO(minafarid): choose proper encoding based on file_name prefix.
  echo "$file_content" \
    | ./build/external/protobuf/src/protobuf-build/src/protoc \
    -I./Firestore/Protos/protos \
    -I./build/external/protobuf/src/protobuf/src \
    --encode=google.firestore.v1beta1."$message_type" \
    google/firestore/v1beta1/document.proto \
    | tee "$binary_protos_dir"/"$file_name" > /dev/null
done
