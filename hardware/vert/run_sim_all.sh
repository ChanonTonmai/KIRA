# ./run_simulation.sh -f output_cmsis_l1_4x4 -g 8 -r 4 -c 4 -m riscv_grid_top -ot conv
# ./run_simulation.sh -f output_cmsis_l1_8x4 -g 16 -r 8 -c 4 -m riscv_grid_top -ot conv
# ./run_simulation.sh -f output_cmsis_l1_8x8 -g 32 -r 8 -c 8 -m riscv_grid_top -ot conv

# ./run_simulation.sh -f output_cmsis_l1_8x4 -g 8 -r 4 -c 4 -m riscv_scale_top -cl 2 -ot conv
# ./run_simulation.sh -f output_cmsis_l1_8x8 -g 8 -r 4 -c 4 -m riscv_scale_top -cl 4 -ot conv

# ./run_simulation.sh -f output_gemm_64x64_4x4 -g 8 -r 4 -c 4 -m riscv_grid_top -ot gemm
# ./run_simulation.sh -f output_gemm_64x64_8x4 -g 16 -r 8 -c 4 -m riscv_grid_top -ot gemm
# ./run_simulation.sh -f output_gemm_64x64_8x8 -g 32 -r 8 -c 8 -m riscv_grid_top -ot gemm

# ./run_simulation.sh -f output_gemm_64x64_8x4 -cl 2 -g 8 -m riscv_scalable -ot gemm
# ./run_simulation.sh -f output_gemm_64x64_8x8 -cl 4 -g 8 -m riscv_scalable -ot gemm


#!/bin/bash

# Exit on error
set -e

# Configuration
LOG_DIR="./logs"
REPORT_DIR="./rpt"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/simulation_${TIMESTAMP}.log"
SUMMARY_FILE="${LOG_DIR}/summary_${TIMESTAMP}.txt"
ERROR_FILE="${LOG_DIR}/errors_${TIMESTAMP}.txt"

# Create necessary directories
mkdir -p ${LOG_DIR}
mkdir -p ${REPORT_DIR}

# Function to log messages
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a ${LOG_FILE}
}

# Function to log errors
log_error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo "$message" | tee -a ${ERROR_FILE} ${LOG_FILE}
}

# Function to log summary
log_summary() {
    echo "$1" | tee -a ${SUMMARY_FILE} ${LOG_FILE}
}

# Function to run a single simulation
run_simulation() {
    local folder=$1
    local grid_div=$2
    local n_r=$3
    local n_c=$4
    local module=$5
    local cluster=$6
    local op_type=$7
    local sim_log="${LOG_DIR}/${folder}_${module}_${op_type}_${TIMESTAMP}.log"

    log "Starting simulation:"
    log "  Folder: ${folder}"
    log "  Grid Div: ${grid_div}"
    log "  N_R: ${n_r}"
    log "  N_C: ${n_c}"
    log "  Module: ${module}"
    log "  Cluster: ${cluster}"
    log "  Operation: ${op_type}"

    # Start time
    local start_time=$(date +%s)

    if [[ "${module}" == "riscv_scalable" ]]; then
        ./run_simulation.sh -f ${folder} -g ${grid_div} -cl ${cluster} -m ${module} -ot ${op_type} > ${sim_log} 2>&1
    else
        ./run_simulation.sh -f ${folder} -g ${grid_div} -r ${n_r} -c ${n_c} -m ${module} -ot ${op_type} > ${sim_log} 2>&1
    fi

    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ ${exit_code} -eq 0 ]; then
        log "Simulation completed successfully in ${duration} seconds"
        log_summary "SUCCESS: ${folder} (${module}) - ${op_type} - Duration: ${duration}s"
    else
        log_error "Simulation failed for ${folder} (${module}) - ${op_type}"
        log_summary "FAILED: ${folder} (${module}) - ${op_type} - Duration: ${duration}s"
        exit 1
    fi
}

# Main execution
log "Starting batch simulation run"
log_summary "=== Simulation Run Summary ==="
log_summary "Start Time: $(date)"
log_summary "Configuration:"
log_summary "  Log Directory: ${LOG_DIR}"
log_summary "  Report Directory: ${REPORT_DIR}"
log_summary "  Timestamp: ${TIMESTAMP}"

# Grid Top Convolution Tests
log "Running Grid Top Convolution Tests"
run_simulation "output_cmsis_l1_4x4" 8 4 4 "riscv_grid_top" "" "conv"
run_simulation "output_cmsis_l1_8x4" 16 8 4 "riscv_grid_top" "" "conv"
run_simulation "output_cmsis_l1_8x8" 32 8 8 "riscv_grid_top" "" "conv"

# Scalable Convolution Tests
log "Running Scalable Convolution Tests"
run_simulation "output_cmsis_l1_8x4" 8 4 4 "riscv_scalable" 2 "conv"
run_simulation "output_cmsis_l1_8x8" 8 4 4 "riscv_scalable" 4 "conv"

# Grid Top GEMM Tests
log "Running Grid Top GEMM Tests"
run_simulation "output_gemm_64x64_4x4" 8 4 4 "riscv_grid_top" "" "gemm"
run_simulation "output_gemm_64x64_8x4" 16 8 4 "riscv_grid_top" "" "gemm"
run_simulation "output_gemm_64x64_8x8" 32 8 8 "riscv_grid_top" "" "gemm"

# Scalable GEMM Tests
log "Running Scalable GEMM Tests"
run_simulation "output_gemm_64x64_8x4" 8 4 4 "riscv_scalable" 2 "gemm"
run_simulation "output_gemm_64x64_8x8" 8 4 4 "riscv_scalable" 4 "gemm"

# Final summary
log_summary "=== Final Summary ==="
log_summary "End Time: $(date)"
log_summary "Total Duration: $(( $(date +%s) - $(date -d @$(grep "Start Time" ${SUMMARY_FILE} | head -1 | cut -d' ' -f3-) +%s) )) seconds"
log_summary "All simulations completed"

log "All simulations completed successfully"