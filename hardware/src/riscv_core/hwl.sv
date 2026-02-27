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
// Design Name:    hwl
// Module Name:    hwl
// File Name:      hwl.sv
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
//   - This module is used to handle the hardware loop unit.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// 
// Additional Comments:
//   Hardware Loop Unit 
//   The idea is to create a new register file named HWLRF (Hardware Loop Reg File).
//   Since we have upto 8 nested loop and the size of this register file is 32,
//   it is resulting in 8x32 bit size. 
//   | 31:26 -> Loop Start | 25:20 -> Loop End | 16:12 -> Tag | 11:0 -> Loop Count | 
//   We will used lui and addi to write to this register called hwrf.lui and hwrf.addi. 
//   This register would update every ena_inst is actived. 
//   There would be another introduced variable called loop_level[2:0] (3 bit). 
//   The loop_level would increment evert hwrf.addi. 
//   It indicates the nested level which mean every time we assert hwrf.addi mean we are 
//   performing the loop. It also decrement when the PC==Loop_end because the loop is end. 
//   We will use this loop_level to select the PC from the HW loop engine. 
//   If the loop_level != 0, pc_sel = 2 (pc_sel is the select pc used in next_pc.sv). 
// ==============================================================================




module hwl #(
  parameter n_pe = 16
)(
  input clk, rst,
  input [31:0] pc, 
  input logic [31:0] inst_x,
  input logic ena_inst,

  input logic [2:0] cpu_state, 
  input logic [n_pe-1:0] grid_state, 
  input logic [4:0] wa, 
  input logic [31:0] wd,
  input logic [31:0] imm,  
  input logic is_lw, 
  input logic is_sw, 
  input logic is_zero,
  input logic is_zero_x,


  // output 
  output logic [4:0] hwl_tag_en_1, 
  output logic [4:0] hwl_tag_en_2, 
  output logic [4:0] hwl_tag_en_3, 
  output logic [4:0] hwl_tag_en_4, 
  output logic [4:0] hwl_tag_en_5, 
  output logic [4:0] hwl_tag_en_6, 
  output logic [4:0] hwl_tag_en_7, 
  output logic [2:0] hwl_state_out, 
  output is_hwLrf_lui, 
  output is_hwLrf_addi, 
  output is_hwloop_pc_end, 
  output is_loopcnt_end,
  output is_loop_notend,
  output logic [4:0] hwLrf_tag_end, 
  output logic [31:0] pc_hwloop,
  output logic [1:0] pcsel_upper, 
  output logic pc_end_zero_flag,
  output logic [11:0] i_mat,j_mat,k_mat
);

  parameter RESET_PC = 32'h1000_0000;
  localparam [2:0] cpu_state_pc     = 3'b110; // 6


  logic [31:0] loop_endx4; 
  logic still_hw_loop;
  logic [4:0] hwLrf_wa; 
  logic [15:0] loop_start, loop_end; 
  logic [2:0] loop_lv; // loop level for nested loop
  initial begin
    loop_lv = 3'b0; 
  end
  reg [31:0] hwLrf_mem [0:7];
  logic [11:0] loop_count; 

  logic is_loopcnt_almostend; 
  logic is_loopcnt_almostend_reg; 
  logic is_loopcnt_almostend_e; 

  always @(posedge clk) begin 
    is_loopcnt_almostend_reg <= is_loopcnt_almostend;
  end
  assign is_loopcnt_almostend_e = ~is_loopcnt_almostend_reg & (is_loopcnt_almostend);

  logic [2:0] number_of_ended_loop; 
  logic [7:0] loop_count_is_one, loop_temp2; 
  logic [7:0] loop_temp; 
  logic [2:0] loop_max; 
  assign loop_count_is_one = {(hwLrf_mem[7][11:0] == 1), (hwLrf_mem[6][11:0] == 1), (hwLrf_mem[5][11:0] == 1), 
                              (hwLrf_mem[4][11:0] == 1), (hwLrf_mem[3][11:0] == 1), (hwLrf_mem[2][11:0] == 1), 
                              (hwLrf_mem[1][11:0] == 1), (hwLrf_mem[0][11:0] == 1)} ;

  logic [2:0] leading_one;
  always @(*) begin
      leading_one = 3'b000; // Default output
      casex (loop_count_is_one)
          8'b1xxxxxxx: begin leading_one = 3'b111; end // Highest priority (bit 7)
          8'b01xxxxxx: begin leading_one = 3'b110; end
          8'b001xxxxx: begin leading_one = 3'b101; end
          8'b0001xxxx: begin leading_one = 3'b100; end
          8'b00001xxx: begin leading_one = 3'b011; end
          8'b000001xx: begin leading_one = 3'b010; end
          8'b0000001x: begin leading_one = 3'b001; end
          8'b00000001: begin leading_one = 3'b000; end
          default: begin     leading_one = 3'b000;  end
      endcase
  end


  
  always @(*) begin
    i_mat = 8 - hwLrf_mem[1][11:0];
    j_mat = 64 - hwLrf_mem[2][11:0];
    k_mat = 64 - hwLrf_mem[3][11:0];
  end

  logic [2:0] hwl_state; 
  assign hwl_state_out = hwl_state; 
  assign loop_temp2 = loop_count_is_one << (7-leading_one);


  assign loop_temp[0] = loop_temp2[7]; 
  assign loop_temp[1] = loop_temp2[7] & loop_temp2[6];
  assign loop_temp[2] = loop_temp2[7] & loop_temp2[6] & loop_temp2[5];
  assign loop_temp[3] = loop_temp2[7] & loop_temp2[6] & loop_temp2[5] & 
                        loop_temp2[4];
  assign loop_temp[4] = loop_temp2[7] & loop_temp2[6] & loop_temp2[5] & 
                        loop_temp2[4] & loop_temp2[3];
  assign loop_temp[5] = loop_temp2[7] & loop_temp2[6] & loop_temp2[5] & 
                        loop_temp2[4] & loop_temp2[3] & loop_temp2[2];
  assign loop_temp[6] = loop_temp2[7] & loop_temp2[6] & loop_temp2[5] & 
                        loop_temp2[4] & loop_temp2[3] & loop_temp2[2] & 
                        loop_temp2[1];
  assign loop_temp[7] = loop_temp2[7] & loop_temp2[6] & loop_temp2[5] & 
                        loop_temp2[4] & loop_temp2[3] & loop_temp2[2] & 
                        loop_temp2[1] & loop_temp2[0];                         

  // assign number_of_ended_loop = (loop_temp[0] == 1) + (loop_temp[1] == 1) + (loop_temp[2] == 1) + 
  //             (loop_temp[3] == 1) + (loop_temp[4] == 1) + (loop_temp[5] == 1) +
  //             (loop_temp[6] == 1) + (loop_temp[7]);
  assign number_of_ended_loop = {2'b0, loop_temp[0]} + {2'b0, loop_temp[1]} + {2'b0, loop_temp[2]} + {2'b0, loop_temp[3]} +
                                {2'b0, loop_temp[4]} + {2'b0, loop_temp[5]} + {2'b0, loop_temp[6]} + {2'b0, loop_temp[7]};


  // assign hwLrf_tag_end = hwLrf_mem[loop_lv][16:12]; // tag end
  assign still_hw_loop = (loop_lv > 0) ? 1:0; 
  assign loop_start = hwLrf_mem[loop_lv][31:23]; 
  assign loop_end = {'0, hwLrf_mem[loop_lv][22:17]} + {'0, loop_start}; 
  assign loop_count = hwLrf_mem[loop_lv][11:0]; 


  assign is_hwloop_pc_end = (pc == ({'0, ({3'b0, hwLrf_mem[loop_lv][22:17]} + loop_start),2'b00} | RESET_PC) && still_hw_loop) ? 1:0; 

  //assign is_hwloop_pc_end = (pc[11:2] == ({'0, ({3'b0, hwLrf_mem[loop_lv][22:17]} + loop_start)}) && still_hw_loop) ? 1:0; 

  
  assign is_loopcnt_end = (hwLrf_mem[loop_lv][11:0] == 0 && still_hw_loop) ? 1:0;
  assign is_loopcnt_almostend = (hwLrf_mem[loop_lv][11:0] == 1 && still_hw_loop && !is_hwLrf_addi && !is_hwLrf_lui) ? 1:0;
  assign is_loop_notend = (hwLrf_mem[loop_lv][11:0] > 0 && still_hw_loop) ? 1:0;
  assign is_hwLrf_lui = (inst_x[6:0] == 7'h3C) ? 1:0; 
  assign is_hwLrf_addi = (inst_x[6:0] == 7'h14 && inst_x[14:12] == 3'h2) ? 1:0; 

  initial begin
    integer i;
    for (i=0; i<8; i=i+1) begin
        hwLrf_mem[i] = 32'b0;
    end
  end

  always @(posedge clk) begin 
    if (rst) begin 
      loop_max <= '0; 
    end else begin
      if (loop_max < loop_lv) begin 
        loop_max <= loop_lv; 
      end
    end 
  end
  logic [7:0] loop_mask;
  logic [2:0] i;

  logic [4:0] hwl_tag_en_1_reg; 
  logic [4:0] hwl_tag_en_2_reg; 
  logic [4:0] hwl_tag_en_3_reg; 
  logic [4:0] hwl_tag_en_4_reg; 
  logic [4:0] hwl_tag_en_5_reg; 
  logic [4:0] hwl_tag_en_6_reg; 
  logic [4:0] hwl_tag_en_7_reg; 
  logic [4:0] hwl_loop_lv; 



  assign hwl_tag_en_1 = hwl_tag_en_1_reg;
  assign hwl_tag_en_2 = hwl_tag_en_2_reg;
  assign hwl_tag_en_3 = hwl_tag_en_3_reg;
  assign hwl_tag_en_4 = hwl_tag_en_4_reg;
  assign hwl_tag_en_5 = hwl_tag_en_5_reg;
  assign hwl_tag_en_6 = hwl_tag_en_6_reg;
  assign hwl_tag_en_7 = hwl_tag_en_7_reg;

  localparam [2:0] hwl_state_idle  = 3'b000; // 0
  localparam [2:0] hwl_state_var     = 3'b001; // 1
  localparam [2:0] hwl_state_mem    = 3'b010; // 2

  logic [4:0] hwl_loop_lv_diff;
  assign hwl_loop_lv_diff = hwl_loop_lv - {2'b0, loop_lv};

  always @(*) begin 
    hwl_tag_en_1_reg = '0;
    hwl_tag_en_2_reg = '0;
    hwl_tag_en_3_reg = '0; 
    hwl_tag_en_4_reg = '0; 
    hwl_tag_en_5_reg = '0; 
    hwl_tag_en_6_reg = '0; 
    hwl_tag_en_7_reg = '0; 
    if (hwl_state == hwl_state_mem || hwl_state == hwl_state_var) begin 
      if (hwl_loop_lv_diff == 0) begin 
        hwl_tag_en_1_reg = hwLrf_mem[loop_lv][16:12];
        hwl_tag_en_2_reg = '0;
        hwl_tag_en_3_reg = '0;
        hwl_tag_en_4_reg = '0;
        hwl_tag_en_5_reg = '0;
        hwl_tag_en_6_reg = '0;
        hwl_tag_en_7_reg = '0;
      end else if (hwl_loop_lv_diff == 1) begin 
        hwl_tag_en_1_reg = '0; // hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg = hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg = '0;
        hwl_tag_en_4_reg = '0;
        hwl_tag_en_5_reg = '0;
        hwl_tag_en_6_reg = '0;
        hwl_tag_en_7_reg = '0;
      end else if (hwl_loop_lv_diff == 2) begin 
        hwl_tag_en_1_reg = '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg = '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg = hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg = '0;
        hwl_tag_en_5_reg = '0;
        hwl_tag_en_6_reg = '0;
        hwl_tag_en_7_reg = '0;
      end else if (hwl_loop_lv_diff == 3) begin 
        hwl_tag_en_1_reg = '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg = '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg = '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg = hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg = '0;
        hwl_tag_en_6_reg = '0;
        hwl_tag_en_7_reg = '0;
      end else if (hwl_loop_lv_diff == 4) begin 
        hwl_tag_en_1_reg = '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg = '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg = '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg = '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg = hwLrf_mem[hwl_loop_lv-4][16:12];
        hwl_tag_en_6_reg = '0;
        hwl_tag_en_7_reg = '0;
      end else if (hwl_loop_lv_diff == 5) begin 
        hwl_tag_en_1_reg = '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg = '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg = '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg = '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg = '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
        hwl_tag_en_6_reg = hwLrf_mem[hwl_loop_lv-5][16:12];
        hwl_tag_en_7_reg = '0;
      end else if (hwl_loop_lv_diff == 6) begin 
        hwl_tag_en_1_reg = '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg = '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg = '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg = '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg = '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
        hwl_tag_en_6_reg = '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
        hwl_tag_en_7_reg = hwLrf_mem[hwl_loop_lv-6][16:12];
      end 
    end
  end

  always @(posedge clk) begin 
    if (rst) begin 
      hwl_state <= hwl_state_idle; 
      // hwl_tag_en_1_reg <= '0; 
      // hwl_tag_en_2_reg <= '0;
      // hwl_tag_en_3_reg <= '0; 
      // hwl_tag_en_4_reg <= '0; 
      // hwl_tag_en_5_reg <= '0; 
      // hwl_tag_en_6_reg <= '0; 
      // hwl_tag_en_7_reg <= '0; 
    end else begin 
      case (hwl_state)
        hwl_state_idle: begin 
          // hwl_tag_en_1_reg <= '0;
          // hwl_tag_en_2_reg <= '0;
          // hwl_tag_en_3_reg <= '0; 
          // hwl_tag_en_4_reg <= '0; 
          // hwl_tag_en_5_reg <= '0; 
          // hwl_tag_en_6_reg <= '0; 
          // hwl_tag_en_7_reg <= '0; 
          if (is_lw || is_sw) begin 
            hwl_state <= hwl_state_mem; 
            hwl_loop_lv <= {2'b0, loop_lv}; 
            // hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
          end else begin 
            hwl_state <= hwl_state_idle;
          end
        end
        hwl_state_mem: begin 
          
          if (grid_state == '0) begin
            hwl_state <= hwl_state_var;

            // if (hwl_loop_lv_diff == 0) begin 
            //   hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0;
            //   hwl_tag_en_3_reg <= '0;
            //   hwl_tag_en_4_reg <= '0;
            //   hwl_tag_en_5_reg <= '0;
            //   hwl_tag_en_6_reg <= '0;
            //   hwl_tag_en_7_reg <= '0;
            // end else if (hwl_loop_lv_diff == 1) begin 
            //   hwl_tag_en_1_reg <= '0; // hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0;
            //   hwl_tag_en_4_reg <= '0;
            //   hwl_tag_en_5_reg <= '0;
            //   hwl_tag_en_6_reg <= '0;
            //   hwl_tag_en_7_reg <= '0;
            // end else if (hwl_loop_lv_diff == 2) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0;
            //   hwl_tag_en_5_reg <= '0;
            //   hwl_tag_en_6_reg <= '0;
            //   hwl_tag_en_7_reg <= '0;
            // end else if (hwl_loop_lv_diff == 3) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= '0;
            //   hwl_tag_en_6_reg <= '0;
            //   hwl_tag_en_7_reg <= '0;
            // end else if (hwl_loop_lv_diff == 4) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= hwLrf_mem[hwl_loop_lv-4][16:12];
            //   hwl_tag_en_6_reg <= '0;
            //   hwl_tag_en_7_reg <= '0;
            // end else if (hwl_loop_lv_diff == 5) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
            //   hwl_tag_en_6_reg <= hwLrf_mem[hwl_loop_lv-5][16:12];
            //   hwl_tag_en_7_reg <= '0;
            // end else if (hwl_loop_lv_diff == 6) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
            //   hwl_tag_en_6_reg <= '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
            //   hwl_tag_en_7_reg <= hwLrf_mem[hwl_loop_lv-6][16:12];
            // end 
          end else begin 
            hwl_state <= hwl_state_mem;
          end
        end
        hwl_state_var: begin // 1

          if (is_lw || is_sw) begin 
            hwl_state <= hwl_state_mem; 
            // if (hwl_loop_lv_diff == 0) begin 
            //   hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
            // end else if (hwl_loop_lv_diff == 1) begin 
            //   hwl_tag_en_1_reg <= '0; // hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= hwLrf_mem[hwl_loop_lv-1][16:12];
            // end else if (hwl_loop_lv_diff == 2) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= hwLrf_mem[hwl_loop_lv-2][16:12];
            // end else if (hwl_loop_lv_diff == 3) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= hwLrf_mem[hwl_loop_lv-3][16:12];
            // end else if (hwl_loop_lv_diff == 4) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= hwLrf_mem[hwl_loop_lv-4][16:12];
            // end else if (hwl_loop_lv_diff == 5) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
            //   hwl_tag_en_6_reg <= hwLrf_mem[hwl_loop_lv-5][16:12];
            // end else if (hwl_loop_lv_diff == 6) begin 
            //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
            //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
            //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
            //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
            //   hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
            //   hwl_tag_en_6_reg <= '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
            //   hwl_tag_en_7_reg <= hwLrf_mem[hwl_loop_lv-6][16:12];
            // end 
          end else begin
            if (is_hwloop_pc_end || is_zero || is_zero_x) begin 
              hwl_state <= hwl_state_idle; 
            end else begin
              hwl_state <= hwl_state_var; 
              // if (hwl_loop_lv_diff == 0) begin 
              //   hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
              // end else if (hwl_loop_lv_diff == 1) begin 
              //   hwl_tag_en_1_reg <= '0; // hwLrf_mem[hwl_loop_lv][16:12];
              //   hwl_tag_en_2_reg <= hwLrf_mem[hwl_loop_lv-1][16:12];
              // end else if (hwl_loop_lv_diff == 2) begin 
              //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
              //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
              //   hwl_tag_en_3_reg <= hwLrf_mem[hwl_loop_lv-2][16:12];
              // end else if (hwl_loop_lv_diff == 3) begin 
              //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
              //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
              //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
              //   hwl_tag_en_4_reg <= hwLrf_mem[hwl_loop_lv-3][16:12];
              // end else if (hwl_loop_lv_diff == 4) begin 
              //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
              //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
              //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
              //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
              //   hwl_tag_en_5_reg <= hwLrf_mem[hwl_loop_lv-4][16:12];
              // end else if (hwl_loop_lv_diff == 5) begin 
              //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
              //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
              //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
              //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
              //   hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
              //   hwl_tag_en_6_reg <= hwLrf_mem[hwl_loop_lv-5][16:12];
              // end else if (hwl_loop_lv_diff == 6) begin 
              //   hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
              //   hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
              //   hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
              //   hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
              //   hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
              //   hwl_tag_en_6_reg <= '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
              //   hwl_tag_en_7_reg <= hwLrf_mem[hwl_loop_lv-6][16:12];
              // end 
            end
          end
        end

      endcase 
    end

  end






  logic cpu_state_busy;
  logic cpu_state_busy_r; 
  logic cpu_state_busy_ris; // falling edge
  logic loop_count_max_zero;
  logic ended_loop; 
  // logic pc_end_zero_flag; 
  assign cpu_state_busy = (cpu_state == 3'd2 || cpu_state == 3'd5);
  assign loop_count_max_zero = (hwLrf_mem[loop_max][11:0] == 0);
  assign ended_loop = cpu_state_busy_ris & loop_count_max_zero;
  assign pc_end_zero_flag = (still_hw_loop) && (is_hwloop_pc_end) && ((hwLrf_mem[loop_max][11:0] == 0));

  always @ (posedge clk) begin
		cpu_state_busy_r <= cpu_state_busy;
	end
  assign cpu_state_busy_ris = cpu_state_busy & ~cpu_state_busy_r; 

  assign loop_mask = '1; 

  assign loop_endx4 = {24'd0, loop_end, 2'b00};
  always @(*) begin 
    if (is_loop_notend) begin 
      if ((pc == loop_endx4 + RESET_PC) || (is_zero) || (is_zero_x)) begin 
        pcsel_upper = 2; 
        pc_hwloop = {24'd0, loop_start, 2'b00} + RESET_PC; // loop_end
      end else begin 
        pcsel_upper = 0; 
        pc_hwloop = pc; 
      end
    end else begin 
      pcsel_upper = 0; 
      pc_hwloop = pc; 
    end
  end

  assign hwLrf_wa = wa[4:0]; 
  assign hwLrf_tag_end = is_hwLrf_lui ? hwLrf_mem[hwLrf_wa][16:12]:0;
  // assign hwLrf_we = (cpu_state == cpu_state_pc && ena_inst == 1) ? 1 : 0;
  always @(posedge clk) begin
    if(1) begin 
      if (is_hwLrf_lui || is_hwLrf_addi) begin 
        if (is_hwLrf_lui) begin
          hwLrf_mem[hwLrf_wa[2:0]] <= wd[31:0]; 
        end else begin
          hwLrf_mem[hwLrf_wa[2:0]] <= hwLrf_mem[hwLrf_wa[2:0]] | imm;
        end
      end 
      else if (ended_loop) begin 
        hwLrf_mem[loop_lv][11:0] <= hwLrf_mem[loop_lv][11:0] - 1;
      end else begin 
        if (hwLrf_mem[loop_lv][11:0] > 0) begin 
          if ((loop_lv > 0 && (is_hwloop_pc_end) && ena_inst) || 
                (loop_lv > 0 && is_zero) || (loop_lv > 0 && is_zero_x) ) begin
              hwLrf_mem[loop_lv][11:0] <= hwLrf_mem[loop_lv][11:0] - 1;
            end
        end
      end
    end 
  end

  always @(posedge clk) begin
    if (ena_inst) begin
      if (is_hwLrf_addi) begin
        loop_lv <= loop_lv + 1; 
      end else begin
        if (is_loopcnt_almostend) begin
          if (is_loopcnt_almostend_e == 1 && !is_hwLrf_addi && !is_hwLrf_lui) begin 
            if (loop_lv < number_of_ended_loop) begin 
              loop_lv <= loop_lv; //1;
            end else begin 
              loop_lv <= loop_lv - number_of_ended_loop;
            end
          end
          else if (is_lw || is_sw) begin
            if (loop_lv < number_of_ended_loop) begin 
              loop_lv <= loop_lv; //1;
            end else begin 
              loop_lv <= loop_lv - number_of_ended_loop;
            end
          end
        end
      end
    end
  end


endmodule

// if (loop_count_is_one ==       (8'b01010000 & loop_mask) ) begin 
//   loop_lv <= loop_lv - 1; 
// end 
// else if ((loop_count_is_one == (8'b01001000 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end 
// else if ((loop_count_is_one == (8'b01011100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end 
// else if ((loop_count_is_one == (8'b01011000 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end 
// else if ((loop_count_is_one == (8'b01101000 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01100100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01101100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01100010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01000100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01001100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01000010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01010010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01010100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01110010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 3; 
// end
// else if ((loop_count_is_one == (8'b01001010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01000110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01100110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01101010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01101110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 2; 
// end
// else if ((loop_count_is_one == (8'b01010010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01010110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01110110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 3; 
// end
// else if ((loop_count_is_one == (8'b01110100 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 3; 
// end
// else if ((loop_count_is_one == (8'b01001110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01011010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 
// end
// else if ((loop_count_is_one == (8'b01111010 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 4; 
// end
// else if ((loop_count_is_one == (8'b01011110 & loop_mask) )) begin 
//   loop_lv <= loop_lv - 1; 