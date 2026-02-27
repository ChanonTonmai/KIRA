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
// Design Name:    branch_comp
// Module Name:    branch_comp
// File Name:      branch_comp.sv
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
//   - This module is used to compare the two operands and generate the branch condition.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Comparison behavior:
//       * If `brun` is asserted (unsigned comparison):
//         - `brlt` is true if `rs1 < rs2` (unsigned).
//         - `breq` is true if `rs1 == rs2`.
//       * If `brun` is deasserted (signed comparison):
//         - `brlt` is true if `rs1 < rs2` (signed).
//         - `breq` is true if `rs1 == rs2` (signed).
//   - Ensure proper sign extension of inputs for signed operations if required.
// ==============================================================================


module branch_comp #(
    parameter id=0, 
    parameter n_pe=16
)(
    input clk, 
    input brun,
    input is_sync_beq, 
    input [7:0] grid_id,
    input [15:0] cond_state,
    input [31:0] rs1,
    input [31:0] rs2,
    output reg brlt,
    output reg breq
);
    // always @(posedge clk) begin
    //     if (brun) begin
    //         brlt = (rs1 < rs2) ? 1 : 0;
    //         breq = (rs1 == rs2) ? 1 : 0;
    //     end else begin
    //         brlt = ($signed(rs1) < $signed(rs2)) ? 1 : 0;
    //         breq = ($signed(rs1) == $signed(rs2)) ? 1 : 0;
    //     end
    // end
    logic or_cond; 


    // logic [15:0] masked_cond;
    // genvar i;
    // generate
    //     for (i = 0; i < 16; i = i + 1) begin : gen_mask
    //         assign masked_cond[i] = (i != id) ? cond_state[i] : 1'b0;
    //     end
    // endgenerate

    //assign or_cond = (is_sync_beq) ? |cond_state : '0; // OR-reduction
    assign or_cond = |cond_state; // OR-reduction

    always @(*) begin
        if (brun) begin
            if (is_sync_beq) begin
                brlt = (rs1 < rs2) ? 1 : 0;
                breq = (or_cond == 1) ? 1 : 0; // if it is equal to one,
                // there is a branch in a grid and it would need to synchonize between them.  
            end else begin 
                brlt = (rs1 < rs2) ? 1 : 0;
                breq = (rs1 == rs2) ? 1 : 0;
            end
        end else begin
            if (is_sync_beq) begin
                brlt = (rs1 < rs2) ? 1 : 0;
                breq = (or_cond == 1) ? 1 : 0; // if it is equal to one,
                // there is a branch in a grid and it would need to synchonize between them.  
            end else begin 
                brlt = ($signed(rs1) < $signed(rs2)) ? 1 : 0;
                breq = ($signed(rs1) == $signed(rs2)) ? 1 : 0;
            end
        end
    end
endmodule
