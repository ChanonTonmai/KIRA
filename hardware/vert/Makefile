MODULE ?= riscv_grid_top
CPP_FILE ?= sim_riscv_grid_top.cpp
# MODULE=riscv_scalable
# CPP_FILE=sim_riscv_scala_top.cpp

ifeq ($(MODULE),riscv_grid_top)
    CPP_FILE = sim_riscv_grid_top.cpp
else ifeq ($(MODULE),riscv_scalable)
    CPP_FILE = sim_riscv_scale_top.cpp
else
    $(error Invalid MODULE value. Must be either 'riscv_grid_top' or 'riscv_scalable')
endif

VERILATOR_FLAGS = --cc --trace -Wno-fatal 
VERILATOR_LINT_FLAGS = -Wno-fatal -Wno-TIMESCALEMOD \
					   -Wno-GENUNNAMED -Wno-PINCONNECTEMPTY -Wno-PINMISSING \
					   -Wno-BLKSEQ -Wno-WIDTHEXPAND

SRC_FILES = $(shell cat filelist.f)
TOP_FILES = $(MODULE).sv 

INCLUDE_DIRS = $(shell find . -type f \( -name "*.vh" -o -name "*.sv" \) -exec dirname {} \; | sort -u)
VERILATOR_INCLUDES = -I../src -I../src/Log-XBar -I../src/memories -I../src/riscv_core

N_R ?= 4
N_C ?= 4
CL ?= 2

print:
	@echo "SRC_FILES: $(SRC_FILES)"
	@echo "VERILATOR_INCLUDES: $(VERILATOR_INCLUDES)"

lint:
	verilator --lint-only ${VERILATOR_LINT_FLAGS} $(VERILATOR_INCLUDES) $(CPP_FILE)

sandwish: 
	@echo
	@echo "### VERILATING ###"
	verilator ${VERILATOR_FLAGS} $(VERILATOR_INCLUDES) \
				-CFLAGS "-O3" \
				--f filelist.f  --top-module $(MODULE) --exe $(CPP_FILE) \
				-GN_R=$(N_R) -GN_C=$(N_C) \
				-j 8 \
				
	@echo
	@echo "### BUILDING SIM ###"
	cd obj_dir
	make -j 8 -C obj_dir -f V$(MODULE).mk V$(MODULE)

toast: 
	@echo
	@echo "### VERILATING ###"
	verilator ${VERILATOR_FLAGS} $(VERILATOR_INCLUDES) \
				-CFLAGS "-O3" \
				--f filelist.f  --top-module $(MODULE) --exe $(CPP_FILE) \
				-GCL=$(CL) -GN_R=$(N_R) -GN_C=$(N_C) \
				-j 8 \
				
	@echo
	@echo "### BUILDING SIM ###"
	cd obj_dir
	make -j 8 -C obj_dir -f V$(MODULE).mk V$(MODULE)

clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd
