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
// Design Name:    data_in_gen
// Module Name:    data_in_gen
// File Name:      data_in_gen.sv
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
//   - This module is used to generate the address for the data memory module.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
//
// Additional Comments:
//   - Key Functionality:
//       * Shifts the input data (`in`) based on the `mask` value.
//       * Supports the following mask-based operations:
//           - `4'b1100`: Left shift by 16 bits.
//           - `4'b0010`: Left shift by 8 bits.
//           - `4'b0100`: Left shift by 16 bits.
//           - `4'b1000`: Left shift by 24 bits.
//           - Default: No shift (output equals input).
//   - Can be extended for additional data manipulation operations based on mask.
// ==============================================================================


module data_in_gen(
    input [31:0] in,
    input [3:0] mask,
    output reg [31:0] out
);
    always @(*) begin
        case (mask)
            4'b1100: out = in << 16;
            4'b0010: out = in << 8;
            4'b0100: out = in << 16;
            4'b1000: out = in << 24;
            default: out = in;
        endcase
        // out = in;
    end
endmodule
