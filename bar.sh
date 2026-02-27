#!/bin/bash

# Default configuration
N_R=4
N_C=4
CL=2
GRID_DIV=8
MODULE="riscv_grid_top"
OPERATION_TYPE="conv"
SOURCE_NAME=""
ARB_POLICY=0

# source name for second state (if needed)
SOURCE_NAME_2=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE_NAME="$2"
            shift 2
            ;;
        -r|--n_r)
            N_R="$2"
            shift 2
            ;;
        -c|--n_c)
            N_C="$2"
            shift 2
            ;;
        -g|--grid-div)
            GRID_DIV="$2"
            shift 2
            ;;
        -m|--module)
            MODULE="$2"
            shift 2
            ;;
        -arb|--arb-policy)
            ARB_POLICY="$2"
            shift 2
            ;;
        -cl|--cluster)
            CL="$2"
            shift 2
            ;;
        -ot|--operation-type)
            OPERATION_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -s|--source <source_file_name> [options]"
            echo "Required:"
            echo "  -s, --source <name>      Source file name (without .vn extension)"
            echo "Options:"
            echo "  -r, --n_r <value>        Number of rows (default: 4)"
            echo "  -c, --n_c <value>        Number of columns (default: 4)"
            echo "  -g, --grid-div <value>   Grid division (default: 8)"
            echo "  -m, --module <name>      Module name (default: riscv_grid_top)"
            echo "  -cl, --cluster <value>   Cluster value (default: 2)"
            echo "  -ot, --operation-type <type> Operation type (default: conv)"
            echo "  -arb, --arb-policy <value> Arb policy (default: 0) 0 --> Round Robin, 1 --> Priority min"
            echo "  -h, --help               Show this help message"
            echo "Example: $0 -s test -r 4 -c 4"
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if source name is provided
if [ -z "$SOURCE_NAME" ]; then
    echo "Error: Source file name is required"
    echo "Usage: $0 -s|--source <source_file_name> [options]"
    echo "Use -h or --help for more information"
    exit 1
fi

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HARDWARE_DIR="${SCRIPT_DIR}/hardware/vert"
SOFTWARE_DIR="${SCRIPT_DIR}/software"

# Get the source file name without extension
SOURCE_FILE="${SCRIPT_DIR}/software/venus_src/${SOURCE_NAME}.vn"
YAML_OUTPUT="${SCRIPT_DIR}/software/dfg_yaml/dfg_${SOURCE_NAME}.yaml"
OUTPUT_DIR="${SCRIPT_DIR}/software/output/output_${SOURCE_NAME}"

# Function to run simulation
run_simulation() {
    local folder=$1
    local grid_div=$2
    local n_r=$3
    local n_c=$4
    local module=$5
    local op_type=$6
    local cl=$7

    echo "Running simulation with:"
    echo "  Folder: ${folder}"
    echo "  Grid Div: ${grid_div}"
    echo "  N_R: ${n_r}"
    echo "  N_C: ${n_c}"
    echo "  Module: ${module}"
    echo "  Operation: ${op_type}"
    echo "  Cluster: ${cl}"

    # Change to hardware directory and run simulation
    cd "${HARDWARE_DIR}"
    ./run_simulation.sh -f "${folder}" -g "${grid_div}" -r "${n_r}" -c "${n_c}" -m "${module}" -ot "${op_type}" -cl "${cl}" -arb "${ARB_POLICY}"
    local sim_result=$?
    cd "${SCRIPT_DIR}"
    return $sim_result
}

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file $SOURCE_FILE does not exist"
    exit 1
fi

# Create output directories if they don't exist
mkdir -p "${SCRIPT_DIR}/software/dfg_yaml"
mkdir -p "${SCRIPT_DIR}/software/output"

# Remove the output directory if it exists
rm -rf "$YAML_OUTPUT"
rm -rf "$OUTPUT_DIR"

# Step 1: Compile using Venus
echo "Step 1: Compiling $SOURCE_FILE..."

# Get the base name (everything before the last underscore)
base_name="${SOURCE_NAME%_*}"
# Get the suffix (everything after the last underscore)
suffix="_${SOURCE_NAME##*_}"
first_name="${SOURCE_NAME%%_*}"
echo "Original string: $SOURCE_NAME"
echo "Base name: $base_name"
echo "Suffix: $suffix"
echo "First name: $first_name"

# Check if source file exists
python software/VeNus/venus/cli/main.py "$SOURCE_FILE" -o "$YAML_OUTPUT"
if [[ "$first_name" == "2mm" ]]; then
    str2="_2"
    SOURCE_NAME_2=$base_name$str2
    SOURCE_FILE_2="${SCRIPT_DIR}/software/venus_src/${SOURCE_NAME_2}.vn"
    YAML_OUTPUT_2="${SCRIPT_DIR}/software/dfg_yaml/dfg_${SOURCE_NAME_2}.yaml"
    OUTPUT_DIR_2="${SCRIPT_DIR}/software/output/output_${SOURCE_NAME_2}"
    python software/VeNus/venus/cli/main.py "$SOURCE_FILE_2" -o "$YAML_OUTPUT_2"
    cd "${SCRIPT_DIR}/software"
    ./build.sh "$YAML_OUTPUT_2" "$OUTPUT_DIR_2"
    if [ $? -ne 0 ]; then
        echo "Error: Build failed"
        exit 1
    fi
fi



# Check if compilation was successful
if [ $? -ne 0 ]; then
    echo "Error: Compilation failed"
    exit 1
fi

# Step 2: Build using build.sh
cd "${SCRIPT_DIR}/software"
echo "Step 2: Building with $YAML_OUTPUT..."
./build.sh "$YAML_OUTPUT" "$OUTPUT_DIR"

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

cd "${SCRIPT_DIR}"

# Step 3: Run simulation
echo "Step 3: Running simulation..."
run_simulation "$OUTPUT_DIR" "$GRID_DIV" "$N_R" "$N_C" "$MODULE" "$OPERATION_TYPE" "$CL"

# Check if simulation was successful
if [ $? -ne 0 ]; then
    echo "Error: Simulation failed"
    exit 1
fi

echo "Process completed successfully!"
echo "Output directory: $OUTPUT_DIR"