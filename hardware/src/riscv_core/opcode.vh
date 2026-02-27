// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    opcode
// Module Name:    opcode
// File Name:      opcode.vh
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
//   - This file is used to define the RISC-V opcodes and function codes.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// List of RISC-V opcodes and funct codes.
// Use `include "opcode.vh" to use these in the decoder

`ifndef OPCODE
`define OPCODE

// ***** Opcodes *****
// CSR instructions
`define OPC_CSR 7'b1110011

// Special immediate instructions
`define OPC_LUI         7'b0110111
`define OPC_AUIPC       7'b0010111

// Jump instructions
`define OPC_JAL         7'b1101111
`define OPC_JALR        7'b1100111

// Branch instructions
`define OPC_BRANCH      7'b1100011

// Load and store instructions
`define OPC_STORE       7'b0100011
`define OPC_LOAD        7'b0000011

// Arithmetic instructions
`define OPC_ARI_RTYPE   7'b0110011
`define OPC_ARI_ITYPE   7'b0010011

// ***** 5-bit Opcodes *****
`define OPC_LUI_5       5'b01101
`define OPC_AUIPC_5     5'b00101
`define OPC_JAL_5       5'b11011
`define OPC_JALR_5      5'b11001
`define OPC_BRANCH_5    5'b11000
`define OPC_STORE_5     5'b01000
`define OPC_LOAD_5      5'b00000
`define OPC_ARI_RTYPE_5 5'b01100
`define OPC_ARI_ITYPE_5 5'b00100

// ***** Function codes *****

// Branch function codes
`define FNC_BEQ         3'b000
`define FNC_BNE         3'b001
`define FNC_BLT         3'b100
`define FNC_BGE         3'b101
`define FNC_BLTU        3'b110
`define FNC_BGEU        3'b111

// Load and store function codes
`define FNC_LB          3'b000
`define FNC_LH          3'b001
`define FNC_LW          3'b010
`define FNC_LBU         3'b100
`define FNC_LHU         3'b101
`define FNC_SB          3'b000
`define FNC_SH          3'b001
`define FNC_SW          3'b010

// Arithmetic R-type and I-type functions codes
`define FNC_ADD_SUB     3'b000
`define FNC_SLL         3'b001
`define FNC_SLT         3'b010
`define FNC_SLTU        3'b011
`define FNC_XOR         3'b100
`define FNC_OR          3'b110
`define FNC_AND         3'b111
`define FNC_SRL_SRA     3'b101
`define FNC_MUL         3'b000

// ADD and SUB use the same opcode + function code
// SRA and SRL also use the same opcode + function code
// For these operations, we also need to look at bit 30 of the instruction
`define FNC2_ADD        1'b0
`define FNC2_SUB        1'b1
`define FNC2_SRL        1'b0
`define FNC2_SRA        1'b1

`define FNC7_0  7'b0000000 // ADD, SRL
`define FNC7_1  7'b0100000 // SUB, SRA
`define FNC7_2  7'b0000001 // MUL
`endif //OPCODE
