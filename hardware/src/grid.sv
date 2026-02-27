
// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    fetch_inst
// Module Name:    fetch_inst
// File Name:      fetch_inst.sv
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
//   - This module is used to fetch the instruction from the instruction memory.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Features:
//       * Configurable parameters:
//           - `N_R`: Number of rows in the grid.
//           - `N_C`: Number of columns in the grid.
//           - `DATA_WIDTH`: Data width for internal communication (default: 32).
//           - `NB_LS`: Number of load/store signals.
//       * Interfaces:
//           - Instruction memory interface: `imem_dina`, `imem_wea`, `imem_addra`.
//           - Data memory interface: `dmem_addr`, `dmem_din`, `dmem_dout`, `dmem_we`, `dmem_en`.
//           - Load/store interconnect: `load_store_req`, `load_store_data_req`, etc.
//           - ALU outputs: `alu_o`.
//       * Manages tile-level communication and control across the grid.
// ==============================================================================

`timescale 1ns / 1ps
module grid # (
    parameter N_R = 4, 
    parameter N_C = 4, 
    parameter NB_LS = 16,
    parameter n_pe = N_R*N_C,
    parameter DATA_WIDTH = 32
) (
    input logic                             clk, 
    input [n_pe-1:0]                            rst, 
    input logic                             inst_en, 
    input logic                             preload, 
    output logic                            finish, 
    input logic [7:0]                       grid_div, 

    // instruction memory interface
    input logic [(N_R*N_C)-1:0][31:0]   imem_dina,
    input logic [(N_R*N_C)-1:0][3:0]    imem_wea, 
    input logic [(N_R*N_C)-1:0][13:0]   imem_addra,

    // local memory interface
    input logic [(N_R*N_C)-1:0][31:0]   lmem_dina,
    input logic [(N_R*N_C)-1:0][3:0]    lmem_wea, 
    input logic [(N_R*N_C)-1:0][9:0]    lmem_addra,

    // // power management     
    // output  logic         pmu_we, // write enable for pmu
    // output  logic [5:0]   pmu_wa, // write address for pmu
    // output  logic [31:0]  pmu_wd, // write data for pmu

    // data memory interface
    output  logic [(N_R*N_C)-1:0][31:0] dmem_addr,
    output  logic [(N_R*N_C)-1:0][31:0] dmem_din, // data in to mem 
    input   logic [(N_R*N_C)-1:0][31:0] dmem_dout, // data out from mem 
    output  logic [(N_R*N_C)-1:0][3:0]  dmem_we,
    output  logic [(N_R*N_C)-1:0]       dmem_en, 

    // interconnect interface xbar logarithmic
    input  logic [(N_R*N_C)-1:0]        load_store_grant_i,
    input  logic [(N_R*N_C)-1:0]        data_req_valid_i,
    output logic [(N_R*N_C)-1:0]        load_store_req, 
    output logic [(N_R*N_C)-1:0]        load_store_data_req,

    // zero tcdm interface
    output logic [(N_R*N_C)-1:0][31:0]  zero_pe_dmem_addr,
    output logic [(N_R*N_C)-1:0]        zero_pe_load_store_data_req,
    output logic [(N_R*N_C)-1:0]        zero_pe_load_store_req,
    input  logic [(N_R*N_C)-1:0][31:0]  zero_pe_dmem_dout,
    input  logic [(N_R*N_C)-1:0]        zero_pe_data_req_valid_i,
    input  logic [(N_R*N_C)-1:0]        zero_pe_load_store_grant_i,

    input  logic [(N_R*N_C)-1:0]        zero_pe_reg_we,
    input  logic [(N_R*N_C)-1:0][31:0]  zero_pe_data,

    // analsis signals 
    output logic [(N_R*N_C)-1:0]       dbg_finish,
    output logic [(N_R*N_C)-1:0][31:0] dbg_ic, 
    output logic [(N_R*N_C)-1:0][31:0] dbg_ic_trap, 
    output logic [(N_R*N_C)-1:0][31:0] dbg_mem_conflict
); 


logic [(N_R*N_C)-1 : 0][3:0] 		              tile_id;	
logic [(N_R-1):0][(N_C-1):0][DATA_WIDTH-1:0]  pe_wire_n;
logic [(N_R-1):0][(N_C-1):0][DATA_WIDTH-1:0]  pe_wire_s;
logic [(N_R-1):0][(N_C-1):0][DATA_WIDTH-1:0]  pe_wire_w;
logic [(N_R-1):0][(N_C-1):0][DATA_WIDTH-1:0]  pe_wire_e;

logic [(N_R*N_C)-1:0] load_store_grant_i_reg;

logic [(N_R*N_C)-1:0] mem_op, busy;
logic [(N_R*N_C)-1:0] cond_state_in;
logic [(N_R*N_C)-1:0] cond_state;
logic [(N_R*N_C)-1:0] trap_or_finish;

assign dbg_finish = trap_or_finish; 

assign cond_state_in = cond_state;

// grid_div is grid_divider 
// currently, we have 16 PEs 
// grid_div = 8 mean grid_cluster size will have 2. 
// logic [7:0] grid_div; 
// assign grid_div = 7'd16;



logic [(N_R*N_C)-1:0][31:0] dmem_addr_temp;


assign busy = mem_op & (~load_store_grant_i_reg) ; // something need to noted 
assign finish = (trap_or_finish == '1) ? 1:0; 

always @(posedge clk) begin
  if (rst) begin
    load_store_grant_i_reg <= '0;
  end else begin
    load_store_grant_i_reg <= load_store_grant_i; 
  end
end

integer kk; 
always @(*) begin
  for (kk = 0; kk<N_R*N_C; kk++) begin
    dmem_addr[kk] = { dmem_addr_temp[kk]};
  end
end

logic [n_pe-1:0][n_pe-1:0] masked_cond;

genvar k;
// generate
//   for (k = 0; k < n_pe; k = k + 1) begin : gen_mask
//     assign masked_cond[0][k] = (k != 0) ? cond_state_in[k]: 1'b0; // timing loop issue
//     assign masked_cond[1][k] = (k != 1) ? cond_state_in[k]: 1'b0; // timing loop issue
//   end
// endgenerate


// logic [(N_R*N_C)-1:0] zero_pe_load_store_data_req;
// logic [(N_R*N_C)-1:0] zero_pe_load_store_req;
// logic [(N_R*N_C)-1:0] zero_pe_data_req_valid_i;
// logic [(N_R*N_C)-1:0] zero_pe_load_store_grant_i;
// logic [(N_R*N_C)-1:0][31:0] zero_pe_dmem_addr;
// logic [(N_R*N_C)-1:0][31:0] zero_pe_dmem_dout;


genvar i,j;
generate 
  for (i = 0; i< N_R; i++) begin
    for (j = 0; j< N_C; j++) begin
      if (i==0 && j==0) begin // this indicate the master CGRA which should always run

        

        for (k = 0; k < n_pe; k = k + 1) begin : gen_mask
            assign masked_cond[i*N_C + j] = '0; // (k != i*N_C + j) ? |cond_state_in[k]: |1'b0; // timing loop issue
        end


        cpu #(
          .n_pe(N_R*N_C),
          .id(i*N_C + j)
        )
        master_cpu 
        (
          .clk(clk),
          .rst(rst[i*N_C + j]), 
          .inst_en(inst_en),
          .preload(preload), 

          .lw_busy(mem_op[i*N_C + j]),
          .grid_state_in(busy),
          .cond_state(masked_cond[i*N_C + j]), 
          .trap(trap_or_finish[i*N_C + j]), 
          .cond_out(cond_state[i*N_C + j]),
          .grid_div(grid_div), 
      
          .i_n(pe_wire_s[(N_R+i-1)%N_R][j]),
          .i_s(pe_wire_n[(i+1)%N_R][j]),
          .i_e(pe_wire_w[i][(j+1)%N_C]),
          .i_w(pe_wire_e[i][(N_C+j-1)%N_C]),

          .o_n(pe_wire_n[i][j]), 
          .o_s(pe_wire_s[i][j]), 
          .o_e(pe_wire_e[i][j]), 
          .o_w(pe_wire_w[i][j]), 


          .imem_dina(imem_dina[i*N_C + j]), 
          .imem_wea(imem_wea[i*N_C + j]), 
          .imem_addra(imem_addra[i*N_C + j]),

          .lmem_dina(lmem_dina[i*N_C + j]),
          .lmem_wea(lmem_wea[i*N_C + j]),
          .lmem_addra(lmem_addra[i*N_C + j]),

          .dmem_addr(dmem_addr_temp[i*N_C + j]),
          .dmem_din(dmem_din[i*N_C + j]), // data to mem
          .dmem_dout(dmem_dout[i*N_C + j]), 
          .dmem_we(dmem_we[i*N_C + j]),
          .dmem_en(dmem_en[i*N_C + j]),


          .zero_pe_dmem_addr(zero_pe_dmem_addr[i*N_C + j]),
          .zero_pe_load_store_data_req(zero_pe_load_store_data_req[i*N_C + j]),
          .zero_pe_load_store_req(zero_pe_load_store_req[i*N_C + j]),
          .zero_pe_dmem_dout(zero_pe_dmem_dout[i*N_C + j]),
          .zero_pe_data_req_valid_i(zero_pe_data_req_valid_i[i*N_C + j]),
          .zero_pe_load_store_grant_i(zero_pe_load_store_grant_i[i*N_C + j]),


          .zero_pe_reg_we(zero_pe_reg_we[i*N_C + j]),
          .zero_pe_data(zero_pe_data[0]),

          .load_store_grant_i(load_store_grant_i[i*N_C + j]), 
          .data_req_valid_i(data_req_valid_i[i*N_C + j]), 
          .load_store_req(load_store_req[i*N_C + j]), 
          .load_store_data_req(load_store_data_req[i*N_C + j]),
          .dbg_mem_conflict(dbg_mem_conflict[i*N_C + j]),
          .dbg_ic(dbg_ic[i*N_C + j]),
          .dbg_ic_trap(dbg_ic_trap[i*N_C + j])
        );
      end else begin
        for (k = 0; k < n_pe; k = k + 1) begin : gen_mask
            assign masked_cond[i*N_C + j] = '0; // (k != i*N_C + j) ? |cond_state_in[k]: |1'b0;; // timing loop issue
        end
        cpu 
        #(
          .n_pe(N_R*N_C),
          .id(i*N_C + j)
        )
        cpu 
        (
          .clk(clk),
          .rst(rst[i*N_C + j]), 
          .inst_en(inst_en),
          .preload(preload), 

          .lw_busy(mem_op[i*N_C + j]),
          .grid_state_in(busy),
          .cond_state(masked_cond[i*N_C + j]), 
          .trap(trap_or_finish[i*N_C + j]), 
          .cond_out(cond_state[i*N_C + j]),
          .grid_div(grid_div), 
      
          .i_n(pe_wire_s[(N_R+i-1)%N_R][j]),
          .i_s(pe_wire_n[(i+1)%N_R][j]),
          .i_e(pe_wire_w[i][(j+1)%N_C]),
          .i_w(pe_wire_e[i][(N_C+j-1)%N_C]),

          .o_n(pe_wire_n[i][j]), 
          .o_s(pe_wire_s[i][j]), 
          .o_e(pe_wire_e[i][j]), 
          .o_w(pe_wire_w[i][j]), 


          .imem_dina(imem_dina[i*N_C + j]), 
          .imem_wea(imem_wea[i*N_C + j]), 
          .imem_addra(imem_addra[i*N_C + j]),

          .lmem_dina(lmem_dina[i*N_C + j]),
          .lmem_wea(lmem_wea[i*N_C + j]),
          .lmem_addra(lmem_addra[i*N_C + j]),

          .dmem_addr(dmem_addr_temp[i*N_C + j]),
          .dmem_din(dmem_din[i*N_C + j]), // data to mem
          .dmem_dout(dmem_dout[i*N_C + j]), 
          .dmem_we(dmem_we[i*N_C + j]),
          .dmem_en(dmem_en[i*N_C + j]),

          .zero_pe_dmem_addr(zero_pe_dmem_addr[i*N_C + j]),
          .zero_pe_load_store_data_req(zero_pe_load_store_data_req[i*N_C + j]),
          .zero_pe_load_store_req(zero_pe_load_store_req[i*N_C + j]),
          .zero_pe_dmem_dout(zero_pe_dmem_dout[i*N_C + j]),
          .zero_pe_data_req_valid_i(zero_pe_data_req_valid_i[i*N_C + j]),
          .zero_pe_load_store_grant_i(zero_pe_load_store_grant_i[i*N_C + j]),

          .zero_pe_reg_we(zero_pe_reg_we[i*N_C + j]),
          .zero_pe_data(zero_pe_data[0]),
          
          .load_store_grant_i(load_store_grant_i[i*N_C + j]), 
          .data_req_valid_i(data_req_valid_i[i*N_C + j]), 
          .load_store_req(load_store_req[i*N_C + j]), 
          .load_store_data_req(load_store_data_req[i*N_C + j]),
          .dbg_mem_conflict(dbg_mem_conflict[i*N_C + j]), 
          .dbg_ic(dbg_ic[i*N_C + j]),
          .dbg_ic_trap(dbg_ic_trap[i*N_C + j])
        );
      end
    end
  end
endgenerate


// ila_cpu_0 ila_cpu_0 (
//     .clk(clk),
//     .probe0(dbg_imem_addrb[0]),
//     .probe1(dbg_cpu_state[0]),
//     .probe2(dbg_inst[0])
// );


endmodule
