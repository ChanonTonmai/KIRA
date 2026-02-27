#!/bin/bash

# Default values
N_R=4
N_C=4
CL=2
FOLDER_NAME="output_cmsis_l1_8x4"
GRID_DIV=8
MODULE="riscv_grid_top"  # Default module
OPERATION_TYPE="conv"
ARB_POLICY=1
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--n_r)
            N_R="$2"
            shift 2
            ;;
        -c|--n_c)
            N_C="$2"
            shift 2
            ;;
        -f|--folder)
            FOLDER_NAME="$2"
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
        -cl|--cluster)
            CL="$2"
            shift 2
            ;;
        -ot|--operation-type)
            OPERATION_TYPE="$2"
            shift 2
            ;;
        -arb|--arb-policy)
            ARB_POLICY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Print configuration
echo "Running simulation with:"
echo "N_R = $N_R"
echo "N_C = $N_C"
echo "Folder = $FOLDER_NAME"
echo "Grid division = $GRID_DIV"
echo ""

# Run make with specified parameters
echo "Building with Verilator..."
if [[ "$MODULE" == "riscv_grid_top" ]]; then
    make sandwish MODULE=riscv_grid_top N_R=$N_R N_C=$N_C
else
    make toast MODULE=riscv_scalable CL=$CL N_R=$N_R N_C=$N_C
fi


# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Run the simulation
echo "Running simulation..."
echo "MODULE: $MODULE"
echo "FOLDER_NAME: $FOLDER_NAME"
echo "GRID_DIV: $GRID_DIV"
echo "OPERATION_TYPE: $OPERATION_TYPE"  
if [[ "$MODULE" == "riscv_grid_top" ]]; then
    ./obj_dir/Vriscv_grid_top $FOLDER_NAME $GRID_DIV $OPERATION_TYPE $ARB_POLICY
else
    ./obj_dir/Vriscv_scalable $FOLDER_NAME $GRID_DIV $OPERATION_TYPE $ARB_POLICY
fi

# Check if simulation was successful
if [ $? -ne 0 ]; then
    echo "Simulation failed!"
    exit 1
fi

echo "Simulation completed successfully!"