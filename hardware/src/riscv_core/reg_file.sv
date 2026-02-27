// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    reg_file
// Module Name:    reg_file
// File Name:      reg_file.sv
// Create Date:    27/02/2026
// Engineer:       Chanon Khongprasongsiri
// Language:       SystemVerilog
//
// This source describes Open Hardware and is licensed under the 
// CERN-OHL-W v2 or later (https://ohwr.org/cern_ohl_w_v2.txt).
//
// Additional contributions by:
// - 
// - 
// Additional Comments:                                                       
//   - This module is used to implement the register file.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Functionality:
//       * Supports up to 32 registers (configurable via the `DEPTH` parameter).
//       * Read Operations:
//           - `ra1` and `ra2` specify the source register addresses for read ports.
//           - Outputs `rd1` and `rd2` provide the corresponding register values.
//       * Write Operation:
//           - `wa` specifies the destination register address for write-back.
//           - `wd` is the data to be written to the register if `we` is asserted.
//           - Write-back is ignored if `wa` is set to 0 (register x0 is hardwired to 0).
//       * Reset Initialization:
//           - All registers are initialized to 0 during module initialization.
//   - Designed for use in RISC-V or similar processor architectures.
// ==============================================================================

module reg_file (
    input clk,
    input we, 
    input [4:0] ra1, ra2, wa,
    input [31:0] wd, 
    output [31:0] rd1, rd2
);
    /*
    Mapping to schema:
    we = RegWEn, the control signal which determines whether DataD would be written at this clock tick.
    ra1, ra2 = AddrA, AddrB
    rd1, rd2 = rs1, rs2
    wa = AddrD, the address of the write back = rd
    wd = WB or DataD, the value being written back to
    */
    parameter DEPTH = 32;
    reg [31:0] mem [0:DEPTH-1]; // 28 registers for FPT synthesis
    initial begin
        for(integer i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = '0;
        end
    end

    reg [31:0] rd1_reg = 0;
    reg [31:0] rd2_reg = 0;

    always @(posedge clk) begin
        // Write value if write enable.
        if(we && wa != 0) begin
            mem[wa] <= wd;
        end
        // if(web && wb != 0) begin
        //     mem[wb] <= wd_b;
        // end
    end
    
    assign rd1 = mem[ra1];
    assign rd2 = mem[ra2];
endmodule
