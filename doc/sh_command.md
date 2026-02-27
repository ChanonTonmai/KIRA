# Build Flow
This section describes how to test or simulate XVI-V with Verilator from Venus (domain specific language) to assembly and the assembly to binary linked with Verilator cpp file. 

## cb.sh 
First of all, venus DSL source file is located in `software/venus_src` where the Venus build is located nearby. Venus is written with python targeting to perform the address mapping to all PE in the grid instead of manual mapping. Basically, Venus will translate vn file to yaml file that consist of the address and loop information. YAML file consists of the memory base address and its offsets for each variable. The offset is the offset for each base address for each PE. We can use command from `cb.sh` to build YAML file which automatically get the YAML file. 

```python
python VeNus/venus/cli/main.py "$SOURCE_FILE" -o "$YAML_OUTPUT"

# example
python VeNus/venus/cli/main.py venus_src/gemm_8x8.vn -o dfg_yaml/newgemm.yaml
```

## build.sh 
The next step is to generate the assembly file for each PE with `dfg_processor.cpp`. We can use `build.sh` to do it. Then, translating the assembly to binary with `risc_v_assembler.cpp`. 

## bar.sh (build and run)
Linked `build.sh` with verilator simulation. 

## verilator simulation 
In the vert folder, invoke the simulation by `run_simuilation.sh`.