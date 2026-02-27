// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    imm_generator
// Module Name:    imm_generator
// File Name:      imm_generator.sv
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
//   - This module is used to generate the immediate value from the instruction.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Functionality:
//       * Decodes immediate values for different instruction types:
//           - I-Type: Extracts a 12-bit immediate with optional sign extension.
//           - S-Type: Combines lower and upper immediate bits from the instruction.
//           - B-Type: Computes a signed branch offset with sign extension.
//           - U-Type: Takes the upper 20 bits as the immediate value.
//           - J-Type: Constructs a jump offset with sign extension.
//           - CSR-Type: Extracts and zero-extends 5-bit immediate values.
//       * Handles SHAMT (shift amount) instructions specifically for I-Type.
//       * Sign extension is applied where applicable for signed instructions.
//   - Supports RISC-V instruction formats and ensures compliance with the ISA.
// ==============================================================================


module imm_generator (
    input  logic [31:0] inst,
    output logic [31:0] imm
);
    logic [31:0] imm_reg;
    logic [6:0] opc;
    assign opc = inst[6:0];
    logic [2:0] func3;
    assign func3 = inst[14:12];

    always @(*) begin
        // Instruction = I-Type
        if (opc == 7'h03 || opc == 7'h13 || opc == 7'h67 || opc == 7'h15) begin
            // SHAMT instructions
            if (opc == 7'h13 && (func3 == 3'b001 || func3 == 3'b101)) begin
                imm_reg[4:0] = inst[24:20];
                imm_reg[31:5] = 'd0;
            end else if (opc == 7'h03) begin // ck custom instruction 
                imm_reg = {'0, inst[31:20]}; 
            end else begin
                imm_reg[11:0] = inst[31:20];
                imm_reg[31:12] = inst[31]? 'hfffff: 'd0;
            end
        end
        // Instruction = corf.addi
        else if (opc == 7'h14 ) begin
            imm_reg[11:0] = inst[31:20];
            imm_reg[31:12] = 'd0;
        end

        // Instruction = CSR
        else if (opc == 7'h73) begin
            imm_reg[4:0] = inst[19:15];
            imm_reg[31:5] = 'd0; // No sign extension needed.
        end
        // Instruction = S-Type
        else if (opc == 7'h23) begin
            if (func3 == 3'b011) begin // ck custom instruction 
                imm_reg = '0; 
            end 
            else begin
                imm_reg[4:0] = inst[11:7];
                imm_reg[11:5] = inst[31:25];
                imm_reg[31:12] = inst[31] ? 'hffffff : 'h0;
            end
        end
        // Instruction = B-Type
        else if (opc == 7'h63 || opc == 7'h64 || opc == 7'h65) begin
            imm_reg[0] = 0;
            imm_reg[4:1] = inst[11:8];
            imm_reg[10:5] = inst[30:25];
            imm_reg[11] = inst[7];
            imm_reg[12] = inst[31];
            imm_reg[31:13] = (inst[31]) ? 'hffffff : 'd0;
        end
        // Instruction = U-Type
        // 7'h3B is custom instruction, corf.lui
        else if (opc == 7'h17 || opc == 7'h37 || opc == 7'h3B || opc == 7'h3C) begin 
            imm_reg[31:12] = inst[31:12];
            imm_reg[11:0] = 'd0;
        end
        // Instruction = J-Type
        else if (opc == 7'h6F) begin
            imm_reg[0] = 0;
            imm_reg[10:1] = inst[30:21];
            imm_reg[11] = inst[20];
            imm_reg[19:12] = inst[19:12];
            imm_reg[20] = inst[31];
            imm_reg[31:21] = (inst[31]) ? 12'hfff : 12'h0;
        end
        // ck.pmu_lui
        // else if (opc == 7'h39) begin 
        //     imm_reg = {'0, inst[31:12]};
        // end 
        // Instruction = R-Type
        else begin
            imm_reg = 0; // Immediate doesn't get used at all in R-Type insts.
        end
    end

    assign imm = $signed(imm_reg);

endmodule
// Calculations based on https://inst.eecs.berkeley.edu/~cs61c/fa17/img/riscvcard.pdf