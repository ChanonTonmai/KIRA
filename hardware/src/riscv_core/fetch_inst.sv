// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    fetch_inst
// Module Name:    fetch_inst
// File Name:      fetch_inst.sv
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
//   - This module is used to fetch the instruction from the instruction memory.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module fetch_inst (
    input [31:0] pc, 
    input [31:0] imem_dout,
    input logic pc_hwl_end_zero_flag,
    output reg [13:0] imem_addr, 
    output [31:0] inst
  );
    
    always @(*) begin
      imem_addr = pc[15:2]; // Set imem_addrb
    end


    // assign inst = (instsel) ? bios_dout : imem_dout;
    assign inst = (pc_hwl_end_zero_flag==1) ? 32'h00000013 : imem_dout;
endmodule

