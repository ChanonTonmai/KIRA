// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    alu
// Module Name:    alu
// File Name:      alu.sv
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
//   - This module is used to perform the arithmetic and logical operations.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Supported Operations (based on `alu_sel`):
//       * 0 : Addition (`rs1 + rs2`)
//       * 1 : Subtraction (`rs1 - rs2`)
//       * 2 : Shift Left Logical (`rs1 << rs2[4:0]`)
//       * 3 : Set Less Than (signed comparison)
//       * 4 : Set Less Than Unsigned (unsigned comparison)
//       * 5 : XOR
//       * 6 : Shift Right Logical (`rs1 >> rs2[4:0]`)
//       * 7 : Shift Right Arithmetic (signed shift)
//       * 8 : OR
//       * 9 : AND
//       * 10: Pass Immediate (`rs2`)
//       * 11: Multiplication (`rs1[15:0] * rs2[15:0]`)
//       * Default: Addition
//   - Handles signed and unsigned operations for comparison and shifting.
//   - Considered the lower 5 bits of `rs2` for shift operations.
//
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
`define ASIC

module alu (
    input clk, 
    input [31:0] rs1,
    input [31:0] rs2,
    input [3:0] alu_sel,
    input vec_op_en, 
    output reg [31:0] out
);
    /*
        ADD = 0, SUB = 1, SLL = 2, SLT = 3
        SLTU = 4, XOR = 5, SRL = 6, SRA = 7, OR = 8,
        AND = 9, PASSIMM = 10
    */
    // Shift left logical and shift right logical can only shift
    // A maximum of 2^5 = 32 times (AKA, 32 values). Thus,
    // we only consider the lowermost 5 bits.
    wire [4:0] rs2_res = rs2[4:0];
    logic [31:0] mult_out; 
    logic [31:0] addsub_out; 
    logic [31:0] out_tmp; 
    logic clk_mult_enable; 
    logic clk_addsub_enable; 

    logic [63:0] mult_out_full; 

    assign clk_mult_enable = (alu_sel == 'd11) ? 1:0; 
    assign clk_addsub_enable = (alu_sel == 'd0 || alu_sel == 'd1) ? 1:0; 

    // always @(*) begin
    //     case (alu_sel)
    //         'd0: out = addsub_out; //rs1 + rs2;
    //         'd1: out = addsub_out; //rs1 - rs2;
    //         'd11: out = mult_out; 
    //         default: out = out_tmp;
    //     endcase
    // end
    assign out = out_tmp;
    logic [31:0] vec_tmp; 
    always @(*) begin 
        if (vec_op_en == 0) begin 
            case (alu_sel)
                'd0: out_tmp = addsub_out; //rs1 + rs2;
                'd1: out_tmp = addsub_out; //rs1 - rs2;
                'd2: out_tmp = $signed(rs1) << $signed(rs2_res);
                'd3: out_tmp = ($signed(rs1) < $signed(rs2)) ? 1 : 0;
                'd4: out_tmp = (rs1 < rs2) ? 1 : 0;
                'd5: out_tmp = rs1 ^ rs2;
                'd6: out_tmp = rs1 >> rs2_res;
                'd7: out_tmp = $signed(rs1) >>> rs2_res;
                'd8: out_tmp = rs1 | rs2;
                'd9: out_tmp = rs1 & rs2;
                'd10: out_tmp = rs2;
                'd11: out_tmp = mult_out; 
                default: out_tmp = '0;
            endcase
        end else if (vec_op_en == 1) begin 
            // case (alu_sel)
            //     'd0: begin // v.add 
            //         out_tmp[7:0]   = rs1[7:0] + rs2[7:0];
            //         out_tmp[15:8]  = rs1[15:8] + rs2[15:8];
            //         out_tmp[23:16] = rs1[23:16] + rs2[23:16];
            //         out_tmp[31:24] = rs1[31:24] + rs2[31:24]; 
            //     end
            //     'd11: begin // v.mul based on q1.7 ((a * b) + 16'sd64) >>> 7;
            //         out_tmp[7:0]   = ($signed(rs1[7:0]) * $signed(rs2[7:0])     + 16'sd0)     >>> 0; 
            //         out_tmp[15:8]  = ($signed(rs1[15:8]) * $signed(rs2[15:8])   + 16'sd0)   >>> 0;
            //         out_tmp[23:16] = ($signed(rs1[23:16]) * $signed(rs2[23:16]) + 16'sd0) >>> 0;
            //         out_tmp[31:24] = ($signed(rs1[31:24]) * $signed(rs2[31:24]) + 16'sd0) >>> 0; 
            //     end
            //     'd2: begin // v.sum sum all the value (4x8bit) + rs1
            //         vec_tmp[31:0] = ($signed(rs1[7:0]))
            //                         + ($signed(rs1[15:8]))
            //                         + ($signed(rs1[23:16])) 
            //                         + ($signed(rs1[31:24]));
            //         out_tmp[31:0] = ($signed(rs2)) + vec_tmp;
            //     end 

            // endcase
            out_tmp = '0; 
        end else begin
            out_tmp = '0; 
        end     
    end

    `ifdef FPGA
        mult_0 mult_0 (
            .CLK(clk), 
            .A(rs1[15:0]), 
            .B(rs2[15:0]), 
            .P(mult_out)
            // .CE(clk_mult_enable)
        );

        assign addsub_out = (!alu_sel[0]) ? rs1+rs2 : rs1-rs2; 
    `elsif ASIC
        assign mult_out_full = ($signed(rs1[31:0]) * $signed(rs2[31:0])); 
        assign mult_out = mult_out_full[47:16];  // mult_out_full[47:16]; 
        assign addsub_out = (!alu_sel[0]) ? rs1+rs2 : rs1-rs2; 
        
    `else
        assign mult_out = ($signed(rs1[31:0]) * $signed(rs2[31:0])); 
        assign addsub_out = (!alu_sel[0]) ? rs1+rs2 : rs1-rs2; 
    `endif

endmodule
