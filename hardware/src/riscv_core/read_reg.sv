`timescale 1ns / 1ps
// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    read_reg
// Module Name:    read_reg
// File Name:      read_reg.sv
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
//   - This module is used to read the register values from the register file.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Functionality:
//       * Decodes source register addresses (`ra1`, `ra2`) from the instruction:
//           - `ra1` from bits [19:15].
//           - `ra2` from bits [24:20].
//       * Assigns `rs1` and `rs2` values based on `ra1` and `ra2`:
//           - If `ra1`/`ra2` matches predefined directional inputs (north, south, 
//             east, west), assigns respective input values (`i_n`, `i_s`, `i_e`, `i_w`).
//           - Otherwise, assigns values from general-purpose registers (`rd1`, `rd2`).
//   - Supports local parameter definitions for easier input mapping.
// ==============================================================================

module read_reg(
    input [31:0] inst, 
    input [31:0] rd1, 
    input [31:0] rd2,
    input is_psrf_sw, 
    input [31:0] i_n, i_s, i_e, i_w,
    output reg [4:0] ra1, 
    output reg [4:0] ra2, 
    output reg [31:0] rs1, 
    output reg [31:0] rs2
    );

    localparam IN_NORTH = 5'd31; 
    localparam IN_SOUTH = 5'd30; 
    localparam IN_WEST  = 5'd29; 
    localparam IN_EAST  = 5'd28; 
    
    always @(*) begin
      ra1 = inst[19:15];
      if (is_psrf_sw) begin 
        ra2 = inst[11:7];
      end else begin 
        ra2 = inst[24:20];
      end
  
      if (ra1 == IN_NORTH) begin
        rs1 = i_n; 
      end else if (ra1 == IN_SOUTH) begin
        rs1 = i_s; 
      end else if (ra1 == IN_WEST) begin
        rs1 = i_w; 
      end else if (ra1 == IN_EAST) begin
        rs1 = i_e; 
      end else begin
        rs1 = rd1; 
      end

      if (ra2 == IN_NORTH) begin
        rs2 = i_n; 
      end else if (ra2 == IN_SOUTH) begin
        rs2 = i_s; 
      end else if (ra2 == IN_WEST) begin
        rs2 = i_w; 
      end else if (ra2 == IN_EAST) begin
        rs2 = i_e; 
      end else begin
        rs2 = rd2; 
      end


    end

    // assign rs1 = rd1; 
    // assign rs2 = rd2; 

endmodule
