// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    wb_selector
// Module Name:    wb_selector
// File Name:      wb_selector.sv
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
//   - This module is used to select the write-back value based on the control signal.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Functionality:
//       * Selects the write-back value (`wb_val`) based on `wb_sel`:
//           - `wb_sel == 2`: Write-back value is `pc + 4` (next instruction address).
//           - `wb_sel == 1`: Write-back value is `out_lex` (external data or load result).
//           - Default: Write-back value is `alu` (ALU computation result).
//   - Designed to be integrated with a RISC-V or similar pipeline architecture.
// ==============================================================================

module wb_selector(
    input [31:0] out_lex,
    input [31:0] pc,
    input [31:0] alu,
    input [1:0] wb_sel,
    output reg [31:0] wb_val
);
    always @(*) begin
        if (wb_sel == 2) begin
            wb_val = pc + 4;
        end else if (wb_sel == 1) begin
            wb_val = out_lex;
        end else begin
            wb_val = alu;
        end
    end
endmodule