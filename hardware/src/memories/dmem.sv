// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    dmem
// Module Name:    dmem
// File Name:      dmem.sv
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
//   - This module is used to test the data memory module.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps


// addr[i+OFFSET] uses to select the byte
// addr[i+OFFSET] = '1 means store word

`define log2_non_zero(VALUE) ((VALUE) < ( 1 ) ? 1 : (VALUE) < ( 2 ) ? 1 : (VALUE) < ( 4 ) ? 2 : (VALUE)< (8) ? 3:(VALUE) < ( 16 )  ? 4 : (VALUE) < ( 32 )  ? 5 : (VALUE) < ( 64 )  ? 6 : (VALUE) < ( 128 ) ? 7 : (VALUE) < ( 256 ) ? 8 : (VALUE) < ( 512 ) ? 9 : 10)


module dmem #(
  parameter n_bank = 32,
  parameter log2_n_bank = `log2_non_zero(n_bank)
) (
  input clk,
  input en,
  input [3:0] we,
  input [26:0] addr, // [9:0]
  input [31:0] din,
  input [log2_n_bank-1:0] dmem_id, 
  output reg [31:0] dout
);
  parameter DEPTH = 4096*32;
  parameter ADDR_WIDTH = 12;
  // See page 133 of the Vivado Synthesis Guide for the template
  // https://www.xilinx.com/support/documentation/sw_manuals/xilinx2016_4/ug901-vivado-synthesis.pdf

  (* ram_style = "block" *) reg [31:0] mem [DEPTH-1:0];
  initial begin
    integer i;
    for (i=0; i<DEPTH; i=i+1) begin
        mem[i] = '0; // (i+1) + (dmem_id * 1024);
    end
  end
  
  // 16 bank addr[i+22]

localparam OFFSET = (n_bank == 32) ? 21 :
                    (n_bank == 16) ? 22 :
                    (n_bank == 64) ? 20 :
                    (n_bank == 8)  ? 23 : 
                                     22;


  SRAM_32x4096_1rw #(
    .ADDR_WIDTH_in(ADDR_WIDTH)
  ) sram_core_inst (
    // Port Connections (mapping wrapper ports to core ports)
    .clk0(clk),
    .csb0(~en),  // Active-low chip select
    .web0(write_enable_n), // Active-low write enable
    .addr0(address),
    .din0(din),
    .dout0(dout_internal)
  );

  logic write_enable_n; 
  logic [ADDR_WIDTH-1:0] address; 
  logic [31:0] dout_internal;

  assign address = addr[ADDR_WIDTH-1: 0];
  assign write_enable_n = ~( (we[0]||addr[OFFSET]) & (we[1]||addr[OFFSET+1]) & 
                             (we[2]||addr[OFFSET+2]) & (we[3]||addr[OFFSET+3]));  

  assign dout = dout_internal; 

  logic [31:0] dout_mem; 

  integer i;
  always @(posedge clk) begin
    if (en) begin
      for(i=0; i<4; i=i+1) begin
        if (we[i] || addr[i+OFFSET]) begin 
          mem[addr[17:0]][i*8 +: 8] <= din[i*8 +: 8];
        end
      end
      dout_mem <= mem[addr[17:0]];
    end 
  end

  logic [3:0] addr_offset;
  assign addr_offset = addr[OFFSET+3 : OFFSET];
//  assign dout = mem[addr];
endmodule

