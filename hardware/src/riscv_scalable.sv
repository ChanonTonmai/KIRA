// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    riscv_scalable
// Module Name:    riscv_scalable
// File Name:      riscv_scalable.sv
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
//   - This module is used to implement the scalable RISC-V core.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------

module riscv_scalable #(
  parameter CL = 8, 
  parameter N_R = 4, 
  parameter N_C = 2, 
  parameter N_PE = N_C*N_R*CL, 
  parameter N_PE_PER_CLUSTER = N_PE/CL,
  parameter LOG2_NUM_PE = $clog2(N_PE)
) (
  input logic clk, rst,
  input logic inst_en, 
  input logic preload, 
  output logic finish, 
  input logic [7:0] grid_div, 
  input logic mode_select, // 0 --> shared mode, 1 --> bypass mode
  input logic tcdm_arb_policy, // 0 --> Round Robin, 1 --> Priority min

  // instruction memory interface
  input logic [31:0] imem_dina, 
  input logic [3:0] imem_wea, 
  input logic [9+LOG2_NUM_PE:0] imem_addra,

  input logic           host_load_store_data_req,
  input logic 	        host_load_store_req,
  input logic  [31:0]   host_dmem_addr,
  input logic  [31:0]   host_dmem_din,
  input logic  [CL-1:0] host_dmem_cluster_ena, // one-hot encoding

  output logic        host_load_store_grant_i, 
  output logic 	      host_data_req_valid_i,
  output logic [31:0] host_dmem_out,

`ifndef SYNTHESIS
  output logic [7:0]  dbg_nc, dbg_nr, dbg_cl,
  output logic [(N_R*N_C*CL)-1:0][31:0] dbg_mem_conflict,
  output logic [(N_R*N_C*CL)-1:0][31:0] dbg_ic,
  output logic [(N_R*N_C*CL)-1:0][31:0] dbg_ic_trap,
  output logic [7:0] dbg_mc_temporal,
  output logic [(N_R*N_C*CL)-1:0] dbg_finish
`else 
  output logic [7:0]  dbg_nc, dbg_nr
`endif
); 

logic [31:0] imem_dina_cluster [CL-1:0];
logic [3:0] imem_wea_cluster [CL-1:0]; 
logic [9+LOG2_NUM_PE:0] imem_addra_cluster [CL-1:0];

assign dbg_cl = CL; 

// N_PE = 16 (CL=1) LOG2_NUM_PE = 4 -> imem_addra[13:0] [13:10] -> 4 bits represent which PE in the cluster
// N_PE = 32 (CL=2) LOG2_NUM_PE = 5 -> imem_addra[14:0] [14:10] -> 5 bits represent which PE in the cluster
// However, the PE is clustered in 16 PE in each cluster. The PE number 16-31 has imem_addra[14] = 1


logic [$clog2(CL)-1:0]  imem_cluster_ena;
generate 
  if (N_PE_PER_CLUSTER == 16) begin
    assign imem_cluster_ena = imem_addra[14+$clog2(CL)-1:14];
  end else if (N_PE_PER_CLUSTER == 8) begin
    assign imem_cluster_ena = imem_addra[13+$clog2(CL)-1:13];
  end
endgenerate
// assign imem_cluster_ena = imem_addra[14+$clog2(CL)-1:14];
// assign imem_cluster_ena = imem_addra[13+$clog2(CL)-1:13];

integer idx;  
always @(*) begin
  for (idx=0; idx<CL; idx++) begin
    if (imem_cluster_ena == idx) begin
      imem_dina_cluster[idx] = imem_dina;
      imem_wea_cluster[idx] = imem_wea;
      imem_addra_cluster[idx] = imem_addra;
    end else begin
      imem_dina_cluster[idx] = '0;
      imem_wea_cluster[idx] = '0;
      imem_addra_cluster[idx] = '0;
    end
  end
end


// TCDM Write 
logic [CL-1:0] host_load_store_data_req_cluster;
logic [CL-1:0] host_load_store_req_cluster;
logic [31:0] host_dmem_addr_cluster;
logic [31:0] host_dmem_din_cluster;
always @(*) begin
  if (host_dmem_cluster_ena[0] == 1) begin
    host_load_store_data_req_cluster[0] = host_load_store_data_req;
    host_load_store_req_cluster[0] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[1] == 1) begin
    host_load_store_data_req_cluster[1] = host_load_store_data_req;
    host_load_store_req_cluster[1] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[2] == 1) begin
    host_load_store_data_req_cluster[2] = host_load_store_data_req;
    host_load_store_req_cluster[2] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[3] == 1) begin
    host_load_store_data_req_cluster[3] = host_load_store_data_req;
    host_load_store_req_cluster[3] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[4] == 1) begin
    host_load_store_data_req_cluster[4] = host_load_store_data_req;
    host_load_store_req_cluster[4] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[5] == 1) begin
    host_load_store_data_req_cluster[5] = host_load_store_data_req;
    host_load_store_req_cluster[5] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[6] == 1) begin
    host_load_store_data_req_cluster[6] = host_load_store_data_req;
    host_load_store_req_cluster[6] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;
  end else if (host_dmem_cluster_ena[7] == 1) begin
    host_load_store_data_req_cluster[7] = host_load_store_data_req;
    host_load_store_req_cluster[7] = host_load_store_req;
    host_dmem_addr_cluster = host_dmem_addr;
    host_dmem_din_cluster = host_dmem_din;

  end else begin  
    host_load_store_data_req_cluster = '0;
    host_load_store_req_cluster = '0;
    host_dmem_addr_cluster = '0;
    host_dmem_din_cluster = '0;
  end 
end

// TCDM Read 
logic host_load_store_grant_i_cluster [CL-1:0];
logic host_data_req_valid_i_cluster [CL-1:0];
logic [31:0] host_dmem_out_cluster [CL-1:0];  
always @(*) begin
  if (host_dmem_cluster_ena[0] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[0];
    host_data_req_valid_i = host_data_req_valid_i_cluster[0];
    host_dmem_out = host_dmem_out_cluster[0];
  end else if (host_dmem_cluster_ena[1] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[1];
    host_data_req_valid_i = host_data_req_valid_i_cluster[1];
    host_dmem_out = host_dmem_out_cluster[1];
  end else if (host_dmem_cluster_ena[2] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[2];
    host_data_req_valid_i = host_data_req_valid_i_cluster[2];
    host_dmem_out = host_dmem_out_cluster[2];
  end else if (host_dmem_cluster_ena[3] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[3];
    host_data_req_valid_i = host_data_req_valid_i_cluster[3];
    host_dmem_out = host_dmem_out_cluster[3];
  end else if (host_dmem_cluster_ena[4] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[4];
    host_data_req_valid_i = host_data_req_valid_i_cluster[4];
    host_dmem_out = host_dmem_out_cluster[4];
  end else if (host_dmem_cluster_ena[5] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[5];
    host_data_req_valid_i = host_data_req_valid_i_cluster[5];
    host_dmem_out = host_dmem_out_cluster[5];
  end else if (host_dmem_cluster_ena[6] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[6];
    host_data_req_valid_i = host_data_req_valid_i_cluster[6];
    host_dmem_out = host_dmem_out_cluster[6];
  end else if (host_dmem_cluster_ena[7] == 1) begin
    host_load_store_grant_i = host_load_store_grant_i_cluster[7];
    host_data_req_valid_i = host_data_req_valid_i_cluster[7];
    host_dmem_out = host_dmem_out_cluster[7];
  end else begin
    host_load_store_grant_i = '0; 
    host_data_req_valid_i = '0; 
    host_dmem_out = '0;   
  end  
end

logic [CL-1:0] finish_cluster;
logic temp_finish;

always @(*) begin
  if (finish_cluster == '1) begin
    temp_finish = 1'b1;
  end else begin
    temp_finish = 1'b0;
  end
end


assign finish = temp_finish;

`ifndef SYNTHESIS
  logic [CL-1:0][N_R*N_C-1:0][31:0] dbg_mem_conflict_temp;
  logic [CL-1:0][N_R*N_C-1:0][31:0] dbg_ic_temp;
  logic [CL-1:0][N_R*N_C-1:0][31:0] dbg_ic_trap_temp;

  logic [CL-1:0][7:0] dbg_mc_temporal_temp;
  logic [CL-1:0][N_R*N_C-1:0] dbg_finish_temp;
  always @(*) begin
    for (int ii=0; ii<CL; ii++) begin
      for (int jj=0; jj<N_R*N_C; jj++) begin
        dbg_mem_conflict[ii*(N_R*N_C)+jj] = dbg_mem_conflict_temp[ii][jj];
        dbg_ic[ii*(N_R*N_C)+jj] = dbg_ic_temp[ii][jj];
        dbg_ic_trap[ii*(N_R*N_C)+jj] = dbg_ic_trap_temp[ii][jj];
      end
    end
  end


  generate
    if (CL == 2) begin 
      assign dbg_finish = {dbg_finish_temp[1], dbg_finish_temp[0]};
      assign dbg_mc_temporal =  dbg_mc_temporal_temp[0] + dbg_mc_temporal_temp[1];
    end else if (CL == 4) begin 
      assign dbg_finish = {dbg_finish_temp[3], dbg_finish_temp[2], dbg_finish_temp[1], dbg_finish_temp[0]};
      assign dbg_mc_temporal = dbg_mc_temporal_temp[3] + dbg_mc_temporal_temp[2] + dbg_mc_temporal_temp[1] + dbg_mc_temporal_temp[0];
    end else if (CL == 8) begin 
      assign dbg_finish = {dbg_finish_temp[7], dbg_finish_temp[6], dbg_finish_temp[5], dbg_finish_temp[4], dbg_finish_temp[3], dbg_finish_temp[2], dbg_finish_temp[1], dbg_finish_temp[0]};
      assign dbg_mc_temporal = dbg_mc_temporal_temp[7] + dbg_mc_temporal_temp[6] + dbg_mc_temporal_temp[5] + dbg_mc_temporal_temp[4] + dbg_mc_temporal_temp[3] + dbg_mc_temporal_temp[2] + dbg_mc_temporal_temp[1] + dbg_mc_temporal_temp[0];
    end else begin 
      assign dbg_finish = '0;
      assign dbg_mc_temporal = '0;
    end
  endgenerate
`endif



genvar i; 
generate 
  for (i=0; i<CL; i++) begin : gen_cluster
    riscv_grid_top #(
      .N_R(N_R),
      .N_C(N_C)
    ) riscv_grid_top_unit ( 
      .clk(clk), 
      .rst(rst), 
      .inst_en(inst_en), 
      .preload(preload), 
      .finish(finish_cluster[i]), 
      .grid_div(grid_div), 
      .tcdm_arb_policy(tcdm_arb_policy),
      .mode_select(mode_select),
      
      .imem_dina(imem_dina_cluster[i]), 
      .imem_wea(imem_wea_cluster[i]), 
      .imem_addra(imem_addra_cluster[i]), 

      .host_load_store_data_req(host_load_store_data_req_cluster[i]), 
      .host_load_store_req(host_load_store_req_cluster[i]),   
      .host_dmem_addr(host_dmem_addr_cluster),      
      .host_dmem_din(host_dmem_din_cluster), 

      .host_load_store_grant_i(host_load_store_grant_i_cluster[i]), 
      .host_data_req_valid_i(host_data_req_valid_i_cluster[i]), 
      .host_dmem_out(host_dmem_out_cluster[i]), 


`ifndef SYNTHESIS
      .dbg_mc_temporal_out(dbg_mc_temporal_temp[i]),
      .dbg_finish(dbg_finish_temp[i]),
      .dbg_ic(dbg_ic_temp[i]),
      .dbg_ic_trap(dbg_ic_trap_temp[i]),
      .dbg_nc(dbg_nc), 
      .dbg_nr(dbg_nr),
      .dbg_mem_conflict(dbg_mem_conflict_temp[i])
`else 
      .dbg_nc(dbg_nc), 
      .dbg_nr(dbg_nr)
`endif
    ); 
  end
endgenerate


endmodule