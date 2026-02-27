
## Building and Running the Simulation

### Quick Start

To run the simulation with default parameters:
```bash
./run_simulation.sh
```

### Custom Configuration

The simulation can be configured with the following parameters:

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| N_R       | Number of rows in the grid | 4 |
| N_C       | Number of columns in the grid | 4 |
| Folder    | Output folder name | output_cmsis_l1_8x4 |
| Grid Div  | Grid division value | 16 |

#### Command Line Options

```bash
./run_simulation.sh [options]

Options:
  -r, --n_r <value>      Set number of rows (N_R)
  -c, --n_c <value>      Set number of columns (N_C)
  -f, --folder <name>    Set output folder name
  -g, --grid-div <value> Set grid division value
```

#### Examples

1. Run with default parameters:
```bash
./run_simulation.sh
```

2. Run with custom grid size:
```bash
./run_simulation.sh -r 8 -c 4
```

3. Run with all custom parameters:
```bash
./run_simulation.sh -r 8 -c 4 -f output_cmsis_l1_8x4 -g 16
```

### Output

The simulation generates:
- A report file in the `rpt/` directory named `simulation_report_<folder_name>.txt`
- Console output showing simulation progress and results

The report includes:
- Configuration details (N_R, N_C, grid_div)
- Memory file path
- Timing results
- Verification results

## Troubleshooting

1. If you encounter build errors:
   - Ensure Verilator is properly installed
   - Check that all required Verilog files are listed in filelist.f
   - Verify the paths in filelist.f are correct

2. If you encounter runtime errors:
   - Check that the specified output folder exists
   - Verify that the grid_div value is appropriate for your configuration
   - Ensure you have write permissions in the rpt directory

## Notes

- The simulation uses the Verilator-generated model in obj_dir/
- Reports are stored in the rpt/ directory
- The simulation will automatically create the rpt directory if it doesn't exist