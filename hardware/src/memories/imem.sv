// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    imem
// Module Name:    imem
// File Name:      imem.sv
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
//   - This module is used to test the instruction memory module.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps
module imem (
  input clk,
  input ena,
  input [3:0] wea,
  input [11:0] addra,
  input [31:0] dina,
  // input [13:0] addrb,
  output reg [31:0] doutb
);

`ifndef SYNTHESIS
  parameter DEPTH = 1024;
`else
  parameter DEPTH = 256;
`endif

  // See page 133 of the Vivado Synthesis Guide for the template
  // https://www.xilinx.com/support/documentation/sw_manuals/xilinx2016_4/ug901-vivado-synthesis.pdf

  (* ram_style = "distributed" *) reg [31:0] mem [DEPTH-1:0];
  // reg [DEPTH-1:0][31:0] mem ;
  initial begin
    integer i;
    for (i=0; i<DEPTH; i=i+1) begin
        mem[i] = 32'b0;
    end
  end

  integer i;
  always @(posedge clk) begin
    if (ena) begin
      for(i=0; i<4; i=i+1) begin
        if (wea[i]) begin
          mem[addra][i*8 +: 8] <= dina[i*8 +: 8];
        end
      end
      // doutb <= mem[addra];
    end
  end
  always @(*) begin
    if (ena) begin
      doutb = mem[addra];
    end else begin 
      doutb = '0;
    end
  end


// assign doutb = mem[addra]; 
endmodule


`timescale 1ns / 1ps
module imem_clr (
  input clk,
  input rst, 
  input ena,
  input [3:0] wea,
  input [13:0] addra,
  input [31:0] dina,
  // input [13:0] addrb,
  output reg [31:0] doutb
);
  parameter DEPTH = 1024;

  // See page 133 of the Vivado Synthesis Guide for the template
  // https://www.xilinx.com/support/documentation/sw_manuals/xilinx2016_4/ug901-vivado-synthesis.pdf

  (* ram_style = "block" *) reg [31:0] mem [DEPTH-1:0];
  initial begin
    integer i;
    for (i=0; i<DEPTH; i=i+1) begin
        mem[i] = 32'b0;
    end
  end

  integer i;
  always @(posedge clk) begin
    if (rst) begin 
      doutb <= '0;
    end 
    else if (ena) begin
      for(i=0; i<4; i=i+1) begin
        if (wea[i]) begin
          mem[addra][i*8 +: 8] <= dina[i*8 +: 8];
        end
      end
      doutb <= mem[addra];
    end
  end
  // always @(posedge clk) begin
  //     doutb <= mem[addra];
  // end


// assign doutb = mem[addrb]; 
endmodule
