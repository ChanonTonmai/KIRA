// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    agu
// Module Name:    agu
// File Name:      agu.sv
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

// Address generation Unit
// The idea is to introduce two new register file: 
// 1. Configuration Register File (CoRF)
// 2. Partial Sum Register File (PSRF)
// CRF takes responsibility to store the coefficient to get the address 
// PSRF takes responsibility to store the partial sum of the address 
// instead of multiplication
// The limitation is here: 
// 1. We design up to 4 dimensional array
// 2. We design up to 8 loop variables
// To utilize this idea, we introduce 4 new auxillary instructions apart from lw and sw
// 1. corf.addi and corf.lui for writing value to register file
// 2. psrf.addi is used to increment the loop index as well as 
//    the value in psrf which correspond to the tag (register).
//    This instruction check the every psrf mem for similar tag
//    and then increment it based on the CoRF which has the same row. 
// 3. psrf.branch (all the branch instruction) is used to reset the value
//    in the PSRF to zero. The value will have the similar tag. 
// Also, the lw and sw would be special as well named psrf.lw and psrf.sw. 
// Once the psrf.lw and psrf.sw perform, the value in the psrf for each variable
// are add it together and last but not least adding with the base address. 


module agu #(
  parameter n_pe = 16
)
(
  input clk, 
  input logic [31:0] inst_x,
  input logic ena_inst,
  input logic br_taken,

  input logic [2:0] cpu_state, 
  input logic [4:0] wa, 
  input logic [31:0] wd, 
  input logic [31:0] imm, 
  input logic regwen_x, 
  input logic is_hwloop_pc_end,
  input logic is_loopcnt_end, 
  input logic is_loop_notend, 
  input logic [4:0] hwLrf_tag_end, 
  input logic is_lw, 
  input logic is_sw, 
  input logic is_zero, 
  input logic is_zero_x, 
  input logic [2:0] hwl_state, 
  input logic is_hwLrf_lui, is_hwLrf_addi,
  input logic [n_pe-1:0] grid_state, 


  input logic [4:0] hwl_tag_en_1, 
  input logic [4:0] hwl_tag_en_2, 
  input logic [4:0] hwl_tag_en_3, 
  input logic [4:0] hwl_tag_en_4, 
  input logic [4:0] hwl_tag_en_5, 
  input logic [4:0] hwl_tag_en_6, 
  input logic [4:0] hwl_tag_en_7, 

  // output 
  output logic is_corf_lui,
  output logic is_corf_addi, 
  output logic is_ppsrf_addi, 
  output logic is_offs_addi, 
  output logic is_psrf_branch,
  output logic is_psrf_addi,
  output logic is_psrf_rst, 
  output logic is_psrf_lw, 
  output logic is_psrf_sw, 
  output logic is_psrf_zd_lw, 
  output logic [17:0] psrf_addr, 

  // output for zero-detection
  output logic [31:0] addr_operand_A, 
  output logic [31:0] addr_operand_B
);

  localparam [2:0] cpu_state_pc     = 3'b110; // 6
  localparam CORF_PSRF_MEM_DEPTH = 18;

  logic         corf_we; // write enable for corf
  logic [4:0]   corf_wa; // write address for corf
  logic [31:0]  corf_wd; // write data for corf
  logic         offs_we; // write enable for offs
  logic [4:0]   offs_wa; // write address for offs
  logic [31:0]  offs_wd; // write data for offs
  logic         psrf_we; // write enable for psrf
  logic [4:0]   psrf_wa; // write address for psrf
  logic [31:0] psrf_addr_temp; 
  logic [4:0] psrf_var; 
  logic [31:0] a_6add, b_6add, c_6add, d_6add, out_6add, e_6add, f_6add; 





  // The CoRF has 32 bit x 4 for each variable and we have 8 variables
  reg [31:0] corf_mem [0:CORF_PSRF_MEM_DEPTH-1];
  initial begin
    integer i;
    for (i=0; i<CORF_PSRF_MEM_DEPTH; i=i+1) begin
        corf_mem[i] = 32'b0;
    end
  end

  // offset mem for the final addition
  reg [31:0] offs_mem [0:15];
  initial begin
    integer i;
    for (i=0; i<15; i=i+1) begin
        offs_mem[i] = 32'b0;
    end
  end


  // The PSRF has 37 bit x 4 for each variable and we have 8 variables
  // There is an additional 5 bit for the tag located in LSB
  // | 20:5 -> value | 4:0 -> tag |
  reg [36:0] psrf_mem [0:CORF_PSRF_MEM_DEPTH-1];
  initial begin
    integer i;
    for (i=0; i<CORF_PSRF_MEM_DEPTH; i=i+1) begin
        psrf_mem[i] = 37'b0;
    end
  end

  always @(posedge clk) begin
    if (corf_we) begin
        corf_mem[corf_wa] <= corf_wd;
    end
  end

  always @(posedge clk) begin
    if (offs_we) begin
        offs_mem[offs_wa] <= offs_wd;
    end
  end

  assign is_corf_lui = (inst_x[6:0] == 7'h3B) ? 1:0; 
  assign is_corf_addi = (inst_x[6:0] == 7'h14 && inst_x[14:12] == 3'h0) ? 1:0; 
  assign is_ppsrf_addi = (inst_x[6:0] == 7'h14 && inst_x[14:12] == 3'h1) ? 1:0; 
  assign is_offs_addi = (inst_x[6:0] == 7'h14 && inst_x[14:12] == 3'h3) ? 1:0; 

  always @(*) begin
    if (is_corf_lui || is_corf_addi) begin 
      // corf_we = (cpu_state == cpu_state_pc && ena_inst == 1) ? regwen_x : 0;  
      corf_we = regwen_x;
      corf_wa = wa[4:0]; 
      if (is_corf_lui) begin
          corf_wd = wd[31:0]; 
      end else begin
          corf_wd = corf_mem[corf_wa] | imm;
      end
    end else begin
      corf_we = '0;
      corf_wa = '0; 
      corf_wd = '0; 
    end
  end

  always @(*) begin
    if (is_offs_addi) begin 
      // corf_we = (cpu_state == cpu_state_pc && ena_inst == 1) ? regwen_x : 0;  
      offs_we = regwen_x;
      offs_wa = wa[4:0]; 
      offs_wd = offs_mem[offs_wa] | imm;
    end else begin
      offs_we = '0;
      offs_wa = '0; 
      offs_wd = '0; 
    end
  end


  // The PSRF.branch instruction account for all the branch instructions
  // What it does is not only branching process but also
  // reset the value of the loop index in RF and value in the PSRF register 
  // based on tag to zero when it is not branch

  assign is_psrf_branch =   '0; // (inst_x[6:0] == 7'h64) ? 1:0; 
  assign is_psrf_addi =  (inst_x[6:0] == 7'h15 && inst_x[14:12] == 3'h0) ? 1:0; 
  assign is_psrf_rst =  (inst_x[6:0] == 7'h15 && inst_x[14:12] == 3'h1) ? 1:0; 

  always @(*) begin 
    if (is_psrf_branch) begin 
      psrf_wa = inst_x[19:15]; 
    end 
    else if (is_hwLrf_lui)  begin 
        psrf_wa = hwLrf_tag_end; // hwLrf_mem[loop_lv][19:15]; // tag end
    end else begin 
        psrf_wa = wa[4:0]; 
    end
  end

  // assign psrf_we = (cpu_state == cpu_state_pc && ena_inst == 1) ? regwen_x : 0;
  assign psrf_we = regwen_x; 

  always @(posedge clk) begin
    // ppsrf write the tag information only
    if (is_ppsrf_addi) begin 
      if (psrf_we) begin
        psrf_mem[wa[4:0]][4:0] <= wd[4:0];
      end
    end 

    else begin 
    // else if (is_psrf_addi || is_psrf_branch || is_hwloop_pc_end || is_ppsrf_addi) begin 
      // psrf_we = (cpu_state == cpu_state_pc && ena_inst == 1) ? regwen_x : 0;  
      if (( grid_state == '0 && (is_hwloop_pc_end || is_zero || is_zero_x) ) || (is_hwLrf_lui) )   
      begin
        if  ((psrf_mem[0][4:0] == psrf_wa && (is_psrf_addi || is_psrf_rst || is_hwLrf_lui  || is_psrf_branch)) || 
              psrf_mem[0][4:0] == hwl_tag_en_1 || psrf_mem[0][4:0] == hwl_tag_en_2 || 
              psrf_mem[0][4:0] == hwl_tag_en_3 || psrf_mem[0][4:0] == hwl_tag_en_4 || 
              psrf_mem[0][4:0] == hwl_tag_en_5 || psrf_mem[0][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[0][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[0][4:0] == psrf_wa )) begin
            // $display("psrf_branch"); 
            psrf_mem[0][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[0][4:0] == 0) begin 
              psrf_mem[0][20:5] <= psrf_mem[0][20:5]; 
            end else begin 
              psrf_mem[0][20:5] <= psrf_mem[0][20:5] + corf_mem[0]; 
            end
          end
        end 

        if  ((psrf_mem[1][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[1][4:0] == hwl_tag_en_1 || psrf_mem[1][4:0] == hwl_tag_en_2 || 
              psrf_mem[1][4:0] == hwl_tag_en_3 || psrf_mem[1][4:0] == hwl_tag_en_4 || 
              psrf_mem[1][4:0] == hwl_tag_en_5 || psrf_mem[1][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[1][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[1][4:0] == psrf_wa )) begin 
            psrf_mem[1][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[1][4:0] == 0) begin 
              psrf_mem[1][20:5] <= psrf_mem[1][20:5]; 
            end else begin 
              psrf_mem[1][20:5] <= psrf_mem[1][20:5] + corf_mem[1]; 
            end
          end
        end 

        if  ((psrf_mem[2][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[2][4:0] == hwl_tag_en_1 || psrf_mem[2][4:0] == hwl_tag_en_2 || 
              psrf_mem[2][4:0] == hwl_tag_en_3 || psrf_mem[2][4:0] == hwl_tag_en_4 || 
              psrf_mem[2][4:0] == hwl_tag_en_5 || psrf_mem[2][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[2][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[2][4:0] == psrf_wa )) begin 
            psrf_mem[2][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[2][4:0] == 0) begin 
              psrf_mem[2][20:5] <= psrf_mem[2][20:5]; 
            end else begin 
              psrf_mem[2][20:5] <= psrf_mem[2][20:5] + corf_mem[2]; 
            end
          end
        end 

        if  ((psrf_mem[3][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[3][4:0] == hwl_tag_en_1 || psrf_mem[3][4:0] == hwl_tag_en_2 || 
              psrf_mem[3][4:0] == hwl_tag_en_3 || psrf_mem[3][4:0] == hwl_tag_en_4 || 
              psrf_mem[3][4:0] == hwl_tag_en_5 || psrf_mem[3][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[3][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[3][4:0] == psrf_wa )) begin 
            psrf_mem[3][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[3][4:0] == 0) begin 
              psrf_mem[3][20:5] <= psrf_mem[3][20:5]; 
            end else begin 
              psrf_mem[3][20:5] <= psrf_mem[3][20:5] + corf_mem[3]; 
            end 
          end
        end 

        if  ((psrf_mem[4][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[4][4:0] == hwl_tag_en_1 || psrf_mem[4][4:0] == hwl_tag_en_2 || 
              psrf_mem[4][4:0] == hwl_tag_en_3 || psrf_mem[4][4:0] == hwl_tag_en_4 || 
              psrf_mem[4][4:0] == hwl_tag_en_5 || psrf_mem[4][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[4][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[4][4:0] == psrf_wa )) begin 
            psrf_mem[4][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[4][4:0] == 0) begin 
              psrf_mem[4][20:5] <= psrf_mem[4][20:5]; 
            end else begin 
              psrf_mem[4][20:5] <= psrf_mem[4][20:5] + corf_mem[4]; 
            end
          end
        end 

        if  ((psrf_mem[5][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[5][4:0] == hwl_tag_en_1 || psrf_mem[5][4:0] == hwl_tag_en_2 || 
              psrf_mem[5][4:0] == hwl_tag_en_3 || psrf_mem[5][4:0] == hwl_tag_en_4 || 
              psrf_mem[5][4:0] == hwl_tag_en_5 || psrf_mem[5][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[5][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[5][4:0] == psrf_wa )) begin 
            psrf_mem[5][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[5][4:0] == 0) begin 
              psrf_mem[5][20:5] <= psrf_mem[5][20:5]; 
            end else begin 
              psrf_mem[5][20:5] <= psrf_mem[5][20:5] + corf_mem[5]; 
            end 
          end
        end 

        if  ((psrf_mem[6][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[6][4:0] == hwl_tag_en_1 || psrf_mem[6][4:0] == hwl_tag_en_2 || 
              psrf_mem[6][4:0] == hwl_tag_en_3 || psrf_mem[6][4:0] == hwl_tag_en_4 || 
              psrf_mem[6][4:0] == hwl_tag_en_5 || psrf_mem[6][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[6][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[6][4:0] == psrf_wa )) begin 
            psrf_mem[6][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[6][4:0] == 0) begin 
              psrf_mem[6][20:5] <= psrf_mem[6][20:5]; 
            end else begin 
              psrf_mem[6][20:5] <= psrf_mem[6][20:5] + corf_mem[6]; 
            end 
          end
        end 

        if  ((psrf_mem[7][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[7][4:0] == hwl_tag_en_1 || psrf_mem[7][4:0] == hwl_tag_en_2 || 
              psrf_mem[7][4:0] == hwl_tag_en_3 || psrf_mem[7][4:0] == hwl_tag_en_4 || 
              psrf_mem[7][4:0] == hwl_tag_en_5 || psrf_mem[7][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[7][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[7][4:0] == psrf_wa )) begin 
            psrf_mem[7][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[7][4:0] == 0) begin 
              psrf_mem[7][20:5] <= psrf_mem[7][20:5]; 
            end else begin 
              psrf_mem[7][20:5] <= psrf_mem[7][20:5] + corf_mem[7]; 
            end 
          end
        end 

        if  ((psrf_mem[8][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[8][4:0] == hwl_tag_en_1 || psrf_mem[8][4:0] == hwl_tag_en_2 || 
              psrf_mem[8][4:0] == hwl_tag_en_3 || psrf_mem[8][4:0] == hwl_tag_en_4 || 
              psrf_mem[8][4:0] == hwl_tag_en_5 || psrf_mem[8][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[8][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[8][4:0] == psrf_wa )) begin 
            psrf_mem[8][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[8][4:0] == 0) begin 
              psrf_mem[8][20:5] <= psrf_mem[8][20:5]; 
            end else begin 
              psrf_mem[8][20:5] <= psrf_mem[8][20:5] + corf_mem[8]; 
            end 
          end
        end 

        if  ((psrf_mem[9][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[9][4:0] == hwl_tag_en_1 || psrf_mem[9][4:0] == hwl_tag_en_2 || 
              psrf_mem[9][4:0] == hwl_tag_en_3 || psrf_mem[9][4:0] == hwl_tag_en_4 || 
              psrf_mem[9][4:0] == hwl_tag_en_5 || psrf_mem[9][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[9][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[9][4:0] == psrf_wa )) begin 
            psrf_mem[9][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[9][4:0] == 0) begin 
              psrf_mem[9][20:5] <= psrf_mem[9][20:5]; 
            end else begin 
              psrf_mem[9][20:5] <= psrf_mem[9][20:5] + corf_mem[9]; 
            end 
          end
        end 

        if  ((psrf_mem[10][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[10][4:0] == hwl_tag_en_1 || psrf_mem[10][4:0] == hwl_tag_en_2 || 
              psrf_mem[10][4:0] == hwl_tag_en_3 || psrf_mem[10][4:0] == hwl_tag_en_4 || 
              psrf_mem[10][4:0] == hwl_tag_en_5 || psrf_mem[10][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[10][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[10][4:0] == psrf_wa )) begin 
            psrf_mem[10][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[10][4:0] == 0) begin
              psrf_mem[10][20:5] <= psrf_mem[10][20:5]; 
            end else begin 
              psrf_mem[10][20:5] <= psrf_mem[10][20:5] + corf_mem[10]; 
            end 
          end
        end 

        if  ((psrf_mem[11][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[11][4:0] == hwl_tag_en_1 || psrf_mem[11][4:0] == hwl_tag_en_2 || 
              psrf_mem[11][4:0] == hwl_tag_en_3 || psrf_mem[11][4:0] == hwl_tag_en_4 || 
              psrf_mem[11][4:0] == hwl_tag_en_5 || psrf_mem[11][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[11][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[11][4:0] == psrf_wa )) begin 
            psrf_mem[11][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[11][4:0] == 0) begin
              psrf_mem[11][20:5] <= psrf_mem[11][20:5]; 
            end else begin 
              psrf_mem[11][20:5] <= psrf_mem[11][20:5] + corf_mem[11]; 
            end 
          end
        end 

        if  ((psrf_mem[12][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[12][4:0] == hwl_tag_en_1 || psrf_mem[12][4:0] == hwl_tag_en_2 || 
              psrf_mem[12][4:0] == hwl_tag_en_3 || psrf_mem[12][4:0] == hwl_tag_en_4 || 
              psrf_mem[12][4:0] == hwl_tag_en_5 || psrf_mem[12][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[12][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[12][4:0] == psrf_wa )) begin 
            psrf_mem[12][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[12][4:0] == 0) begin
              psrf_mem[12][20:5] <= psrf_mem[12][20:5]; 
            end else begin 
              psrf_mem[12][20:5] <= psrf_mem[12][20:5] + corf_mem[12]; 
            end
          end
        end 

        if  ((psrf_mem[13][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[13][4:0] == hwl_tag_en_1 || psrf_mem[13][4:0] == hwl_tag_en_2 || 
              psrf_mem[13][4:0] == hwl_tag_en_3 || psrf_mem[13][4:0] == hwl_tag_en_4 || 
              psrf_mem[13][4:0] == hwl_tag_en_5 || psrf_mem[13][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[13][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[13][4:0] == psrf_wa )) begin 
            psrf_mem[13][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[13][4:0] == 0) begin
              psrf_mem[13][20:5] <= psrf_mem[13][20:5]; 
            end else begin 
              psrf_mem[13][20:5] <= psrf_mem[13][20:5] + corf_mem[13]; 
            end 
          end
        end 

        if  ((psrf_mem[14][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[14][4:0] == hwl_tag_en_1 || psrf_mem[14][4:0] == hwl_tag_en_2 || 
              psrf_mem[14][4:0] == hwl_tag_en_3 || psrf_mem[14][4:0] == hwl_tag_en_4 || 
              psrf_mem[14][4:0] == hwl_tag_en_5 || psrf_mem[14][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[14][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[14][4:0] == psrf_wa )) begin 
            psrf_mem[14][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[14][4:0] == 0) begin
              psrf_mem[14][20:5] <= psrf_mem[14][20:5]; 
            end else begin 
              psrf_mem[14][20:5] <= psrf_mem[14][20:5] + corf_mem[14]; 
            end 
          end
        end 

        if  ((psrf_mem[15][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[15][4:0] == hwl_tag_en_1 || psrf_mem[15][4:0] == hwl_tag_en_2 || 
              psrf_mem[15][4:0] == hwl_tag_en_3 || psrf_mem[15][4:0] == hwl_tag_en_4 || 
              psrf_mem[15][4:0] == hwl_tag_en_5 || psrf_mem[15][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[15][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[15][4:0] == psrf_wa )) begin 
            psrf_mem[15][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[15][4:0] == 0) begin
              psrf_mem[15][20:5] <= psrf_mem[15][20:5]; 
            end else begin 
              psrf_mem[15][20:5] <= psrf_mem[15][20:5] + corf_mem[15]; 
            end 
          end
        end 

        if  ((psrf_mem[16][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[16][4:0] == hwl_tag_en_1 || psrf_mem[16][4:0] == hwl_tag_en_2 || 
              psrf_mem[16][4:0] == hwl_tag_en_3 || psrf_mem[16][4:0] == hwl_tag_en_4 || 
              psrf_mem[16][4:0] == hwl_tag_en_5 || psrf_mem[16][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[16][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[16][4:0] == psrf_wa )) begin 
            psrf_mem[16][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[16][4:0] == 0) begin
              psrf_mem[16][20:5] <= psrf_mem[16][20:5]; 
            end else begin
              psrf_mem[16][20:5] <= psrf_mem[16][20:5] + corf_mem[16]; 
            end 
          end
        end 

        if  ((psrf_mem[17][4:0] == psrf_wa && (is_hwLrf_lui)) || 
              psrf_mem[17][4:0] == hwl_tag_en_1 || psrf_mem[17][4:0] == hwl_tag_en_2 || 
              psrf_mem[17][4:0] == hwl_tag_en_3 || psrf_mem[17][4:0] == hwl_tag_en_4 || 
              psrf_mem[17][4:0] == hwl_tag_en_5 || psrf_mem[17][4:0] == hwl_tag_en_6 || 
              0//psrf_mem[17][4:0] == hwl_tag_en_7
        ) begin 
          if ((0)|| ((is_hwLrf_lui || is_psrf_rst) && psrf_mem[17][4:0] == psrf_wa )) begin 
            psrf_mem[17][20:5] <= '0;
          end else begin
            if (is_hwLrf_lui || psrf_mem[17][4:0] == 0) begin
              psrf_mem[17][20:5] <= psrf_mem[17][20:5]; 
            end else begin
              psrf_mem[17][20:5] <= psrf_mem[17][20:5] + corf_mem[17]; 
            end 
          end
        end 

        
      // TODO: need to do the reset 
       
      // end else if ((is_psrf_addi) || (is_psrf_rst)) begin 
      //   if (psrf_mem[0][4:0] == psrf_wa) begin 
      //     if (is_psrf_addi) begin 
      //       psrf_mem[0][20:5] <= psrf_mem[0][20:5] + corf_mem[0]; 
      //     end else begin 
      //       psrf_mem[0][20:5] <= '0;
      //     end 
      //   end else if (psrf_mem[1][4:0] == psrf_wa) begin 
      //     if (is_psrf_addi) begin 
      //       psrf_mem[1][20:5] <= psrf_mem[1][20:5] + corf_mem[1]; 
      //     end else begin 
      //       psrf_mem[1][20:5] <= '0;
      //     end 
      //   end else if (psrf_mem[2][4:0] == psrf_wa) begin 
      //     if (is_psrf_addi) begin 
      //       psrf_mem[2][20:5] <= psrf_mem[2][20:5] + corf_mem[2]; 
      //     end else begin 
      //       psrf_mem[2][20:5] <= '0;
      //     end 
      //   end else if (psrf_mem[3][4:0] == psrf_wa) begin 
      //     if (is_psrf_addi) begin 
      //       psrf_mem[3][20:5] <= psrf_mem[3][20:5] + corf_mem[3]; 
      //     end else begin 
      //       psrf_mem[3][20:5] <= '0;
      //     end 
      //   end else if (psrf_mem[4][4:0] == psrf_wa) begin
      //     if (is_psrf_addi) begin  
      //       psrf_mem[4][20:5] <= psrf_mem[4][20:5] + corf_mem[4]; 
      //     end else begin 
      //       psrf_mem[4][20:5] <= '0;
      //     end 
      //   end else if (psrf_mem[5][4:0] == psrf_wa) begin 
      //     if (is_psrf_addi) begin 
      //       psrf_mem[5][20:5] <= psrf_mem[5][20:5] + corf_mem[5]; 
      //     end else begin 
      //       psrf_mem[5][20:5] <= '0;
      //     end 
      //   end else if (psrf_mem[6][4:0] == psrf_wa) begin 
      //     if (is_psrf_addi) begin 
      //       psrf_mem[6][20:5] <= psrf_mem[6][20:5] + corf_mem[6]; 
      //     end else begin 
      //       psrf_mem[6][20:5] <= '0;
      //     end 
      //   end 
        // end else if (psrf_mem[7][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[7][20:5] <= psrf_mem[7][20:5] + corf_mem[7]; 
        //   end else begin 
        //     psrf_mem[7][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[8][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin   
        //     psrf_mem[8][20:5] <= psrf_mem[8][20:5] + corf_mem[8]; 
        //   end else begin 
        //     psrf_mem[8][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[9][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[9][20:5] <= psrf_mem[9][20:5] + corf_mem[9]; 
        //   end else begin 
        //     psrf_mem[9][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[10][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[10][20:5] <= psrf_mem[10][20:5] + corf_mem[10]; 
        //   end else begin 
        //     psrf_mem[10][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[11][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[11][20:5] <= psrf_mem[11][20:5] + corf_mem[11]; 
        //   end else begin 
        //     psrf_mem[11][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[12][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[12][20:5] <= psrf_mem[12][20:5] + corf_mem[12]; 
        //   end else begin 
        //     psrf_mem[12][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[13][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[13][20:5] <= psrf_mem[13][20:5] + corf_mem[13]; 
        //   end else begin 
        //     psrf_mem[13][20:5] <= '0;
        //   end 
      
        // end else if (psrf_mem[14][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[14][20:5] <= psrf_mem[14][20:5] + corf_mem[14]; 
        //   end else begin 
        //     psrf_mem[14][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[15][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[15][20:5] <= psrf_mem[15][20:5] + corf_mem[15]; 
        //   end else begin 
        //     psrf_mem[15][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[16][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[16][20:5] <= psrf_mem[16][20:5] + corf_mem[16]; 
        //   end else begin 
        //     psrf_mem[16][20:5] <= '0;
        //   end 
        // end else if (psrf_mem[17][4:0] == psrf_wa) begin 
        //   if (is_psrf_addi) begin 
        //     psrf_mem[17][20:5] <= psrf_mem[17][20:5] + corf_mem[17]; 
        //   end else begin 
        //     psrf_mem[17][20:5] <= '0;
        //   end 
        // end 
      end
    end 
  end


  // sw 3'b100 sw
  assign is_psrf_lw = ((inst_x[14:12] == 3'b111 || inst_x[14:12] == 3'b0) && is_lw) ? 1:0;
  assign is_psrf_sw = ((inst_x[14:12] == 3'b100 || inst_x[14:12] == 3'b0) && is_sw) ? 1:0; 
  assign is_psrf_zd_lw = ((inst_x[14:12] == 3'b110) && is_lw) ? 1:0;


  logic [6:0] offs_var; 
  logic [29:0] offset_val; 
  assign offset_val = (is_psrf_lw == 1 || is_psrf_zd_lw == 1) ? offs_mem[offs_var[3:0]]:0; 

  assign psrf_addr = {psrf_addr_temp[29:0]} + offset_val ; // + 32'h1000_0000; 
  assign offs_var = inst_x[31:26]; 

  // psrf_var is 0 to 7 indicate which the loop variable 
  assign psrf_var = inst_x[24:20]; 


  assign addr_operand_A = psrf_mem[0][20:5]+psrf_mem[1][20:5]+psrf_mem[2][20:5]+psrf_mem[3][20:5]+psrf_mem[4][20:5]+psrf_mem[5][20:5];
  assign addr_operand_B = psrf_mem[6][20:5]+psrf_mem[7][20:5]+psrf_mem[8][20:5]+psrf_mem[9][20:5]+psrf_mem[10][20:5]+psrf_mem[11][20:5];


  always @(*) begin
    if (is_psrf_lw || is_psrf_sw || is_psrf_zd_lw) begin 
      if (psrf_var == 0) begin
        a_6add = psrf_mem[0][20:5]; 
        b_6add = psrf_mem[1][20:5];
        c_6add = psrf_mem[2][20:5]; 
        d_6add = psrf_mem[3][20:5]; 
        e_6add = psrf_mem[4][20:5]; 
        f_6add = psrf_mem[5][20:5];
        psrf_addr_temp = out_6add;
      end 
      else if (psrf_var == 1) begin 
        a_6add = psrf_mem[6][20:5]; 
        b_6add = psrf_mem[7][20:5];
        c_6add = psrf_mem[8][20:5]; 
        d_6add = psrf_mem[9][20:5]; 
        e_6add = psrf_mem[10][20:5]; 
        f_6add = psrf_mem[11][20:5];
        psrf_addr_temp = out_6add;
        // psrf_addr_temp = (psrf_mem[4][20:5] + psrf_mem[5][20:5] + psrf_mem[6][20:5] + psrf_mem[7][20:5]);
      end 
      else if (psrf_var == 2) begin 
        a_6add = psrf_mem[12][20:5]; 
        b_6add = psrf_mem[13][20:5];
        c_6add = psrf_mem[14][20:5]; 
        d_6add = psrf_mem[15][20:5]; 
        e_6add = psrf_mem[16][20:5]; 
        f_6add = psrf_mem[17][20:5];
        psrf_addr_temp = out_6add;
        // psrf_addr_temp = (psrf_mem[8][20:5] + psrf_mem[9][20:5] + psrf_mem[10][20:5] + psrf_mem[11][20:5]);
      end 
      // else if (psrf_var == 3) begin 
      //   a_6add = psrf_mem[18][20:5]; 
      //   b_6add = psrf_mem[19][20:5];
      //   c_6add = psrf_mem[20][20:5]; 
      //   d_6add = psrf_mem[21][20:5]; 
      //   e_6add = psrf_mem[22][20:5]; 
      //   f_6add = psrf_mem[23][20:5];
      //   psrf_addr_temp = out_6add;
      //   // psrf_addr_temp = (psrf_mem[12][20:5] + psrf_mem[13][20:5] + psrf_mem[14][20:5] + psrf_mem[15][20:5]);
      // end 
      
      else begin 
        a_6add = '0; // psrf_mem[6][20:5]; 
        b_6add = '0; // psrf_mem[7][20:5];
        c_6add = '0; // psrf_mem[8][20:5]; 
        d_6add = '0; // psrf_mem[9][20:5]; 
        e_6add = '0; // psrf_mem[10][20:5]; 
        f_6add = '0; // psrf_mem[11][20:5];
        psrf_addr_temp = '0; 
      end

    end else begin 
        a_6add = '0; // psrf_mem[6][20:5]; 
        b_6add = '0; // psrf_mem[7][20:5];
        c_6add = '0; // psrf_mem[8][20:5]; 
        d_6add = '0; // psrf_mem[9][20:5]; 
        e_6add = '0; // psrf_mem[10][20:5]; 
        f_6add = '0; // psrf_mem[11][20:5];
        psrf_addr_temp = '0; 
      end
  end

      // fourAdd fourAdd (
      //   // Inputs
      //   .a(a_4add),
      //   .b(b_4add),
      //   .c(c_4add),
      //   .d(d_4add),
      //   // Outputs
      //   .out_4add(out_4add)
      // );

  sixAdd sixAdd (
    // Inputs
    .a(a_6add),
    .b(b_6add),
    .c(c_6add),
    .d(d_6add),
    .e(e_6add),
    .f(f_6add),
    // Outputs
    .out_6add(out_6add)
  );

`ifndef SYNTHESIS
  logic [31:0] addr_peak_var_0; 
  logic [31:0] addr_peak_var_1; 
  logic [31:0] addr_peak_var_2; 

  assign addr_peak_var_0 = psrf_mem[0][20:5]+psrf_mem[1][20:5]+psrf_mem[2][20:5]+psrf_mem[3][20:5]+psrf_mem[4][20:5]+psrf_mem[5][20:5];
  assign addr_peak_var_1 = psrf_mem[6][20:5]+psrf_mem[7][20:5]+psrf_mem[8][20:5]+psrf_mem[9][20:5]+psrf_mem[10][20:5]+psrf_mem[11][20:5];
  assign addr_peak_var_2 = psrf_mem[12][20:5]+psrf_mem[13][20:5]+psrf_mem[14][20:5]+psrf_mem[15][20:5]+psrf_mem[16][20:5]+psrf_mem[17][20:5];

`endif


endmodule


module fourAdd(
  input logic [31:0] a, b, c, d,
  output logic [31:0] out_4add
); 

assign out_4add = a + b + c + d;
endmodule

module sixAdd(
  input logic [31:0] a, b, c, d, e, f,
  output logic [31:0] out_6add
); 

//  assign out_6add = a[15:0] + b[15:0] + c[15:0] + d[15:0] + e[15:0] + f[15:0];
assign out_6add = a[31:0] + b[31:0] + c[31:0] + d[31:0] + e[31:0] + f[31:0];

endmodule
