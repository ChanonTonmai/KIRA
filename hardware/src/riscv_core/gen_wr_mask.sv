// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    gen_wr_mask
// Module Name:    gen_wr_mask
// File Name:      gen_wr_mask.sv
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
//   - This module is used to generate the write mask for the memory store operations.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Description  : 
//   This module generates a write mask for memory store operations based on the
//   instruction opcode and address alignment. It supports various store types
//   (word, half-word, and byte) and determines which byte lanes in memory should
//   be written to.
// 
// Dependencies : None
// 
// Revision History:
//   2024-11-25 - [Version 1.0] - Initial design implementation
// 
// Additional Comments:
//   - Key Features:
//       * Analyzes instruction (`inst`) to determine the store type using `func3` and `opc`.
//       * Generates a 4-bit write mask (`mask`) for memory operations:
//         - Store Word (func3 = 3'b010): Writes to all byte lanes (mask = 4'b1111).
//         - Store Half-Word (func3 = 3'b001): Writes to two byte lanes based on `addr[1]`.
//         - Store Byte (func3 = 3'b000): Writes to one byte lane based on `addr[1:0]`.
//       * If not a store instruction (`opc != 7'h23`), generates a zero mask (mask = 4'b0000).
//   - Designed for integration with memory subsystems in processors.
// ==============================================================================


module gen_wr_mask(
    input [31:0] inst,
    input [31:0] addr,
    output reg [3:0] mask
);
    /* 
    1. If the instruction isn't a store type (7'h23), then set the mask to all zeros (write nothing).
    2. If it is a store type
    */
    wire [6:0] opc;
    assign opc = inst[6:0];
    
    wire [2:0] func3;
    assign func3 = inst[14:12];

    always @(*) begin
        if (opc == 7'h23 || opc == 7'h24) begin
            if (func3 == 3'b010) begin // Store Word
                mask = 4'b1111;
            end 
            else if (func3 == 3'b100) begin // PSRF Store Word
                mask = 4'b1111;
            end 
            // else if (func3 == 3'b001) begin // Store Half Word
            //     if (addr[1] == 1) begin
            //         mask = 4'b1100;
            //     end else begin
            //         mask = 4'b0011;
            //     end

            // else if (func3 == 3'b000) begin // Store byte
            //     case(addr[1:0])
            //         'd3: mask = 4'b1000;
            //         'd2: mask = 4'b0100;
            //         'd1: mask = 4'b0010;
            //         'd0: mask = 4'b0001;
            //         default: mask = 4'b0000; 
            //     endcase
            // end 
            // else if (func3 == 3'b011) begin // ck custom instrcution 
            //     mask = 4'b1111;
            // end
            else begin
                mask = 4'b0000;
            end
        end else begin
            mask = 4'b0000;
        end
    end
endmodule
