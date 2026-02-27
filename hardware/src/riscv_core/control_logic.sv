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
// Design Name:    control_logic
// Module Name:    control_logic
// File Name:      control_logic.sv
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
// Additional Comments:
//   - Key Features:
//       * Decodes instruction fields:
//           - `r_opc`: Opcode
//           - `r_func3`: Function code (3 bits)
//           - `r_func7`: Extended function code (7 bits)
//           - `r_rs1`, `r_rs2`: Source register indices
//           - `r_rd`: Destination register index
//       * Generates control signals:
//           - `pcsel`: Program counter selection.
//           - `regwen`: Register write enable.
//           - `asel`, `bsel`: ALU operand selectors.
//           - `alusel`: ALU operation selector.
//           - `memrw`: Memory read/write control.
//           - `memsel`, `wbsel`: Memory and write-back path selection.
//       * Branch handling:
//           - `br_taken`: Determines if a branch condition is satisfied based 
//             on branch type (`breq`, `brlt`) and branch function codes.
//   - Supports instruction types: R-format, branch, load, store, jump.
// ==============================================================================
`include "opcode.vh"

module control_logic #(
    parameter n_pe = 16
)(
    input clk, 
    input [31:0] inst,
    output reg [1:0] pcsel,  
    output reg regwen,  
    output reg brun,
    input brlt,
    input breq,
    input [n_pe-1:0] cond_state,
    input is_sync_beq,
    output logic vec_op_en, 
    output reg asel,  
    output reg bsel, 
    output reg [3:0] alusel,  
    output reg memrw, 
    output reg [1:0] wbsel,
    output logic br_taken_out
 );
    
    
    // R-format 
    wire [6:0] r_opc = inst[6:0];
    wire [2:0] r_func3 = inst[14:12];
    wire [6:0] r_func7 = inst[31:25];
    wire [4:0] r_rs1 = inst[19:15];
    wire [4:0] r_rs2 = inst[24:20];
    wire [4:0] r_rd = inst[11:7];


    
    // r_opc == 7'h64 -> psrf.{branch}
    // r_opc == 7'h65 -> sync.beq
    wire is_branch = r_opc == 7'h63 || r_opc == 7'h64 || r_opc == 7'h65; 
    reg br_taken; 
    assign br_taken_out = br_taken; 
    wire is_jalr = inst[6:0] == 7'h67 && inst[14:12] == 3'h0;
    wire is_jal = inst[6:0] == 7'h6F;

    // update: psrf.lw change opc to 7'h04 due to the need of lb
    wire is_load = inst[6:0] == 7'h03 || inst[6:0] == 7'h04; 
    
    // pc_sel => branch_taken => pc_sel = alu 
    // else pc_sel = pc + 4 => branch not taken
    always @(*) begin
        if (is_branch) begin
            case (r_func3)
                `FNC_BEQ: br_taken = breq;
                `FNC_BNE: br_taken = !breq;
                `FNC_BLT: br_taken = brlt;
                `FNC_BGE: br_taken = !brlt;
                `FNC_BLTU: br_taken = brlt;
                `FNC_BGEU: br_taken = !brlt;
                default: br_taken = 0;
            endcase
        end else begin
            br_taken = 0;
        end
    end
    
    logic or_cond; 
    assign or_cond = |cond_state; 

    always @(*) begin
        if (br_taken || (is_jal || is_jalr || (is_sync_beq && or_cond))) begin pcsel = 1; // branch taken 
        // end else if (loop_level > 0) begin pcsel = 2; 
        end else pcsel = 0; // branch not taken 
    end 
    
    logic [3:0] alusel_reg; // latch issuse
    always @(posedge clk) begin
        alusel_reg <= alusel;
    end
    

    // For R-Type => alusel
    /*
        ADD = 0, SUB = 1, SLL = 2, SLT = 3
        SLTU = 4, XOR = 5, SRL = 6, SRA = 7, OR = 8,
        AND = 9, PASSIMM = 10
    */
    // r_opc == 7'h15 -> psrf.addi
    always @(*) begin
        if (r_opc == 7'h33 || r_opc == 7'h13 || r_opc == 7'h67 || r_opc == 7'h15) begin
            vec_op_en = '0; 
            case (r_func3)
                3'b000: begin
                    if (r_opc == 7'h33) begin
                        if (r_func7 == '0) begin
                            alusel = 0; // add
                        end else if (r_func7 == 7'b0100000) begin
                            alusel = 1; // sub 
                        end else if (r_func7 == 7'b0000001) begin
                            alusel = 11; // mul
                        end else begin
                            alusel = alusel_reg;
                        end
                    end else if (r_opc == 7'h13) begin 
                        alusel = 0;
                    end else begin 
                        alusel = 0;
                    end
                end
                3'b001: alusel = 2;
                3'b010: alusel = 3;
                3'b011: alusel = 4;
                3'b100: alusel = 5;
                3'b101: alusel = (r_func7 == 7'b0) ? 6 : 7;
                3'b110: alusel = 8;
                3'b111: alusel = 9;
                default: alusel = 0;
            endcase
        // end else if (r_opc == 7'h33  && r_fun)
        end
        // private vector opcode
        else if (r_opc == 7'h34) begin 
            vec_op_en = '1; 
            case (r_func3)
                3'b000: begin
                    if (r_opc == 7'h34) begin
                        if (r_func7 == '0) begin
                            alusel = 0; // v.add
                        end else if (r_func7 == 7'b0000001) begin
                            alusel = 11; // v.mul
                        end else begin
                            alusel = alusel_reg;
                        end
                    end else begin 
                        alusel = 0;
                    end
                end
                3'b001: alusel = 2; // v.sum
                3'b010: alusel = 3;
                3'b011: alusel = 4;
                3'b100: alusel = 5;
                3'b101: alusel = (r_func7 == 7'b0) ? 6 : 7;
                3'b110: alusel = 8;
                3'b111: alusel = 9;
                default: alusel = 0;
            endcase
        end



        // If instruction = LUI, set alu to pass immediate onwards
        else if (r_opc == 7'h37) begin
            vec_op_en = 0; 
            alusel = 10; // passthrough
        end 
        // if instruction = ck.pmu_lui, set to pass immediate onwards aswell
        else if (r_opc == 7'h39) begin 
            vec_op_en = 0; 
            alusel = 10; // passthrough
        end
        // corf.lui, hwLrf.lui
        else if (r_opc == 7'h3B || r_opc == 7'h3C) begin 
            vec_op_en = 0; 
            alusel = 10; // passthrough
        end
        // corf.addi, ppsrf.addi
        else if (r_opc == 7'h14) begin 
            vec_op_en = 0; 
            alusel = 10; // passthrough
        end

        // For every other instruction -> default to add
        else begin
            alusel = 0;
            vec_op_en = 0; 
        end
    end
    
    
    // Setting MemRW
    /*
    1. If the instruction is an S-type, then write, otherwise read.
    */
    assign memrw = r_opc == 7'h23;
    
    // Setting RegWen
    /*
        1. If the type of instruction is not branch or store, we're writing to RD.
        2. Otherwise, set to 0.
    */
    // 64, 39, 14 and 3B is custom instructions
    wire rd_exists = (inst[6:0] != 7'h63 && inst[6:0] != 7'h23 && inst[11:7] != 0) 
                        || (inst[6:0] == 7'h39) || (r_opc == 7'h3B) || (r_opc == 7'h14)
                        || (inst[6:0] == 7'h64);
    assign regwen = rd_exists;
    
    // asel select between the PC and read register rs1 based on the AUIPC, JAL and JALR
    assign asel = (r_opc == 7'h17 || r_opc == 7'h6F || r_opc == 7'h63 || r_opc == 7'h64 || r_opc == 7'h65);

    // bsel select between read register rs2 and signed extend
    assign bsel = r_opc != 7'h33 && r_opc != 7'h73 && r_opc != 7'h34;
    
    // Setting brUN
    /* Branch unsigned = 1 if the inst type is B and func3[3:1] == "11" */
    wire is_unsigned = r_func3 == `FNC_BLTU || r_func3 == `FNC_BGEU; // BLTU or BGEU
    assign brun = is_branch && is_unsigned;
    
    // Setting WBSEL
    /*
        1. If inst_mw = jal or jalr -> writing PC + 4. WBSEL = 2
        2. If inst_mw = lw | lh | lb -> writing Mem, WBSEL = 1
        3. Else -> writing ALU, WBSEL = 0
    */

    always @(*) begin
        if (is_jal || is_jalr) begin
            wbsel = 2;
        end else if (is_load) begin
            wbsel = 1;
        end else begin
            wbsel = 0;
        end
    end
    
    // assign is_lw = inst[6:0] == 7'b0000011;
    // assign is_sw = inst[6:0] == 7'b0100011;
    // assign is_mul = (alusel == 4'd11);

    
endmodule
