## KIRA / XVI‑V RISC‑V Grid Accelerator

KIRA is a research prototype of the **XVI‑V accelerator**: a RISC‑V–based, clusterized grid architecture for data‑parallel workloads (e.g., dense linear algebra and convolutions).  
The design focuses on **scalability**, **memory‑system efficiency**, and **loop/address offloading** via custom microarchitectural extensions.

### Project overview

- **Grid architecture**: Multiple 4×4 RISC‑V PE clusters interconnected to form a scalable grid (see `doc/grid.md`).
- **Tightly Coupled Data Memory (TCDM)**: Banked, shared scratchpad per cluster with a logarithmic interconnect to reduce conflicts (see `doc/data_memory_system.md`).
- **Hardware loop engine**: Zero‑overhead nested loops managed entirely in hardware, up to seven levels deep (see `doc/hardware_loop.md`).
- **Address Generation Unit (AGU)**: Affine address generation using dedicated CoRF/PSRF register files and custom instructions (see `doc/address_gen.md`).
- **Custom ISA extensions**: Additional instructions for hardware loops, AGU, and clustered memory access on top of RV32I (see `doc/instruction.md`).

### Repository layout

- **`hardware/src/`**: RTL for the grid, scalable top, memories, RISC‑V core, hardware loop engine, AGU, and interconnect.
- **`hardware/vert/`**: Verilator testbenches and C++ harnesses (`sim_riscv_grid_top.cpp`, `sim_riscv_scale_top.cpp`), filelists, and helper scripts.
- **`software/`**: Front‑end toolchain (VeNus DSL, YAML generation, assembler, and build scripts) and example kernels.
- **`doc/`**: Micro‑architecture and ISA documentation for KIRA / XVI‑V.
- **`LICENSE`**: Apache 2.0 license for this repository.

### Documentation

- **`doc/grid.md`**: High‑level description of the clustered grid architecture and scalability rationale.
- **`doc/data_memory_system.md`**: TCDM organization, banked layout, host/PE access model, and conflict behavior.
- **`doc/hardware_loop.md`**: Hardware loop engine design, register file, nested loop handling, and integration with the PC and AGU.
- **`doc/address_gen.md`**: Address Generation Unit (CoRF/PSRF), custom instructions (`psrf.*`, `corf.*`, etc.), and hardware/software interaction.
- **`doc/instruction.md`**: Supported RISC‑V base instructions plus all XVI‑V‑specific ISA extensions and encodings.
- **`doc/log_intc.md`**: Logarithmic interconnect interface notes (currently a TODO stub).
- **`doc/sh_command.md`**: End‑to‑end build and simulation flow using the provided shell scripts.

### Build and simulation flow (from `doc/sh_command.md`)

- **Front‑end (VeNus DSL → YAML)**  
  - **Script**: `software/cb.sh`  
  - Uses the VeNus Python tool (`software/VeNus/venus/cli/main.py`) to translate `.vn` kernels in `software/venus_src/` into YAML describing PE mapping, loops, and memory layout.

- **YAML → per‑PE assembly → binary**  
  - **Script**: `software/build.sh`  
  - Runs `dfg_processor.cpp` to generate per‑PE assembly, then assembles to RISC‑V binaries via `risc_v_assembler.cpp`.

- **Build and run (all‑in‑one)**  
  - **Script**: `bar.sh` in the repository root  
  - Wraps `build.sh` and invokes Verilator simulation using the C++ harnesses in `hardware/vert/`.

- **Verilator simulation only**  
  - **Scripts**: `hardware/vert/run_simulation.sh`, `hardware/vert/run_sim_all.sh`  
  - Use these when binaries are already generated and you just want to run or sweep simulations.

For more detailed usage (arguments, example commands, and supported kernels), refer to `doc/sh_command.md` and the comments inside each script.

### Simulation with Verilator (`bar.sh` example)

To build the GEMM kernel and run a Verilator simulation of the clustered grid top:

```bash
./bar.sh -s gemm -r 4 -c 2 -g 8 -m riscv_grid_top -ot gemm -arb 1
```

- **`-s gemm`**: select the GEMM software/kernel.
- **`-r 4 -c 2`**: configure a grid of 4 rows × 2 columns of clusters.
- **`-g 8`**: set the cluster/grid division factor used by the hardware.
- **`-m riscv_grid_top`**: choose the top‑level Verilog module for simulation.
- **`-ot gemm`**: operation type passed through to the Verilator C++ harness.
- **`-arb 1`**: enable priority‑min arbitration policy in the TCDM interconnect.

### License

KIRA / XVI‑V is released under the **Apache License 2.0**.  
See the `LICENSE` file for the full text and terms. 