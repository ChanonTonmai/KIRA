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
// Design Name:    next_pc
// Module Name:    next_pc
// File Name:      next_pc.sv
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
//   - This module is used to generate the next program counter value.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Functionality:
//       * Implements the logic for updating the PC:
//           - If `rst` is asserted, PC is reset to `RESET_PC` (default: 0x4000_0000).
//           - If `pcsel` is 0, PC increments to `pc + 4` (sequential execution).
//           - If `pcsel` is 1, PC is updated to the ALU output (branch/jump).
//       * Controlled by `ena` signal to enable or stall PC updates.
//   - Parameterized Reset PC (`RESET_PC`), allowing flexibility for different initial values.
// ==============================================================================



module next_pc #(
    parameter RESET_PC = 32'h4000_0000
)(
    input clk, 

    input rst, 
    input preload, 
    input [31:0] pc, 
    input [31:0] alu,
    input [31:0] pc_hwloop, 
    input [1:0] pcsel, 
    input ena, 
    output [31:0] next_pc 
);

// fetch loopup for pc sel 
// 0 => pc + 4
// 1 => alu (Branch & Jump)

reg [31:0] pc_next, pc_prev; 
always @(posedge clk) begin 
    if (rst) begin
        pc_next <= pc_prev;
    end
    else begin 
        pc_next <= pc_prev; 
    end
end 

always @(*) begin
  if (rst) begin 
    pc_prev = RESET_PC; 
  end else if (preload) begin
    pc_prev = 32'h800; 
  end else begin
    if (ena == 1) begin
      if (pcsel == 1) begin
          pc_prev = alu; 
      end else if (pcsel == 2) begin 
          pc_prev = pc_hwloop; 
      end else begin 
          pc_prev = pc + 4; 
      end 
    end else begin
        pc_prev = pc; 
    end
  end 
end 
assign next_pc = pc_next; 

endmodule
