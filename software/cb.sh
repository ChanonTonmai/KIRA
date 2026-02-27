#!/bin/bash

# Check if input file name is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <source_file_name>"
    echo "Example: $0 test"
    exit 1
fi

# Get the source file name without extension
SOURCE_NAME=$1
SOURCE_FILE="venus_src/${SOURCE_NAME}.vn"
YAML_OUTPUT="dfg_yaml/dfg_${SOURCE_NAME}.yaml"
OUTPUT_DIR="output/output_${SOURCE_NAME}"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file $SOURCE_FILE does not exist"
    exit 1
fi

# Create output directories if they don't exist
mkdir -p dfg_yaml
mkdir -p output

# Remove the output directory if it exists
rm -rf "$YAML_OUTPUT"
rm -rf "$OUTPUT_DIR"

# Compile using Venus
echo "Compiling $SOURCE_FILE..."
python VeNus/venus/cli/main.py "$SOURCE_FILE" -o "$YAML_OUTPUT"

# Check if compilation was successful
if [ $? -ne 0 ]; then
    echo "Error: Compilation failed"
    exit 1
fi

# Build using build.sh
echo "Building with $YAML_OUTPUT..."
./build.sh "$YAML_OUTPUT" "$OUTPUT_DIR"

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

echo "Process completed successfully!"
echo "Output directory: $OUTPUT_DIR" 