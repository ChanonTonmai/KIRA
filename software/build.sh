#!/bin/bash

# RISC-V Processing System Build Script
# Usage: ./build.sh [yaml_file] [output_dir]

set -e  # Exit on any error

# Define colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print with colored prefix
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Configuration with defaults
YAML_FILE=${1:-"dfg_config.yaml"}
OUTPUT_DIR=${2:-"build"}
FILELIST="${OUTPUT_DIR}/assembly_files.txt"
COMBINED_MEM="${OUTPUT_DIR}/combined_memory.mem"
VISUALIZATION="${OUTPUT_DIR}/dfg_visualization.png"

# Source files
DFG_PROCESSOR_SOURCE="dfg_processor.cpp"
ASSEMBLER_SOURCE="risc_v_assembler.cpp"

# Executable names
DFG_PROCESSOR_BIN="dfg_processor"
ASSEMBLER_BIN="risc_v_assembler"

# Check if required Python packages are installed
check_python_dependencies() {
    info "Checking Python dependencies..."
    python3 -c "import yaml, networkx, matplotlib, numpy" 2>/dev/null || {
        error "Missing required Python packages. Please install them using:
        pip3 install pyyaml networkx matplotlib numpy"
    }
}

# Check if YAML file exists
if [ ! -f "$YAML_FILE" ]; then
    error "YAML configuration file '$YAML_FILE' not found!"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR" || error "Failed to create output directory: $OUTPUT_DIR"

info "Build configuration:"
info "- YAML Config: $YAML_FILE"
info "- Output Directory: $OUTPUT_DIR"

# Check Python dependencies
check_python_dependencies

# Step 1: Compile the tools if needed
if [ ! -f "$DFG_PROCESSOR_BIN" ] || [ "$DFG_PROCESSOR_SOURCE" -nt "$DFG_PROCESSOR_BIN" ]; then
    info "Compiling DFG Processor..."
    g++ -O3 -o "$DFG_PROCESSOR_BIN" "$DFG_PROCESSOR_SOURCE" -lyaml-cpp || error "Failed to compile DFG Processor"
    success "DFG Processor compiled successfully"
else
    info "DFG Processor is up to date"
fi

if [ ! -f "$ASSEMBLER_BIN" ] || [ "$ASSEMBLER_SOURCE" -nt "$ASSEMBLER_BIN" ]; then
    info "Compiling RISC-V Assembler..."
    g++ -O3 -o "$ASSEMBLER_BIN" "$ASSEMBLER_SOURCE" || error "Failed to compile RISC-V Assembler"
    success "RISC-V Assembler compiled successfully"
else
    info "RISC-V Assembler is up to date"
fi

# Step 2: Generate assembly files
info "Generating assembly files from $YAML_FILE..."
./"$DFG_PROCESSOR_BIN" "$YAML_FILE" "$OUTPUT_DIR" || error "Failed to generate assembly files"
success "Assembly files generated"

# Step 3: Create file list for assembler
info "Creating assembly file list..."
find "$OUTPUT_DIR" -name "pe*_assembly.s" > "$FILELIST" || error "Failed to create file list"
ASSEMBLY_COUNT=$(wc -l < "$FILELIST")
if [ "$ASSEMBLY_COUNT" -eq 0 ]; then
    warn "No assembly files found!"
else
    success "Found $ASSEMBLY_COUNT assembly files"
fi

# Step 4: Run the assembler 
info "Assembling files..."
./"$ASSEMBLER_BIN" "$FILELIST" "$OUTPUT_DIR" || error "Failed to assemble code"

# Step 5: Generate DFG visualization
info "Generating DFG visualization..."
python3 visualize_dfg.py "$YAML_FILE" "$VISUALIZATION" "$OUTPUT_DIR" || error "Failed to generate DFG visualization"
success "DFG visualization generated at: $VISUALIZATION"

# Step 6: Verify outputs
if [ -f "$COMBINED_MEM" ]; then
    INSTR_COUNT=$(grep -v "^//" "$COMBINED_MEM" | grep -v "^$" | wc -l)
    success "Assembly complete: $INSTR_COUNT instructions in combined memory file"
else
    warn "Combined memory file not found: $COMBINED_MEM"
fi

# Summary
echo 
echo -e "${GREEN}=== Build Summary ===${NC}"
echo "YAML configuration: $YAML_FILE"
echo "Output directory: $OUTPUT_DIR"
echo "Assembly files: $ASSEMBLY_COUNT"
if [ -f "$COMBINED_MEM" ]; then
    echo "Instructions: $INSTR_COUNT"
fi
echo "DFG visualization: $VISUALIZATION"
echo
success "Build process completed successfully"

# Optional: Add timing information
if [ -n "$SECONDS" ]; then
    echo "Build time: $(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds"
fi