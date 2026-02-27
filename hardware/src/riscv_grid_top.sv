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
//           - `NB_LS`: Number of load/store signals.
//       * Interfaces:
//           - Instruction memory: `imem_dina`, `imem_wea`, `imem_addra`.
//           - Data memory: `host_dmem_addr`, `host_dmem_din`, `host_dmem_out`, etc.
//           - Load/store control: `host_load_store_data_req`, `host_load_store_req`.
//       * Handles tile selection and memory interface for host-driven operations.
// ==============================================================================


module riscv_grid_top # (
    parameter N_R = 4,
    parameter N_C = 2, 
    parameter NB_LS = N_R*N_C,
    parameter LOG2_NUM_PE = $clog2(N_R*N_C),
    parameter NB_XBAR_m = $clog2(N_R*N_C)
) (
    input logic                             clk, rst,
    input logic                             inst_en, 
    input logic                             preload, 
    output logic                            finish, 
    input logic [7:0]                       grid_div,
    input logic                             tcdm_arb_policy, // 0 --> Round Robin, 1 --> Priority min
    input logic                             mode_select, // 0 --> shared mode, 1 --> bypass mode
    // input logic [15:0] clk_en, 

    // instruction memory interface

    // reserve 4 MSB bits to located which tile
    // since we have 1024x32 bit for IMEM
    // Basically, we have 9 bits for IMEM address
    // [13:9] is used to located which tile ID 
    input logic [31:0]   imem_dina,
    input logic [3:0]    imem_wea, 
    input logic [9+LOG2_NUM_PE:0]   imem_addra,

    // dmem interface 
    // write_data <- host_load_store_data_req = 1
    // write_data <- host_load_store_req = 1
    // read_data <- host_load_store_data_req = 1
    // read_data <- host_load_store_req = 0
    // else all zero
    input logic         host_load_store_data_req,
    input logic 	    host_load_store_req,
    input logic  [31:0] host_dmem_addr,
    input logic  [31:0] host_dmem_din,

    output logic        host_load_store_grant_i, 
    output logic 	    host_data_req_valid_i,
    output logic [31:0] host_dmem_out,

`ifndef SYNTHESIS
    output logic [7:0]  dbg_nc, dbg_nr,
    output logic [7:0]  dbg_mc_temporal_out,
    output logic [(N_R*N_C)-1:0] dbg_finish,
    output logic [(N_R*N_C)-1:0][31:0] dbg_mem_conflict,
    output logic [(N_R*N_C)-1:0][31:0] dbg_ic, 
    output logic [(N_R*N_C)-1:0][31:0] dbg_ic_trap
`else 
    output logic [7:0]  dbg_nc, dbg_nr
`endif

); 


`ifdef SYNTHESIS
    logic [7:0]  dbg_nc, dbg_nr;
    logic [7:0]  dbg_mc_temporal_out;
    logic [(N_R*N_C)-1:0] dbg_finish;
    logic [(N_R*N_C)-1:0][31:0] dbg_mem_conflict;
    logic [(N_R*N_C)-1:0][31:0] dbg_ic;
    logic [(N_R*N_C)-1:0][31:0] dbg_ic_trap;
`endif

    assign dbg_nc = N_C; 
    assign dbg_nr = N_R; 

    // all of this is located in the signal
    // data memory interface
    logic [(N_R*N_C)-1:0][31:0] dmem_addr;
    logic [(N_R*N_C)-1:0][31:0] dmem_din; // data in to mem 
    logic [(N_R*N_C)-1:0][31:0] dmem_dout; // data out from mem 
    logic [(N_R*N_C)-1:0][3:0]  dmem_we;
    logic [(N_R*N_C)-1:0]       dmem_en; 

    // local memory interface
    logic [(N_R*N_C)-1:0][31:0] lmem_dina;
    logic [(N_R*N_C)-1:0][3:0]  lmem_wea;
    logic [(N_R*N_C)-1:0][9:0]  lmem_addra;

    // interconnect interface xbar logarithmic
    logic [(N_R*N_C)-1:0]        load_store_grant_i;
    logic [(N_R*N_C)-1:0]        data_req_valid_i;
    logic [(N_R*N_C)-1:0]        load_store_req;
    logic [(N_R*N_C)-1:0]        load_store_data_req;

    logic [(N_R*N_C)-1:0][31:0]   imem_din;
    logic [(N_R*N_C)-1:0][3:0]    imem_write_en;
    logic [(N_R*N_C)-1:0][13:0]   imem_address;
    logic host_data_req_valid_i_tmp; 
    logic cycle_count_en; 
    logic [15:0] clk_en;
    // logic mode_select; // 0 --> shared mode, 1 --> bypass mode
    assign clk_en = '1; 
    // assign mode_select = 1; // shared mode

    // assign imem_din[imem_addra[13:9]] = imem_dina; 
    // assign imem_write_en[imem_addra[13:9]] = imem_wea; 
    // assign imem_address[imem_addra[13:9]] = imem_addra[9:0];

    assign host_data_req_valid_i = host_data_req_valid_i_tmp ;
    integer i; 
    always @(*) begin 
        for (i=0; i<(N_R * N_C); i=i+1) begin
            imem_din[i] = imem_dina;
        end
    end

    always @(*) begin
        imem_address = '0;
        imem_write_en = '0;
        for (i=0; i<(N_R * N_C); i=i+1) begin
            if (imem_addra[10+LOG2_NUM_PE-1:10] == i[LOG2_NUM_PE-1:0]) begin
                imem_address[i] = {4'b0000, imem_addra[9:0]};
                imem_write_en[i] = imem_wea; 
            end
        end
    end

    logic [N_R*N_C-1:0] rst_pe;
    logic local_mem_temp_we; 
    assign local_mem_temp_we = host_load_store_req & host_load_store_data_req; 

    always @(*) begin
        for (i=0; i<N_R*N_C; i=i+1) begin
            if (host_dmem_addr[13:10] == i[LOG2_NUM_PE-1:0] && host_dmem_addr[19] == 1) begin
                lmem_wea[i] = {local_mem_temp_we,local_mem_temp_we,local_mem_temp_we,local_mem_temp_we}; 
                lmem_dina[i] = host_dmem_din; 
                lmem_addra[i] = host_dmem_addr[9:0]; 
            end
            else begin
                lmem_wea[i] = 0; 
                lmem_dina[i] = '0; 
                lmem_addra[i] = '0; 
            end
        end
    end


    logic [NB_LS-1:0][31:0] dmem_dout_mux_o; 
    logic [(N_R*N_C)-1:0]  load_store_grant_i_mux_o; 
    logic [(N_R*N_C)-1:0]  data_req_valid_i_mux_o; 

    logic [(N_R*N_C)-1:0]  load_store_req_reg;
    logic [(N_R*N_C)-1:0]  load_store_data_req_reg;

    always @(posedge clk) begin
        load_store_req_reg <= load_store_req;
        load_store_data_req_reg <= load_store_data_req;
    end


    grid # (
        .N_R(N_R),
        .N_C(N_C),
        .NB_LS(NB_LS)
    ) grid_unit (
        .clk(clk),
        .rst(rst_pe),
        .inst_en(inst_en), 
        .preload(preload), 
        .finish(finish), 
        .grid_div(grid_div), 

        .imem_dina(imem_din),
        .imem_wea(imem_write_en),
        .imem_addra(imem_address),

        .lmem_dina(lmem_dina),
        .lmem_wea(lmem_wea),
        .lmem_addra(lmem_addra),

        // output to mem 
        .dmem_addr(dmem_addr), 
        .dmem_din(dmem_din), // data to mem
        .dmem_we(),
        .dmem_en(dmem_en),
        .load_store_req(load_store_req), 
        .load_store_data_req(load_store_data_req),

        // input from mem 
        .dmem_dout(dmem_dout_mux_o), // data from mem
        .load_store_grant_i(load_store_grant_i_mux_o), 
        .data_req_valid_i(data_req_valid_i_mux_o), 


        .dbg_finish(dbg_finish),
        .dbg_mem_conflict(dbg_mem_conflict),
        .dbg_ic(dbg_ic),
        .dbg_ic_trap(dbg_ic_trap)
    );

    logic [NB_LS-1:0][31:0] zero_pe_dmem_addr;
    // assign zero_pe_dmem_addr_xbar = {'0, zero_pe_dmem_addr};
    // assign pe_rst = (inside_loop_count == iteration_end && iteration_end != '0 && loop_cycle_count != 31) ? 1:0;
    genvar i_gen;
    generate
        for (i_gen = 0; i_gen < N_R*N_C; i_gen=i_gen + 1) begin : gen_rst_pe
            assign rst_pe[i_gen] = rst;
        end
    endgenerate

    

    
    logic [NB_LS-1:0] mm_dmem_dout_valid; 
    logic [NB_LS-1:0][31:0] mm_dmem_din, mm_dmem_dout; 
    logic [NB_LS-1:0] mm_dmem_en; 
    logic [NB_LS-1:0][NB_LS-1:0] data_id_i;
    logic [NB_LS-1:0][NB_LS-1:0] data_id; 
    logic [NB_LS-1:0] host_data_id;
    logic [NB_LS-1:0] host_data_id_i;
    logic [NB_LS-1:0] mm_dmem_we; 
    logic [NB_LS-1:0][26:0] mm_dmem_addr; 



    always @(posedge clk) begin
        data_id_i <= data_id; 
        host_data_id_i <= host_data_id; 
        mm_dmem_dout_valid <= mm_dmem_en;
    end

    logic [(N_R*N_C)-1:0][33:0] dmem_addr_xbar;
    logic [32+1:0] host_dmem_addr_xbar; 

    generate
        for(i_gen = 0; i_gen < N_R*N_C; i_gen = i_gen + 1) begin : gen_dmem_addr_xbar
            assign dmem_addr_xbar[i_gen] = {'0, dmem_addr[i_gen]};
        end
    endgenerate
    assign host_dmem_addr_xbar = {'0, host_dmem_addr};
    logic TCDM_arb_policy_i;
    assign TCDM_arb_policy_i = tcdm_arb_policy;

    logic host_load_store_data_req_xbar; 
    logic host_load_store_req_xbar; 

    assign host_load_store_data_req_xbar = (host_dmem_addr[19] != 1) ? host_load_store_data_req : '0; 
    assign host_load_store_req_xbar = (host_dmem_addr[19] != 1) ? host_load_store_req : '0; 

    

    XBAR_TCDM 
    #( 
        .N_CH0(NB_LS + 1), 
        .N_CH1(0),  
        .N_SLAVE(NB_LS), 
        .ADDR_WIDTH(33+1),
        .DATA_WIDTH(32),
        .ADDR_MEM_WIDTH(27)
    ) xbar_tcdm_unit (
        // ---------------- MASTER CH0+CH1 SIDE  -------------------------- 
        .data_req_i             ({host_load_store_data_req_xbar, load_store_data_req}), 
        .data_add_i             ({host_dmem_addr_xbar, dmem_addr_xbar}),
        .data_wen_i             ({host_load_store_req_xbar, load_store_req}),            // Data request type : 0--> Store, 1 --> Load
        .data_wdata_i           ({host_dmem_din, dmem_din}),          // Data request Write data
        .data_be_i              (('1)),             // Data request Byte enable
        .data_gnt_o             ({host_load_store_grant_i, load_store_grant_i}),            // Grant Incoming Request
        .data_r_valid_o         ({host_data_req_valid_i_tmp, data_req_valid_i}),        // Data Response Valid (For LOAD/STORE commands)
        .data_r_rdata_o         ({host_dmem_out, dmem_dout}),        // Data Response DATA (For LOAD commands)
        .data_req_o             (mm_dmem_en),            // Data request

        // ---------------- MM_SIDE (Interleaved) --------------------------
        .data_ts_set_o(),         // Current Request is a SET during a test&set
        .data_add_o             (mm_dmem_addr),            // Data request Address
        .data_wen_o             (mm_dmem_we),            // Data request type : 0--> Store, 1 --> Load
        .data_wdata_o           (mm_dmem_din),          // Data request Wrire data
        .data_be_o(),             // Data request Byte enable 
        .data_ID_o              ({host_data_id, data_id}),             // Data request Byte enable 
        .data_gnt_i             (mm_dmem_en),            // Grant In
        .data_r_rdata_i         (mm_dmem_dout),        // Data Response DATA (For LOAD commands)
        .data_r_valid_i         (mm_dmem_dout_valid),        // Valid Response 
        .data_r_ID_i            ({host_data_id_i, data_id_i}),          // ID Response
        .TCDM_arb_policy_i      (TCDM_arb_policy_i),
        .clk(clk),
        .rst_n(!rst)
    );



    logic [NB_LS-1:0][3:0] mm_we, mm_we_dbg; 
    generate
        for (i_gen = 0; i_gen < NB_LS; i_gen = i_gen + 1) begin : gen_mm_we
            assign mm_we[i_gen] = {4{mm_dmem_we[i_gen]}} & {4{host_load_store_grant_i}};
        end
    endgenerate

    logic [NB_LS-1:0][3:0] mm_we_mux_o; 
    logic [NB_LS-1:0][31:0] mm_dmem_din_mux_o; 
    logic [NB_LS-1:0][26:0] mm_dmem_addr_mux_o; 

    // Mux for memory input
    always @(*) begin
        if (mode_select == 0) begin // shared mode
            mm_we_mux_o = mm_we;
            mm_dmem_din_mux_o = mm_dmem_din;
            mm_dmem_addr_mux_o = mm_dmem_addr;
        end else begin // bypass mode
            // mm_we_mux_o = ;
            integer i_gen; 
            for (i_gen = 0; i_gen < NB_LS; i_gen = i_gen + 1) begin : gen_mm_we_mux_o
                mm_we_mux_o[i_gen] = dmem_addr[i_gen][31:28];
                mm_dmem_addr_mux_o[i_gen] = dmem_addr[i_gen][26:0];
            end
            mm_dmem_din_mux_o = dmem_din;

        end
    end

    // Mux for memory output
    always @(*) begin
        if (mode_select == 0) begin // shared mode
            dmem_dout_mux_o = dmem_dout; 
            load_store_grant_i_mux_o = load_store_grant_i; 
            data_req_valid_i_mux_o = data_req_valid_i; 
        end else begin // bypass mode
            dmem_dout_mux_o = mm_dmem_dout; 
            load_store_grant_i_mux_o =  load_store_data_req; 
            data_req_valid_i_mux_o = load_store_data_req_reg; 
        end
    end

    // TCDM memory interface
    tcdm #(
        .nslave(NB_LS)
    ) tcdm (
        .clk(clk),
        .dmem_en('1),
        .dmem_we(mm_we_mux_o),
        .dmem_addr(mm_dmem_addr_mux_o),
        .dmem_din(mm_dmem_din_mux_o), // data in to mem 
        .dmem_dout(mm_dmem_dout) // data out from mem 
    );



// trace section 
// I want to trace the memory conflict. 
// The memory conflict is occurred when the same address is accessed by multiple pe at the same time. 
// The memory conflict is occurred when it was in the memory operation. 
// The memory operation is defined as the load_store_data_req is 1 or the load_store_req is 1. 

`ifndef SYNTHESIS
    logic [7:0] dbg_mc_temporal = '0; 
    integer xx; 
    integer yy; 
    integer zz; 
    integer index;
    integer index_y;
    logic [N_R*N_C-1:0][7:0] dbg_mc_temporal_map = '0; 

    logic processed [0:N_R*N_C-1]; // Flag to track processed indices



    always @(*) begin 
        if (inst_en == 1) begin 
            // foreach (dmem_addr[xx]) begin 
            dbg_mc_temporal_out = '0; 
            for (xx=0; xx < N_R*N_C; xx++) begin 
                dbg_mc_temporal_map[xx] = '0; 
                processed[xx] = 0;
            end 

            for (xx=0; xx < N_R*N_C; xx++) begin 
                if (load_store_data_req[xx] || load_store_req[xx]) begin 
                    index = dmem_addr[xx][31:2] % (N_R * N_C);
                    if (processed[xx] == 0) begin 
                        for (yy=xx+1; yy < N_R*N_C; yy++) begin 
                            index_y = dmem_addr[yy][31:2] % (N_R * N_C);
                            if ((load_store_data_req[yy] || load_store_req[yy])) begin 
                                if (index_y == index && processed[yy] == 0) begin 
                                    dbg_mc_temporal_map[index] = dbg_mc_temporal_map[index] + 1; 
                                    processed[yy] = 1;
                                    processed[xx] = 1; 
                                end
                            end
                        end
                    end
                end
            end

            for (xx=0; xx < N_R*N_C; xx++) begin 
                dbg_mc_temporal_out = dbg_mc_temporal_out + dbg_mc_temporal_map[xx]; 
                processed[xx] = 0;
            end
        end
    end
`endif



endmodule

`define log2_non_zero(VALUE) ((VALUE) < ( 1 ) ? 1 : (VALUE) < ( 2 ) ? 1 : (VALUE) < ( 4 ) ? 2 : (VALUE)< (8) ? 3:(VALUE) < ( 16 )  ? 4 : (VALUE) < ( 32 )  ? 5 : (VALUE) < ( 64 )  ? 6 : (VALUE) < ( 128 ) ? 7 : (VALUE) < ( 256 ) ? 8 : (VALUE) < ( 512 ) ? 9 : 10)

module tcdm #(
    parameter nslave = 16,
    parameter log2_nslave = `log2_non_zero(nslave)
) (
    input               clk,
    input logic [nslave-1:0]        dmem_en, 
    input logic [nslave-1:0][3:0]   dmem_we, 
    input logic [nslave-1:0][26:0]  dmem_addr, 
    input logic [nslave-1:0][31:0]  dmem_din, 
    output logic [nslave-1:0][31:0] dmem_dout
);
    genvar k;
    logic [log2_nslave-1:0] wire_k; 
    generate
    for (k=0; k<nslave; k++) begin
        logic [log2_nslave-1:0] wire_k = k; 
        dmem #(
            .n_bank(nslave)
        ) dmem (
            .clk(clk),
            .en(dmem_en[k]),
            .we(dmem_we[k]),
            .dmem_id(wire_k),
            .addr(dmem_addr[k][26:0]),
            .din(dmem_din[k]), // data in to mem 
            .dout(dmem_dout[k]) // data out from mem 
        );
    end
    endgenerate

endmodule



