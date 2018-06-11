#!/bin/bash

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
  echo "Converting file: $file_name"
  # TODO(minafarid): choose proper encoding based on file_name prefix.
  echo "$file_content" \
    | ./build/external/protobuf/src/protobuf-build/src/protoc \
    -I./Firestore/Protos/protos \
    -I./build/external/protobuf/src/protobuf/src \
    --encode=google.firestore.v1beta1.Value \
    google/firestore/v1beta1/document.proto \
    | tee "$binary_protos_dir"/"$file_name" > /dev/null
done
