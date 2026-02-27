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
// Design Name:    cpu
// Module Name:    cpu
// File Name:      cpu.sv
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
//   - This module is used to implement the RISC-V core.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
//
// 
// Additional Comments:
//   - Key Ports:
//       * Clock and Reset:
//         - `clk`: Clock signal.
//         - `rst`: Reset signal.
//       * Instruction Memory Interface:
//         - `imem_dina`, `imem_wea`, `imem_addra`: Control signals for instruction memory.
//       * Data Memory Interface:
//         - `dmem_addr`, `dmem_din`, `dmem_dout`, `dmem_we`, `dmem_en`: Data memory access.
//       * Interconnect Interface:
//         - `load_store_req`, `load_store_data_req`, `load_store_grant_i`, `data_req_valid_i`: Signals for memory transactions.
//   - Handles synchronous read and write operations for memory modules.
//   - Implements logic for processing grid states and handling ALU operations.
// ==============================================================================



module cpu 
  #(
    parameter n_pe=16,
    parameter log2_n_pe = $clog2(n_pe),
    parameter agu_ena=1, 
    parameter id=0
  )
  (
    input clk, 
    input rst, 
    input inst_en, // assert to enable the instruction address increment
    input preload, 
    
    output lw_busy, 
    input  [n_pe-1:0] grid_state_in, // grid status 
    input  [n_pe-1:0] cond_state, 
    output logic trap,
    output logic cond_out, 
    input [7:0] grid_div, 

    input  [31:0] i_n, i_e, i_s, i_w, 
    output [31:0] o_n, o_e, o_s, o_w, 

    // instruction memory interface 
    input logic [31:0] imem_dina, 
    input logic [3:0]  imem_wea, 
    input logic [13:0] imem_addra,

    // local memory interface
    input logic [31:0] lmem_dina, 
    input logic [3:0]  lmem_wea, 
    input logic [9:0]  lmem_addra,

    // data memory interface
    output  logic [31:0] dmem_addr,
    output  logic [31:0] dmem_din,  // data in to mem 
    input   logic [31:0] dmem_dout, // data out from mem 
    output  logic [3:0]  dmem_we,
    output  logic        dmem_en, 

    // interconnect interface 
    input   logic        load_store_grant_i, 
    input   logic        data_req_valid_i, 
    output  logic        load_store_req, 
    output  logic        load_store_data_req,

    // zero tcdm interface
    output  logic [31:0] zero_pe_dmem_addr,
    output  logic        zero_pe_load_store_data_req,
    output  logic        zero_pe_load_store_req,
    input   logic [31:0] zero_pe_dmem_dout,
    input   logic        zero_pe_data_req_valid_i,
    input   logic        zero_pe_load_store_grant_i,

    input   logic        zero_pe_reg_we,
    input   logic [31:0] zero_pe_data,

    // analsis signals 
    output logic [31:0] dbg_mem_conflict,
    output logic [31:0] dbg_ic, 
    output logic [31:0] dbg_ic_trap
  );
    
    logic [n_pe-1:0] mem_mask;
    always_comb begin
        mem_mask = '1; // Start with all bits set
        mem_mask[id] = 1'b0; // Clear the bit at position 'id'
    end

    logic [31:0] imem_doutb;
    logic [13:0] imem_addrb;
    logic [13:0] imem_addr; 
    logic imem_ena;
    reg [31:0] pc; 
    reg [31:0] inst; 
    reg [31:0] imm;
    reg [31:0] alu; 
    reg [31:0] wb_val; 
    
    // control logic 
    reg [1:0] pcsel; 
    reg immsel; 
    reg regwen; 
    reg brun, brlt, breq; 
    reg asel, bsel; 
    reg [3:0] alusel; 
    reg memrw; 
    reg [1:0] wbsel; 
    reg [3:0] memoutsel;
    logic br_taken; 
    
    reg [31:0] csr_reg; 
    reg [31:0] rs1, rs2;
    reg [31:0] rs1_in, rs2_in;
    reg [31:0] data_in;
    reg is_lw_x; 
    reg is_sw_x; 
    reg is_mul, is_addsub;
    logic load_store_grant_i_reg; 


    localparam [2:0] cpu_state_fetch  = 3'b000; // 0
    localparam [2:0] cpu_state_rs     = 3'b001; // 1
    localparam [2:0] cpu_state_mem    = 3'b010; // 2
    localparam [2:0] cpu_state_idle   = 3'b011; // 3
    localparam [2:0] cpu_state_trap   = 3'b100; // 4
    localparam [2:0] cpu_state_wait   = 3'b101; // 5
    localparam [2:0] cpu_state_pc     = 3'b110; // 6

    localparam RESET_PC = 32'h1000_0000;

    reg is_lw; 
    reg is_sw; 

    logic is_corf_lui; 
    logic is_corf_addi; 
    logic is_offs_addi; 
    logic is_psrf_addi; 
    logic is_psrf_rst; 
    logic is_ppsrf_addi; 
    logic is_psrf_branch; 
    logic is_psrf_lw; 
    logic is_psrf_sw; 
    logic is_psrf_zd_lw; 
    logic [17:0] psrf_addr;

    logic is_hwLrf_addi; 
    logic is_hwLrf_lui; 
    
    logic is_hwloop_pc_end; 
    logic is_loopcnt_end; 
    logic is_loop_notend; 
    logic [5:0] loop_start, loop_end; 

    logic [31:0] pc_hwloop;
    logic [15:0] loop_count; 
    logic [4:0] hwLrf_wa; 
    logic [1:0] pcsel_upper;

    reg [31:0] pc_state; 
    reg [2:0] cpu_state; 
    logic inst_trap; 

    logic [4:0] hwl_tag_en_1;
    logic [4:0] hwl_tag_en_2;
    logic [4:0] hwl_tag_en_3;
    logic [4:0] hwl_tag_en_4;
    logic [4:0] hwl_tag_en_5;
    logic [4:0] hwl_tag_en_6;
    logic [4:0] hwl_tag_en_7;

    reg we;
    reg [4:0] ra1, ra2, wa, wa_x, wa_master;
    reg [31:0] wd;
    wire [31:0] rd1, rd2;

    reg mem_operation; 
    reg mem_op_in_state; 
    logic [4:0] hwLrf_tag_end; 
    logic [3:0] grid_state_sum; 
    logic pc_hwl_end_zero_flag; 
    logic vec_op_en; 

    reg [31:0] rs1_x, rs2_x, inst_x, imm_x, pc_x; 
    reg regwen_x; 
    logic [1:0] wbsel_x;

    logic [n_pe-1:0] const_mask, and_mask, grid_mask; 
    logic [7:0] id_vec; 

    logic [n_pe-1:0] one_hot_id; 
    always @(*) begin
      one_hot_id = '0; // Default all bits to 0
      one_hot_id[id_vec[log2_n_pe-1:0]] = 1'b1; // Set the corresponding bit to 1
    end

    logic is_sync_beq; 
    assign id_vec = id; 
    assign cond_out = (is_sync_beq) ? 1'b0 : br_taken; 

    generate
      if (n_pe==32) begin
        assign const_mask = 32'b1; assign and_mask = 32'b11111;
      end else if (n_pe==16) begin
        assign const_mask = 16'b1; assign and_mask = 16'b1111;
      end else if (n_pe==64) begin
        assign const_mask = 64'b1; assign and_mask = 64'b111111;
      end else if (n_pe == 8) begin
        assign const_mask = 8'b1;  assign and_mask = 8'b111;
      end else begin
        assign const_mask = '1; assign and_mask = '1;
      end
    endgenerate

    // The principal of grid_mask is to get the one_hot_id for the current PE
    // The one_hot_id is the id of the PE in one hot encoding 
    // For example, if id_vec=5, then one_hot_id[1]=1, thus one_hot_id=16'b0000_0000_0010_0000. 
    // To create a cluster group, the temp_grid is build based on the grid_div. 
    // The grid_div is the divider of the number of PEs in the grid. 
    // For example, if n_pe=16 and grid_div=2, then it means there is 2 clusters in the grid.
    // We will have const_mask = 16'b1111_1111; and_mask = 16'b1000;
    // The temp_grid would be follow the equation: temp_grid = (const_mask << (id_vec & and_mask));
    // In this case, temp_grid = 16'b1111_1111;
    // which make the grid_mask = one_hot_id | temp_grid = 16'b1111_1111;
    // Thus, it will ignore the upper 8 PEs grid state signal. 

    logic [n_pe-1:0] temp_grid, grid_state;
    assign temp_grid = (const_mask << (id_vec & and_mask));
    assign grid_mask = (one_hot_id) | (temp_grid); 

      
    always @(posedge clk) begin
      if (rst) begin
        load_store_grant_i_reg <= '0;
      end else begin
        load_store_grant_i_reg <= load_store_grant_i; 
      end
    end

    reg [31:0] mem_dmem_dout;
    assign mem_dmem_dout = dmem_dout; // data read from DMEM 
    assign grid_state = (grid_state_in & grid_mask); 
    assign imem_addr = (imem_wea == '1) ? imem_addra : imem_addrb;

    imem imem (
      .clk(clk),
      .ena(imem_ena || imem_wea),
      .wea(imem_wea),
      .addra(imem_addr),
      .dina(imem_dina), // idata write
      .doutb(imem_doutb) // idata read 
    );


    reg_file rf (
        .clk(clk),
        .we(we),  
        .ra1(ra1), .ra2(ra2), .wa(wa_master), //| wa_x
        .wd(wd), 
        .rd1(rd1), .rd2(rd2)
    );

    assign is_lw = inst[6:0] == 7'b0000011 || inst[6:0] == 7'b0000100;
    assign is_sw = inst[6:0] == 7'b0100011 || inst[6:0] == 7'b0100100;;

    always @(*) begin 
      if (lw_busy ) begin 
        wa_master = wa_x; 
      end else begin
        wa_master = wa; 
      end
    end

    

    always @(*) begin
      if (cpu_state != cpu_state_idle && cpu_state != cpu_state_mem) begin 
        if (pc != 32'h10000000 && pc != 32'h800)  begin//&& pc != 32'h800) begin
          if (inst[31:0] == '0 || inst_x == '0) begin
            if (is_lw || is_sw || is_lw_x || is_sw_x) begin 
              inst_trap = 0; 
            end else begin
              inst_trap = 1;
            end 
          end else begin 
            inst_trap = 0; 
          end
        end else begin
          inst_trap = 0; 
        end
      end else begin 
        inst_trap = 0; 
      end 
    end


    assign lw_busy = mem_operation;
    always @(posedge clk) begin 
      if (rst) begin 
        trap <= 0; 
      end else begin 
        trap <= inst_trap; 
      end
    end
    
    // control logic
    control_logic # (
      .n_pe(n_pe)
    )
      cl (
        .clk(clk),
        .inst(inst), 
        .pcsel(pcsel), 
        .regwen(regwen), 
        .brun(brun), 
        .brlt(brlt), 
        .breq(breq), 
        .cond_state('0), 
        .is_sync_beq('0), 
        .vec_op_en(vec_op_en), 
        .asel(asel), 
        .bsel(bsel), 
        .alusel(alusel), 
        .memrw(memrw), 
        .wbsel(wbsel), 
        .br_taken_out(br_taken)
    ); 
    
    // pc update => pc + 4 or alu
    logic pc_write_master; 
    reg [31:0] next_pc; 
    logic pc_write; 
    next_pc #(
      .RESET_PC(RESET_PC)
    ) fn ( 
      .clk(clk),
      .rst(rst), 
      .preload(preload), 
      .pc(pc), 
      .alu(alu), 
      .pc_hwloop(pc_hwloop), 
      .pcsel(pcsel | pcsel_upper), 
      .ena(pc_write_master), // enable the next pc 
      .next_pc(pc)
    ); 

    always @(*) begin 
      if (is_lw || is_sw) begin 
        pc_write_master = 0; 
      end else if (grid_state == 0) begin 
        if (cpu_state == cpu_state_idle || cpu_state == cpu_state_trap) begin 
          pc_write_master = pc_write; 
        end else begin 
          pc_write_master = 1; 
        end
      end else if (grid_state != 0) begin 
        pc_write_master = 0; 
      end else begin 
        pc_write_master = pc_write; 
      end 
    end
    
    // assign pc = next_pc ; 
    fetch_inst fi ( 
      .pc(pc), 
      .imem_dout(imem_doutb),
      // .pc_hwl_end_zero_flag(pc_hwl_end_zero_flag),
      .pc_hwl_end_zero_flag('0),
      // Outputs
      .imem_addr(imem_addrb),
      .inst(inst)
    );
    
    imm_generator immgen (
      .inst(inst), // Inputs 
      .imm(imm) // Outputs
    );
    

    read_reg regread ( 
        .inst(inst), 
        .rd1(rd1), // register data from ra1
        .rd2(rd2), // register data from ra2
        .is_psrf_sw(is_psrf_sw),
        .i_n(i_n), .i_s(i_s), .i_e(i_e), .i_w(i_w), 
        .ra1(ra1), // decode register address
        .ra2(ra2), // decode register address 
        .rs1(rs1), // pass value from rd1
        .rs2(rs2)  // pass value from rd2
    ); 
    

    always @(posedge clk) begin
      if (rst) begin
        inst_x <= '0; 
      end else begin
        // rs1_x <= rs1; 
        // rs2_x <= rs2; 
        regwen_x <= regwen;
       
        // imm_x <= imm; 
        pc_x <= pc; 
        if (imem_ena) begin 
          inst_x <= inst; 
          wbsel_x <= wbsel; 
        end 
      end
    end

    // Force to 0 for unused this sync
    assign is_sync_beq = '0; // (inst[6:0] == 7'h65) ? 1:0; 
    
    

    logic [15:0] masked_cond;
    genvar j;
    // generate
    //     for (j = 0; j < n_pe; j = j + 1) begin : gen_mask
    //         assign masked_cond[j] = 0; //(j != id) ? cond_state[j]: 1'b0;
    //     end
    // endgenerate

    branch_comp  #(
      .id(id),
      .n_pe(n_pe)
    ) compfd (
      // Inputs
      .clk(clk),
      .brun(brun),
      .grid_id(id_vec), 
      .is_sync_beq(is_sync_beq), 
      .cond_state(masked_cond),
      .rs1(rs1),
      .rs2(rs2),
      // Outputs
      .brlt(brlt),
      .breq(breq)
    );    
    

    // mux with asel, bsel 
    assign rs2_in = (bsel) ? imm: rs2;//: rs2_in_reg; 
    assign rs1_in = (asel) ? pc:  rs1;//: rs1_in_reg; 
    
    // alu operation 
    alu alunit (
      // Inputs
      .clk(clk),
      .rs1(rs1_in),
      .rs2(rs2_in),
      .vec_op_en(vec_op_en),
      .alu_sel(alusel),
      // Outputs
      .out(alu)
    );
    
    
    // DMEM stage ////////////////////////////
    wire [31:0] add_x = alu;
    // Writing to DMEM 
    reg [3:0] wr_mask;
    gen_wr_mask masker (
      .inst(inst),
      .addr(dmem_addr),
      .mask(wr_mask)
    );

    
    data_in_gen datagen (
      .in(rs2),
      .mask(wr_mask),
      .out(data_in)
    );

    // inst_x[6:0] == 7'b0000100 psrf.load
    // inst_x[6:0] == 7'b0100100 psrf.store
    assign is_lw_x = inst_x[6:0] == 7'b0000011 || inst_x[6:0] == 7'b0000100;
    assign is_sw_x = inst_x[6:0] == 7'b0100011 || inst_x[6:0] == 7'b0100100;
    assign is_mul = (alusel == 4'd11);
    assign is_addsub = (alusel == 4'd0 || alusel == 4'd1);
    
    logic [31:0] add_xx, data_in_x;
    logic [31:0] rd1_x;
    logic [31:0] psrf_addr_x;
    logic [3:0] wr_mask_x; 
    always @(posedge clk) begin
      if (rst) begin
        add_xx <= '0; 
        rd1_x <= '0;
        psrf_addr_x <= '0; 
        data_in_x <= '0;
        wr_mask_x <= '0; 
      end else begin
        if (imem_ena) begin 
          add_xx <= add_x;
          rd1_x <= rd1;
          psrf_addr_x <= psrf_addr; 
          data_in_x <= data_in; 
          wr_mask_x <= wr_mask; 
        end 
      end
    end

    logic is_psrf_lw_x, is_psrf_sw_x; 
    logic is_psrf_zd_lw_x; 
    logic is_zero; 
    logic is_zero_x; 

    // inst_x[14:12] == 3'b0 -> load-byte, store-byte
    // zero-detection perform when load instruction is executed
    // with func3 == 3'b110, the zero-detection is performed. 
    // The conventional load instruction is with func3 == 3'b111. 
    assign is_psrf_lw_x = ((inst_x[14:12] == 3'b111 || inst_x[14:12] == 3'b0) && is_lw_x) ? 1:0;
    assign is_psrf_sw_x = ((inst_x[14:12] == 3'b100 || inst_x[14:12] == 3'b0) && is_sw_x) ? 1:0; 
    assign is_psrf_zd_lw_x = ((inst_x[14:12] == 3'b110) && is_lw_x) ? 1:0; 
    // is_prsf_zd_lw is written in agu.sv.





    // Reading & writing from/to DMEM 
    always @(*) begin
      if (is_psrf_lw || is_psrf_sw || is_psrf_zd_lw || is_psrf_lw_x || is_psrf_sw_x || is_psrf_zd_lw_x) begin 
        if (cpu_state == cpu_state_fetch) begin 
          dmem_addr = {rd1[29:0] + psrf_addr} + ({wr_mask , 28'b0}) ; //, 2'b00}  ;//+ 32'hF800_0000;
          dmem_we = wr_mask;
          // if (rd1[19] == 1 && (is_psrf_lw || is_psrf_zd_lw)) begin
          //   dmem_addr = {'0, psrf_addr} | {'0, 1'b1, 19'b0}; 
          // end
        end else begin 
          dmem_addr = rd1_x[29:0] + psrf_addr_x + ({wr_mask_x , 28'b0}); // , 2'b00} ;//+ 32'hF800_0000;
          dmem_we = wr_mask_x;
          
        end
      end else begin
        if (cpu_state == cpu_state_fetch) begin 
          if (is_psrf_lw || is_psrf_sw || is_psrf_zd_lw) begin
            dmem_addr = {rd1[29:0]} + {psrf_addr} + {wr_mask , 28'b0}; // , 2'b00}; 
            dmem_we = wr_mask;
          end else begin
            dmem_addr =  {add_x[29:0]}  + {wr_mask , 28'b0};
            dmem_we = wr_mask;
          end

        end else begin 
          if (is_lw_x || is_sw_x || is_psrf_zd_lw_x) begin 
            dmem_addr = {add_xx[29:0]} + {wr_mask_x , 28'b0};
            dmem_we = wr_mask_x; 
          end else begin 
            dmem_addr = {add_x[29:0]} + {wr_mask , 28'b0};
            dmem_we = wr_mask;
          end
        end
      end
      dmem_din = (is_sw || is_sw_x) ? data_in: '0; // data_in_xx


      if (cpu_state == cpu_state_fetch) begin 
        dmem_din = (is_sw || is_sw_x) ? data_in: '0; 
      end else begin 
        dmem_din = (is_sw || is_sw_x) ? data_in_x: '0; 
      end

      
      dmem_en = 1;

    end
    

    


    // interconnect interface 
    always @(*) begin
      if (cpu_state == cpu_state_fetch || cpu_state == cpu_state_mem) begin
        if ( (is_lw||(is_lw_x && cpu_state==cpu_state_mem)) && load_store_grant_i_reg != 1) begin 
          load_store_data_req = 1'b1; // data_req
          load_store_req = 1'b0; // data_wen 
          
          // if (dmem_addr[19] == 1) begin // address offset specified to utilze local mem. 
          //   load_store_data_req = 1'b0;
          //   load_store_req = 1'b0;
          // end
        end else if (is_sw || (is_sw_x && cpu_state==cpu_state_mem) && load_store_grant_i_reg != 1) begin
          load_store_data_req = 1'b1;   
          load_store_req = 1'b1;    
        end else if (load_store_grant_i_reg == '1) begin
            load_store_data_req = '0;
            load_store_req = '0;
        end else begin 
            load_store_data_req = '0;
            load_store_req = '0;  
        end 
      end else begin 
          load_store_data_req = '0;
          load_store_req = '0;  
      end 
    end

    always @(*) begin
      if (cpu_state == cpu_state_fetch) begin
        imem_ena = 1;
      end else begin 
        imem_ena = 0; 
      end
    end 

    always @(*) begin
      if (cpu_state == cpu_state_mem || (is_lw||is_sw)) begin
        mem_operation = 1;
        // if (dmem_addr[19] == 1) begin
        //   mem_operation = 0;
        // end
      end else begin 
        mem_operation = 0; 
      end
    end 

    assign pc_state = pc;
    always @(posedge clk) begin // multi cycle operation FSM here 
      if (rst) begin
        cpu_state <= cpu_state_idle;
        pc_write <= '0; 
      end else begin
        mem_op_in_state <= '0; 
        case (cpu_state) 
          cpu_state_idle: begin
            if (inst_en) begin
              cpu_state <= cpu_state_fetch;
              pc_write <= 1;
            end else begin
              cpu_state <= cpu_state_idle;
              pc_write <= 0;
            end
          end
          cpu_state_fetch: begin 
            pc_write <= 0; 
            

            if (inst_en) begin
              if (is_lw || is_sw) begin
                cpu_state <= cpu_state_mem; 
                pc_write <= '0; 
              end else begin
                if ((grid_state) != '0) begin 
                  cpu_state <= cpu_state_fetch;
                  pc_write <= '0;
                end else if (inst_trap) begin
                  cpu_state <= cpu_state_trap; 
                  pc_write <= '0; 
                end else begin
                  cpu_state <= cpu_state_fetch; // cpu_state
                  pc_write <= '1; 
                end
              end
            end else begin
              cpu_state <= cpu_state_fetch;
              pc_write <= '0;
            end

          end


          cpu_state_mem: begin   
            if (load_store_grant_i_reg) begin
              cpu_state <= cpu_state_fetch;
              pc_write <= '1; 
              if ((grid_state & mem_mask)!= 0) begin 
                cpu_state <= cpu_state_wait; 
                pc_write <= 0; 
              end
            end else begin
              cpu_state <= cpu_state_mem;
              mem_op_in_state <= 1; 
              pc_write <= '0; 
            end
          end

          cpu_state_wait: begin 
            if (grid_state == 0) begin 
              cpu_state <= cpu_state_fetch;
              pc_write <= '1; 
            end else begin 
              cpu_state <= cpu_state_wait; 
              pc_write <= 0; 
            end
          end

          cpu_state_trap: begin
            cpu_state <= cpu_state_trap; 
            pc_write <= '0;
          end

        endcase
      end

    end

    // mem_select_out
    // assign memoutsel = add_x[31:28];
    reg [31:0] out_mem;
    assign out_mem = mem_dmem_dout; 
    

    // write back stage 
    // To write a register file, there are 3 signals: we, wa, and wd
    always @(*) begin
      if (is_corf_lui || is_ppsrf_addi || is_corf_addi || is_offs_addi 
                    || (is_psrf_branch && br_taken) || is_hwLrf_lui || is_hwLrf_addi) begin
        we = '0; 
      end else begin
        if (is_lw_x && cpu_state==cpu_state_mem) begin 
          we = load_store_grant_i_reg;
        end else begin 
          if (!is_lw) begin 
          // we = (cpu_state == cpu_state_pc && pc_write == 1) ? regwen : 0;  
            if (grid_state != 0) begin 
              we = 0; 
            end else begin 
              we = regwen; 
            end
          end else begin
            we = 0; 
          end
        end
      end
    end


    assign wa = (is_psrf_branch && br_taken) ? inst[19:15]:inst[11:7];
    assign wa_x = (is_psrf_branch && br_taken) ? inst_x[19:15]:inst_x[11:7];
    assign wd = (is_psrf_branch && br_taken) ? 0 : wb_val;
    
    reg [31:0] out_lex;
    load_ex load_ex (
      .clk(clk),
      .rst(rst),
      .in(out_mem),
      .out(out_lex),
      .inst(inst),
      .addr(dmem_addr),
      .cpu_state(cpu_state),
      .imem_ena(imem_ena)
    );



    logic [1:0] wbsel_master;

    always @(*) begin 
      if (lw_busy )  
          // ( (is_psrf_lw_x || 
          //    is_psrf_zd_lw_x) && dmem_addr[19] == 1)) 
          begin 
        wbsel_master = wbsel_x; 
      end else begin
        wbsel_master = wbsel; 
      end
    end




    wb_selector wber (
      // Inputs
      .out_lex(out_lex),
      .pc(pc_state),
      .alu(alu),
      .wb_sel(wbsel_master),
      // Outputs
      .wb_val(wb_val)
    );


    // output register to other PE
    logic [31:0] wb_val_reg; 
    logic [31:0] temp_store, out_real; 
    assign wb_val_reg = out_real;
    // always @(posedge clk) begin
    //   if (we) begin
    //     wb_val_reg <= wb_val; 
    //   end
    // end 

    localparam [2:0] out_state_idle     = 3'b000; // 0
    localparam [2:0] out_state_next     = 3'b001; // 1
    localparam [2:0] out_state_end      = 3'b010; // 2
    logic [2:0] out_state; 

    always @(posedge clk) begin 
      if (rst) begin 
        out_state <= out_state_idle; 
        temp_store <= '0; 
        out_real <= '0; 
      end else begin 
        case(out_state) 
          out_state_idle: begin 
            if (we) begin
              temp_store <= wb_val; 
              if (grid_state == 0) begin 
                out_state <= out_state_end; 
                out_real <= wb_val;  
              end else begin 
                out_state <= out_state_next;  
              end
            end else begin 
              out_state <= out_state_idle; 
            end
          end

          out_state_next: begin 
            if (grid_state == 0) begin 
              out_state <= out_state_end;  
              out_real <= temp_store; 
            end else begin 
              out_state <= out_state_next; 
            end
          end

          out_state_end: begin 
            out_state <= out_state_idle; 
          end

          default: begin
            out_state <= out_state_idle; 
          end
        endcase

      end
    end 


    assign o_n  = wb_val_reg; 
    assign o_e  = wb_val_reg; 
    assign o_s  = wb_val_reg; 
    assign o_w  = wb_val_reg; 

    // assign dbg_imem_addrb = imem_addrb;
    // assign dbg_inst = inst;
    // assign dbg_cpu_state =  cpu_state; 
    logic [2:0] hwl_state; 
    logic [31:0] addr_operand_A;
    logic [31:0] addr_operand_B;

    hwl #(
      .n_pe(n_pe)
    ) hwl (
      // input 
      .clk(clk), 
      .rst(rst),
      .pc(pc),
      .inst_x(inst),
      .ena_inst(pc_write),
      .cpu_state(cpu_state), 
      .grid_state(grid_state), 
      .wa(wa), 
      .wd(wd), 
      .imm(imm), 
      .is_lw(is_lw), 
      .is_sw(is_sw), 
      .is_zero(is_zero),
      .is_zero_x(is_zero_x),
 
      // output
      .hwl_tag_en_1(hwl_tag_en_1), 
      .hwl_tag_en_2(hwl_tag_en_2), 
      .hwl_tag_en_3(hwl_tag_en_3), 
      .hwl_tag_en_4(hwl_tag_en_4), 
      .hwl_tag_en_5(hwl_tag_en_5), 
      .hwl_tag_en_6(hwl_tag_en_6), 
      .hwl_tag_en_7(hwl_tag_en_7), 
      .hwl_state_out(hwl_state), 
      .is_hwLrf_lui(is_hwLrf_lui), 
      .is_hwLrf_addi(is_hwLrf_addi), 
      .is_hwloop_pc_end(is_hwloop_pc_end), 
      .is_loopcnt_end(is_loopcnt_end),
      .is_loop_notend(is_loop_notend),
      .hwLrf_tag_end(hwLrf_tag_end),
      .pcsel_upper(pcsel_upper),
      .pc_hwloop(pc_hwloop),
      .pc_end_zero_flag(pc_hwl_end_zero_flag),
      .i_mat(i_mat),
      .j_mat(j_mat),
      .k_mat(k_mat)
    );
    generate
      if (agu_ena) begin
        agu #(
          .n_pe(n_pe)
        ) agu (
          // input
          .clk(clk), 
          .inst_x(inst),
          .ena_inst(pc_write),
          .br_taken(br_taken),
          .cpu_state(cpu_state), 
          .wa(wa), 
          .wd(wd), 
          .imm(imm), 
          .regwen_x(regwen), 
          .is_hwloop_pc_end(is_hwloop_pc_end),
          .is_loopcnt_end(is_loopcnt_end), 
          .is_loop_notend(is_loop_notend), 
          .hwLrf_tag_end(hwLrf_tag_end),
          .is_lw(is_lw), 
          .is_sw(is_sw),
          .is_zero(is_zero),
          .is_zero_x(is_zero_x),
          .hwl_state(hwl_state), 
          .is_hwLrf_lui(is_hwLrf_lui),
          .is_hwLrf_addi(is_hwLrf_addi), 
          .grid_state(grid_state), 
          .hwl_tag_en_1(hwl_tag_en_1), 
          .hwl_tag_en_2(hwl_tag_en_2), 
          .hwl_tag_en_3(hwl_tag_en_3), 
          .hwl_tag_en_4(hwl_tag_en_4), 
          .hwl_tag_en_5(hwl_tag_en_5), 
          .hwl_tag_en_6(hwl_tag_en_6), 
          .hwl_tag_en_7(hwl_tag_en_7), 
          // output 
          .is_corf_lui(is_corf_lui),
          .is_corf_addi(is_corf_addi), 
          .is_ppsrf_addi(is_ppsrf_addi), 
          .is_offs_addi(is_offs_addi),
          .is_psrf_addi(is_psrf_addi),
          .is_psrf_rst(is_psrf_rst), 
          .is_psrf_branch(is_psrf_branch),
          .is_psrf_lw(is_psrf_lw), 
          .is_psrf_sw(is_psrf_sw),  
          .is_psrf_zd_lw(is_psrf_zd_lw), 
          .psrf_addr(psrf_addr),
          .addr_operand_A(addr_operand_A),
          .addr_operand_B(addr_operand_B)
        );
      end 
    endgenerate

`ifndef SYNTHESIS
  logic [31:0] dbg_mem_conflict_in = '0;
  logic [31:0] lw_count = '0; 
  assign dbg_mem_conflict = dbg_mem_conflict_in - lw_count; 
  always @(posedge clk) begin 
    if (cpu_state == cpu_state_mem || cpu_state == cpu_state_wait) begin 
      dbg_mem_conflict_in <= dbg_mem_conflict_in + 1; 
    end
  end

  always @(posedge clk) begin 
    if (is_lw || is_sw) begin 
      lw_count <= lw_count + 1; 
    end
  end

  logic [3:0] which_bank; 
  assign which_bank = dmem_addr[31:2] % (n_pe);

  logic [31:0] ic; 
  logic [31:0] ic_trap; 
  always @(posedge clk) begin
    if (inst_en & !trap) begin
      ic = ic + 1; 
    end

    if (trap) begin 
      ic_trap = ic_trap + 1; 
    end
  end

  assign dbg_ic = ic; 
  assign dbg_ic_trap = ic_trap; 

`else 
  assign which_bank = 0;  
  assign dbg_mem_conflict = '0;
`endif



endmodule
