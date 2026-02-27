// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    KIRA-Testbench-vivado
// Module Name:    grid_top_tb
// File Name:      grid_top_tb.sv
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
//   - This testbench is used to test the grid_top module for Vivado Simulation.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
`timescale 1ns/1ns
`include "mem_path.vh"
`include "opcode.vh"

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

// `define HWL_AGU_TEST
// `define CONV_TEST
// `define MAX_POOL_TEST
// `define CONV_SPLIT_TEST
// `define CONV_SPLIT_TEST2
// `define CMSIS_NET
// `define BRANCH_SYNC_TEST
`define LOAD_TEST
// `define R_TEST
// `define I_TEST_ARITH
// `define LW_TEST
// `define MATRIX5x5
// `define CMSIS_L2
// `define CMSIS_L3
// `define PADDING
// `define IM2COL
// `define GEMM_SIMD
// `define GEMM_SIMD_SPLIT
// `define GEMM_SPLIT_L2
// `define GEMM_SPLIT_L3

module grid_tb(); 


  // Parameters
  parameter N_R = 8;
  parameter N_C = 4;
  parameter NB_LS = N_R*N_C;
  parameter LOG2_NUM_PE = $clog2(N_R*N_C);

  // Inputs
  logic clk;
  logic rst_aux; 
  logic rst;
  logic inst_en;
  logic preload;
  logic [31:0] imem_dina;
  logic [3:0] imem_wea;
  logic [9+LOG2_NUM_PE:0] imem_addra;
  logic host_load_store_data_req;
  logic host_load_store_req;
  logic [31:0] host_dmem_addr;
  logic [31:0] host_dmem_din;

  // Outputs
  logic host_load_store_grant_i;
  logic host_data_req_valid_i;
  logic [31:0] host_dmem_out;
  logic finish;
  // logic [15:0] clk_en; 

  logic host_load_store_grant_reg; 

  always @(posedge clk) begin
      host_load_store_grant_reg <= host_load_store_grant_i; 
  end

  reg [4:0]  RD, RS1, RS2;
  reg [31:0] RD1, RD2;
  reg [4:0]  SHAMT;
  reg [31:0] IMM, IMM0, IMM1, IMM2, IMM3, IMMB, IMM4, IMM5, IMM6, IMM_ADDR;
  reg [14:0] INST_ADDR;
  reg [14:0] DATA_ADDR;
  reg [14:0] DATA_ADDR0, DATA_ADDR1, DATA_ADDR2, DATA_ADDR3;
  reg [14:0] DATA_ADDR4, DATA_ADDR5, DATA_ADDR6, DATA_ADDR7;
  reg [14:0] DATA_ADDR8, DATA_ADDR9;

  reg [31:0] JUMP_ADDR;

  reg [31:0]  BR_TAKEN_OP1  [5:0];
  reg [31:0]  BR_TAKEN_OP2  [5:0];
  reg [31:0]  BR_NTAKEN_OP1 [5:0];
  reg [31:0]  BR_NTAKEN_OP2 [5:0];

  reg [255:0] BR_NAME_TK1   [5:0];
  reg [255:0] BR_NAME_TK2   [5:0];
  reg [255:0] BR_NAME_NTK   [5:0];
  reg [2:0] BR_TYPE; 

  logic [7:0] grid_div;
  assign grid_div = 8'd48;

  // Instantiate the DUT (Device Under Test)
  riscv_grid_top #(
    .N_R(N_R),
    .N_C(N_C),
    .NB_LS(NB_LS)
  ) tb (
    .clk(clk),
    .rst(rst),
    .inst_en(inst_en),
    .preload(preload), 
    .grid_div(grid_div),
    
    .finish(finish), 
    .imem_dina(imem_dina),
    .imem_wea(imem_wea),
    .imem_addra(imem_addra),
    .host_load_store_data_req(host_load_store_data_req),
    .host_load_store_req(host_load_store_req),
    .host_dmem_addr(host_dmem_addr),
    .host_dmem_din(host_dmem_din),

    .host_load_store_grant_i(host_load_store_grant_i),
    .host_data_req_valid_i(host_data_req_valid_i),
    .host_dmem_out(host_dmem_out)
  );

  // Clock Generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
  end

  task dma_tx_sim; 
    integer i; 
    begin 
        // write data to dmem
        i = 0;
        while (i < 1024*16) begin
            @(posedge clk);
            host_load_store_data_req <= 1; 
            host_load_store_req <= 1; 
            host_dmem_addr <= i * 4; 
            host_dmem_din <= 100*i + i; 
            i=i+1;
            
        end
        @(posedge clk); 
        host_load_store_data_req <= 0; 
        host_load_store_req <= 0; 
        
    end
  endtask

  // dma2_tx_sim(32'h1000_0000, "data.txt", 1024);
  task dma2_tx_sim;
    input integer base_addr;       // Base address for data transfer
    input string data_file;        // File representing data
    input integer length;          // Length of data transfer
    integer i;
    integer data;
    integer file;
    integer status;

    begin
        // Open the data file
        file = $fopen(data_file, "r");
        if (file == 0) begin
            $display("Error: Failed to open file %s", data_file);
            disable dma_tx_sim;
        end

        i = 0;
        while (i < length) begin
            // Read data from file
            status = $fscanf(file, "%d\n", data);
            if (status != 1) begin
                $display("Error: Failed to read data at index %d", i);
                disable dma_tx_sim;
            end

            @(posedge clk);
            host_load_store_data_req <= 1; 
            host_load_store_req <= 1; 
            host_dmem_addr <= ((base_addr + i) * 4); 
            host_dmem_din <= data; 
            i = i + 1;
        end

        // Clean up
        @(posedge clk); 
        host_load_store_data_req <= 0; 
        host_load_store_req <= 0; 
        $fclose(file);
    end
  endtask



  logic [31:0] host_dmem_addr_reg;
  always @(posedge clk) begin
      host_dmem_addr_reg <= host_dmem_addr; 
  end     

  task dma_rx_sim; 
    integer i; 
    begin 
      i = 0;
      while (i < 1028*16) begin
        if (host_data_req_valid_i) begin
          $display("[debug] data at [%h] give %d",host_dmem_addr_reg, host_dmem_out);
          @(posedge clk); 
        end else begin 
          @(posedge clk); 
        end

        if (i < 1024*16) begin
          host_load_store_data_req <= 1; 
          host_load_store_req <= 0; 
          host_dmem_addr <= i * 4; 
          host_dmem_din <= 0; 
          i = i + 1;
        end else begin
          host_load_store_data_req <= 0; 
          host_load_store_req <= 0; 
          i = i + 1;
        end
      end
      host_load_store_data_req <= 0; 
      host_load_store_req <= 0; 
      @(posedge clk); 
    end
  endtask

  // dma_rx_sim(32'h1000_0000, "read_data.txt", 1024);
  task dma2_rx_sim;
    input integer base_addr;       // Base address for data transfer
    input string data_file;        // File to store read data
    input integer length;          // Length of data transfer
    integer i;
    integer file;

    begin
        // Open the data file for writing
        file = $fopen(data_file, "w");
        if (file == 0) begin
            $display("Error: Failed to open file %s for writing", data_file);
            disable dma_rx_sim;
        end

        i = 0;
        while (i < length) begin
            if (host_data_req_valid_i) begin
                // Capture and log the data
                $display("[debug] data at [%h] = %d", host_dmem_addr_reg, signed'(host_dmem_out));
                $fwrite(file, "%d\n", signed'(host_dmem_out));
                @(posedge clk); 
            end else begin 
                @(posedge clk); 
            end

            if (i < length) begin
                host_load_store_data_req <= 1; 
                host_load_store_req <= 0; 
                host_dmem_addr <= ((base_addr + i) * 4); 
                host_dmem_din <= 0; 
                i = i + 1;
            end else begin
                host_load_store_data_req <= 0; 
                host_load_store_req <= 0; 
                i = i + 1;
            end
        end
        
        // Clean up
        host_load_store_data_req <= 0; 
        host_load_store_req <= 0; 
        $fclose(file);
        @(posedge clk); 
    end
  endtask


  // Test Stimulus
  initial begin
    // init_imem(); 

    imem_dina = '0;
    imem_wea = '0; 
    imem_addra = '0; 
    inst_en = 0; 
    preload = 0; 

    host_load_store_data_req = 0; 
    host_load_store_req = 0; 
    host_dmem_addr = '0; 
    host_dmem_din = '0;
    rst_aux = 0;
    rst = 1; 
    #20; 
    rst = 0; 
    rst_aux = 1;
    #20; 
    rst_aux = 0;
    
    repeat (5) @(posedge clk);

    imem_wea = 4'hf; 
    
    // matrix multiplication A(5x5) times B(5x5) -> C(5x5)
    // *A = 0, *B = 1009, *C=512
    `ifdef MATRIX5x5
      imem_addra = 14'b00000000000000; imem_dina = 32'h00000113; @(posedge clk);
      imem_addra = 14'b00000000000001; imem_dina = 32'h00057083; @(posedge clk);
      imem_addra = 14'b00000000000010; imem_dina = 32'h03c080b3; @(posedge clk);
      imem_addra = 14'b00000000000011; imem_dina = 32'h00110133; @(posedge clk);
      imem_addra = 14'b00000000000100; imem_dina = 32'h0025c123; @(posedge clk);
      imem_addra = 14'b00000000000101; imem_dina = 32'h00128295; @(posedge clk);
      imem_addra = 14'b00000000000110; imem_dina = 32'hff2296e4; @(posedge clk);
      imem_addra = 14'b00000000000111; imem_dina = 32'h00120215; @(posedge clk);
      imem_addra = 14'b00000000001000; imem_dina = 32'hff3210e4; @(posedge clk);
      imem_addra = 14'b00000000001001; imem_dina = 32'h00118195; @(posedge clk);
      imem_addra = 14'b00000000001010; imem_dina = 32'hfd419ce4; @(posedge clk);
      imem_addra = 14'b00010000000000; imem_dina = 32'h00000033; @(posedge clk);
      imem_addra = 14'b00010000000001; imem_dina = 32'h00157083; @(posedge clk);
      imem_addra = 14'b00010000000010; imem_dina = 32'h00000033; @(posedge clk);
      imem_addra = 14'b00010000000011; imem_dina = 32'h00000033; @(posedge clk);
      imem_addra = 14'b00010000000100; imem_dina = 32'h00000033; @(posedge clk);
      imem_addra = 14'b00010000000101; imem_dina = 32'h00128295; @(posedge clk);
      imem_addra = 14'b00010000000110; imem_dina = 32'hff2296e4; @(posedge clk);
      imem_addra = 14'b00010000000111; imem_dina = 32'h00120215; @(posedge clk);
      imem_addra = 14'b00010000001000; imem_dina = 32'hff3210e4; @(posedge clk);
      imem_addra = 14'b00010000001001; imem_dina = 32'h00118195; @(posedge clk);
      imem_addra = 14'b00010000001010; imem_dina = 32'hfd419ce4; @(posedge clk);
      imem_addra = 14'b00001000000000; imem_dina = 32'h00500913; @(posedge clk);
      imem_addra = 14'b00001000000001; imem_dina = 32'h00500993; @(posedge clk);
      imem_addra = 14'b00001000000010; imem_dina = 32'h00500a13; @(posedge clk);
      imem_addra = 14'b00001000000011; imem_dina = 32'h00000513; @(posedge clk);
      imem_addra = 14'b00001000000100; imem_dina = 32'h20000593; @(posedge clk);
      imem_addra = 14'b00001000000101; imem_dina = 32'h00500014; @(posedge clk);
      imem_addra = 14'b00001000000110; imem_dina = 32'h00100094; @(posedge clk);
      imem_addra = 14'b00001000000111; imem_dina = 32'h00500214; @(posedge clk);
      imem_addra = 14'b00001000001000; imem_dina = 32'h00100294; @(posedge clk);
      imem_addra = 14'b00001000001001; imem_dina = 32'h00500414; @(posedge clk);
      imem_addra = 14'b00001000001010; imem_dina = 32'h00100494; @(posedge clk);
      imem_addra = 14'b00001000001011; imem_dina = 32'h00301014; @(posedge clk);
      imem_addra = 14'b00001000001100; imem_dina = 32'h00501094; @(posedge clk);
      imem_addra = 14'b00001000001101; imem_dina = 32'h00501214; @(posedge clk);
      imem_addra = 14'b00001000001110; imem_dina = 32'h00401294; @(posedge clk);
      imem_addra = 14'b00001000001111; imem_dina = 32'h00301414; @(posedge clk);
      imem_addra = 14'b00001000010000; imem_dina = 32'h00401494; @(posedge clk);
      imem_addra = 14'b00011000000000; imem_dina = 32'h00500913; @(posedge clk);
      imem_addra = 14'b00011000000001; imem_dina = 32'h00500993; @(posedge clk);
      imem_addra = 14'b00011000000010; imem_dina = 32'h00500a13; @(posedge clk);
      imem_addra = 14'b00011000000011; imem_dina = 32'h3f100513; @(posedge clk);
      imem_addra = 14'b00011000000100; imem_dina = 32'h00500014; @(posedge clk);
      imem_addra = 14'b00011000000101; imem_dina = 32'h00100094; @(posedge clk);
      imem_addra = 14'b00011000000110; imem_dina = 32'h00500214; @(posedge clk);
      imem_addra = 14'b00011000000111; imem_dina = 32'h00100294; @(posedge clk);
      imem_addra = 14'b00011000001000; imem_dina = 32'h00500414; @(posedge clk);
      imem_addra = 14'b00011000001001; imem_dina = 32'h00100494; @(posedge clk);
      imem_addra = 14'b00011000001010; imem_dina = 32'h00301014; @(posedge clk);
      imem_addra = 14'b00011000001011; imem_dina = 32'h00501094; @(posedge clk);
      imem_addra = 14'b00011000001100; imem_dina = 32'h00501214; @(posedge clk);
      imem_addra = 14'b00011000001101; imem_dina = 32'h00401294; @(posedge clk);
      imem_addra = 14'b00011000001110; imem_dina = 32'h00301414; @(posedge clk);
      imem_addra = 14'b00011000001111; imem_dina = 32'h00401494; @(posedge clk);
    `endif

    `ifdef LOAD_TEST // load 4 contention memory bank with 2 PEs 
      // imem_addra = 14'b00001000000000; imem_dina = 32'h00500913; @(posedge clk);
      // imem_addra = 14'b00011000000000; imem_dina = 32'h00500913; @(posedge clk);
      imem_addra = 15'b00000000000000; imem_dina = 32'h80032303; @(posedge clk); // lw x6, 0(x0)
      imem_addra = 15'b00000000000001; imem_dina = 32'h00000000; @(posedge clk); // lw x6, 0(x0)
      imem_addra = 15'b00010000000000; imem_dina = 32'h38802303; @(posedge clk); // lw x6, 1024(x0)
      // imem_addra = 14'b00110000000000; imem_dina = 32'h20002303; @(posedge clk); // lw x6, 1024(x0)
      // imem_addra = 14'b00100000000000; imem_dina = 32'h10002303; @(posedge clk); // lw x6, 1024(x0)
      // imem_addra = 14'b00110000000000; imem_dina = 32'h20002303; @(posedge clk); // lw x6, 1024(x0)
      // imem_addra = 14'b01000000000000; imem_dina = 32'h30002303; @(posedge clk); // lw x6, 1024(x0)
    `endif

    `ifdef STORE_TEST // sw 2 contention memory bank with 2 PEs 
      imem_addra = 14'b00000000000000; imem_dina = 32'h01430313; @(posedge clk); 
      imem_addra = 14'b00010000000000; imem_dina = 32'h40002303; @(posedge clk);
      imem_addra = 14'b00100000000000; imem_dina = 32'h08102303; @(posedge clk);

      // imem_addra = 14'b00000000000001; imem_dina = 32'h00602023; @(posedge clk);
      // imem_addra = 14'b00010000000000; imem_dina = 32'h01930313; @(posedge clk);
      // imem_addra = 14'b00010000000001; imem_dina = 32'h40602023; @(posedge clk);
    `endif

    `ifdef R_TEST // arithmetic R-type instructions
      RS1 = 1; RD1 = -100;
      RS2 = 2; RD2 =  200;
      RD  = 3;
      SHAMT           = 5'd20;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[RS1] = RD1;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[RS2] = RD2;

      imem_addra = 14'd0; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_ADD_SUB, 5'd3,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd1; imem_dina = {`FNC7_1, RS2,   RS1, `FNC_ADD_SUB, 5'd4,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd2; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_SLL,     5'd5,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd3; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_SLT,     5'd6,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd4; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_SLTU,    5'd7,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd5; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_XOR,     5'd8,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd6; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_OR,      5'd9,  `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd7; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_AND,     5'd10, `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd8; imem_dina = {`FNC7_0, RS2,   RS1, `FNC_SRL_SRA, 5'd11, `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd9; imem_dina = {`FNC7_1, RS2,   RS1, `FNC_SRL_SRA, 5'd12, `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = 14'd10; imem_dina = {`FNC7_0, SHAMT, RS1, `FNC_SLL,     5'd13, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd11; imem_dina = {`FNC7_0, SHAMT, RS1, `FNC_SRL_SRA, 5'd14, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd12; imem_dina = {`FNC7_1, SHAMT, RS1, `FNC_SRL_SRA, 5'd15, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd13; imem_dina = {`FNC7_2, RS2,   RS1, `FNC_MUL,     5'd16, `OPC_ARI_RTYPE}; @(posedge clk);
    `endif

    `ifdef I_TEST_ARITH // arithmetic R-type instructions
      RS1 = 1; RD1 = -100;
      IMM             = -200;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[RS1] = RD1;

      imem_addra = 14'd0;  imem_dina = {IMM[11:0], RS1, `FNC_ADD_SUB, 5'd3, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd1;  imem_dina = {IMM[11:0], RS1, `FNC_SLT,     5'd4, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd2;  imem_dina = {IMM[11:0], RS1, `FNC_SLTU,    5'd5, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd3;  imem_dina = {IMM[11:0], RS1, `FNC_XOR,     5'd6, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd4;  imem_dina = {IMM[11:0], RS1, `FNC_OR,      5'd7, `OPC_ARI_ITYPE}; @(posedge clk);
      imem_addra = 14'd5;  imem_dina = {IMM[11:0], RS1, `FNC_AND,     5'd8, `OPC_ARI_ITYPE}; @(posedge clk);
    `endif


    `ifdef LW_TEST // arithmetic R-type instructions
      RS1 = 1; RD1 = -100;
      IMM  = -200;
      IMM0 = 32'h0000_0000;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[RS1] = 32'h0;

      imem_addra = 14'd0;  imem_dina = 32'h20108093;//{IMM0[11:0], 5'd1, `FNC_LW,  5'd2,  `OPC_LOAD}; 
      @(posedge clk);
      imem_addra = 14'd1;  imem_dina = 32'h4010a303;//{IMM0[11:0], 5'd1, `FNC_LW,  5'd2,  `OPC_LOAD}; 
      @(posedge clk);
    `endif

    `ifdef HWL_AGU_TEST // arithmetic R-type instructions
      // loop_count = 10, tag=3, loop_start=2, loop_end=8
      IMM1 = {6'd2, 6'd3, 5'd3, 15'd10};
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[7] = 32'h87;
      // preload
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = 32'h00500014; @(posedge clk); // corf.addi c0, c0, 5 
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = 32'h00301014; @(posedge clk); // ppsrf.addi p0, p0, 3
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = 32'h20158593; @(posedge clk); // addi x11,x11, 513
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = 32'h01450513; @(posedge clk); // addi x10,x10, 20
      // execute
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {12'd0, 5'd10, 3'b111, 5'd3, 7'h3}; @(posedge clk);// psrf.lw
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {12'd0, 5'd11, 3'b100, 5'd7, 7'h23}; @(posedge clk);// psrf.sw
    `endif


    `ifdef BRANCH_SYNC_TEST 
      // loop_count = 10, tag=3, loop_start=2, loop_end=8
      IMM       = 32'h0000_0010; // jump to 4
      INST_ADDR = 14'h0000;
      JUMP_ADDR = (32'h1000_0000 + IMM[12:0]) >> 2;

      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[1] = 100;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[2] = 200;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[3] = 300;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[4] = 400;

      BR_TYPE = `FNC_BNE;

      // Test branch taken
      imem_addra = {4'd0, 1'd0, 9'd0}; imem_dina = {IMM[12], IMM[10:5], 5'd2, 5'd1, BR_TYPE, IMM[4:1], IMM[11], `OPC_BRANCH}; @(posedge clk);
      imem_addra = {4'd0, 1'd0, 9'd1}; imem_dina = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd5, `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = {4'd0, 1'd0, IMM[10:2]}; imem_dina = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE}; @(posedge clk);

      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[1] = 100;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[2] = 200;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[3] = 500;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[4] = 900;

      imem_addra = {4'd1, 1'd0, 9'd0}; imem_dina = {IMM[12], IMM[10:5], 5'd2, 5'd1, 3'h0, IMM[4:1], IMM[11], 7'h65}; @(posedge clk);
      // imem_addra = {4'd1, 1'd0, 9'd1}; imem_dina = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd5, `OPC_ARI_RTYPE}; @(posedge clk);
      imem_addra = {4'd1, 1'd0, IMM[10:2]}; imem_dina = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE}; @(posedge clk);
      // imem_addra = {4'd1, 1'd0, 9'd5}; imem_dina = {`FNC7_0, 5'd4, 5'd3, `FNC_ADD_SUB, 5'd6, `OPC_ARI_RTYPE}; @(posedge clk);
    `endif

    `ifdef MAX_POOL_TEST 
      IMM1 = {6'd2,  6'd16, 5'd10, 15'd6};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd14}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd14}; // for y in range(Y) Y=28 output size y-axis


      IMM6 = 32'h0000_0000 + (2 << 2); 
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 8500;
      dma2_tx_sim(32'd20, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/output_conv.txt", 6*784); // write input image
      
      // Preload
      // input image 6n+56x+2y+offset
      imem_addra = {4'd0, 1'd1, 9'd0}; imem_dina = {12'd784,  5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd0, 1'd1, 9'd1}; imem_dina = {12'd56, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd2}; imem_dina = {12'd2,  5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd3}; imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd4}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd5}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      // input image offset 
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd0,  5'd0, 3'b11, 5'd0, 7'h14}; @(posedge clk);  // offs.addi f0, f0, 0
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd1,  5'd0, 3'b11, 5'd1, 7'h14}; @(posedge clk);  // offs.addi f1, f0, 1
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd28,  5'd0, 3'b11, 5'd2, 7'h14}; @(posedge clk); // offs.addi f2, f0, 28
      imem_addra = {4'd0, 1'd1, 9'd9}; imem_dina = {12'd29,  5'd0, 3'b11, 5'd3, 7'h14}; @(posedge clk);  // offs.addi f3, f0, 29

      // output image 6n+14x+y
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd196,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd14, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd1,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd10,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14

      // base address of input and output 
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = 32'h01498993; @(posedge clk); // x19, x19, 20  -> O
      // imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = 32'h5dca0a13; @(posedge clk); // addi x20, x20, 8500 -> Output

      // Execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm2
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm3
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi

      // {offset, var,  ba,   func3,   rd,   opc}
      // {6'd0, 6'd0,  5'd19, 3'b111, 5'd1, 7'h03};
      imem_addra = {4'd0, 1'd0, 9'd6}; imem_dina = {6'd0, 6'd0,  5'd19, 3'b111, 5'd1, 7'h03}; @(posedge clk); // psrf.lw x1, 0(x19) // x1=max
      imem_addra = {4'd0, 1'd0, 9'd7}; imem_dina = {6'd1, 6'd0,  5'd19, 3'b111, 5'd2, 7'h03}; @(posedge clk); // psrf.lw x2, 0(x19)
      imem_addra = {4'd0, 1'd0, 9'd8}; imem_dina = {6'd2, 6'd0,  5'd19, 3'b111, 5'd3, 7'h03}; @(posedge clk); // psrf.lw x3, 0(x19)
      imem_addra = {4'd0, 1'd0, 9'd9}; imem_dina = {6'd3, 6'd0,  5'd19, 3'b111, 5'd4, 7'h03}; @(posedge clk); // psrf.lw x4, 0(x19)

      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[12], IMM6[10:5], 5'd2, 5'd1, 3'b101, IMM6[4:1], IMM6[11], `OPC_BRANCH}; @(posedge clk); // bge x1, x2
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = 32'h00010093; @(posedge clk);// addi x1, x2, 0 move x2 to x1 
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = {IMM6[12], IMM6[10:5], 5'd3, 5'd1, 3'b101, IMM6[4:1], IMM6[11], `OPC_BRANCH}; @(posedge clk); // bge x1, x3 
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = 32'h00018093; @(posedge clk);// addi x1, x3, 0 move x3 to x1 
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = {IMM6[12], IMM6[10:5], 5'd4, 5'd1, 3'b101, IMM6[4:1], IMM6[11], `OPC_BRANCH}; @(posedge clk); // bge x1, x4 
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h00020093; @(posedge clk);// addi x1, x3, 0 move x3 to x1 
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk);// psrf.sw x1, 1(x20) 
    `endif

    `ifdef CONV_TEST
      IMM1 = {6'd2,  6'd16, 5'd10, 15'd6};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd28}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd28}; // for y in range(Y) Y=28 output size y-axis
      IMM4 = {6'd8,  6'd16, 5'd13, 15'd1};  // for d in range(D) D=1  input channel 
      IMM5 = {6'd10, 6'd16, 5'd14, 15'd5};  // for i in range(K) K=5  w size x-axis
      IMM6 = {6'd12, 6'd16, 5'd15, 15'd5};  // for j in range(K) K=5  w_size y-axis

      dma2_tx_sim(32'd513, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_im.txt", 784); // write input image
      dma2_tx_sim(32'd20,  "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi.txt", 150); // write filter 

      // PE0
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = 32'h20190913; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = 32'h01498993; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = 32'h5dca0a13; @(posedge clk); // addi x20, x20, 1500 -> Output

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd13};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd0, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10

      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd10,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // Load filter in the second PE
      // PE1
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd25, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28

      imem_addra = {4'd1, 1'd1, 9'd4}; imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd5}; imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6}; imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd7}; imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd1, 1'd1, 9'd8}; imem_dina = 32'h20190913; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd1, 1'd1, 9'd9}; imem_dina = 32'h01498993; @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = 32'h5dca0a13; @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd1, 1'd1, 9'd11};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd1, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd14}; imem_dina = {12'd10,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      

      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm2
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm3
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm4
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm5
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm6
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi

      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // // // execute
      // PE1
      // Loop imm1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm2
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm3
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm4
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm5
      imem_addra = {4'd1, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi

      // Loop imm6
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi

      imem_addra = {4'd1, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd1, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd1, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd1, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd1, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
    `endif

    `ifdef CONV_SPLIT_TEST
      dma2_tx_sim(32'd513, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_im.txt", 784); // write input image
      dma2_tx_sim(32'd20,  "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi.txt", 150); // write filter 

      //                                                              rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};

      IMM1 = {6'd2,  6'd16, 5'd10, 15'd1};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd28}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd28}; // for y in range(Y) Y=28 output size y-axis
      IMM4 = {6'd8,  6'd16, 5'd13, 15'd1};  // for d in range(D) D=1  input channel 
      IMM5 = {6'd10, 6'd16, 5'd14, 15'd5};  // for i in range(K) K=5  w size x-axis
      IMM6 = {6'd12, 6'd16, 5'd15, 15'd5};  // for j in range(K) K=5  w_size y-axis

      // n = 0
      // PE0
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd20, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd1500, 5'd0, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500 -> Output

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // Load filter in the second PE
      // PE1
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd1, 1'd1, 9'd8};  imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd1, 1'd1, 9'd9};  imem_dina = {12'd20, 5'd0, 3'd0, 5'd19, 7'h13};  @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd1500, 5'd0, 3'd0, 5'd20, 7'h13}; @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd1, 1'd1, 9'd11};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd1, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd14}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd1, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd1, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd1, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd1, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // ////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 1
      // PE2
      IMM_ADDR = -1812; // 4096 - 2284 = 1812
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {12'd45, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 4096
       
      // addr and coefficient of output is written in var=1  imem_dina = {IMM_ADDR[10:0], 5'd0, 3'd0, 5'd20, 7'h13};
      imem_addra = {4'd2, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      imem_addra = {4'd2, 1'd1, 9'd19}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1812)
      // Load filter in the second PE
      // PE3
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {12'd45, 5'd0, 3'd0, 5'd19, 7'h13};  @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd3, 1'd1, 9'd11};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd3, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd14}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      imem_addra = {4'd3, 1'd1, 9'd17}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);
      // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd2, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd2, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // execute
      // PE4
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd3, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd3, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd3, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd3, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 2
      // PE4
      IMM_ADDR = -1028; // 4096 - 3068 = 1028
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {12'd70, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // addi x20, x20, 1500 -> Output

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd4, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd19}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1812)

      // Load filter in the second PE
      // PE5
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd5, 1'd1, 9'd8};  imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd5, 1'd1, 9'd9};  imem_dina = {12'd70, 5'd0, 3'd0, 5'd19, 7'h13};  @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd5, 1'd1, 9'd11};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd5, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd14}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd17}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);


      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd4, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd4, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE5
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd5, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd5, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd5, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd5, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 3
      // PE6
      IMM_ADDR = -244; // 4096-3852=244
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {12'd95, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd6, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd19}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1812)

      // Load filter in the second PE
      // PE7
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd7, 1'd1, 9'd8};  imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd7, 1'd1, 9'd9};  imem_dina = {12'd95, 5'd0, 3'd0, 5'd19, 7'h13};  @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd7, 1'd1, 9'd11};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd7, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd14}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd17}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);


      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd6, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd6, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd7, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd7, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd7, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd7, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 4
      // PE8
      IMM_ADDR = 540; // 4096-4638=542
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {12'd120, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd8, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      imem_addra = {4'd8, 1'd1, 9'd19}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1812)

      // Load filter in the second PE
      // PE9
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd9, 1'd1, 9'd8};  imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd9, 1'd1, 9'd9};  imem_dina = {12'd120, 5'd0, 3'd0, 5'd19, 7'h13};  @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd9, 1'd1, 9'd11};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd9, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd14}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      imem_addra = {4'd9, 1'd1, 9'd17}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);

      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd8, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd8, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE9
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd9, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd9, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd9, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd9, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 5
      // PE10
      IMM_ADDR = 1324; // 4096-5420=1325
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {12'd145, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd10, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      imem_addra = {4'd10, 1'd1, 9'd19}; imem_dina = {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);

      // Load filter in the second PE
      // PE9
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd11, 1'd1, 9'd8};  imem_dina = {12'd513, 5'd0, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, 513 -> I
      imem_addra = {4'd11, 1'd1, 9'd9};  imem_dina = {12'd145, 5'd0, 3'd0, 5'd19, 7'h13};  @(posedge clk); // x19, x19, 20  -> O
      imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output

      imem_addra = {4'd11, 1'd1, 9'd11};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd11, 1'd1, 9'd12};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd13};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd14}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd15}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd16}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      imem_addra = {4'd11, 1'd1, 9'd17}; imem_dina =  {IMM_ADDR[11:0], 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);

      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd10, 1'd0, 9'd13}; imem_dina = 32'h00097083; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd10, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd16}; imem_dina = 32'h001a40a3; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd11, 1'd0, 9'd13}; imem_dina = 32'h0009fd83; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd11, 1'd0, 9'd14}; imem_dina = 32'h001a7d83; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd11, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd11, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
    `endif

    `ifdef CONV_SPLIT_TEST2

      dma2_tx_sim(32'd513, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_im_int8.txt", 784/4); // write input image
      dma2_tx_sim(32'd20,  "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 152/4); // write filter 

      //                                                              rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};
      // BA address I = 513 (word addressable)
      // BA address W = 20 (word addressable)
      // BA address O = 1500 (word addressable)

      IMM1 = {6'd2,  6'd16, 5'd10, 15'd1};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd28}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd28}; // for y in range(Y) Y=28 output size y-axis
      IMM4 = {6'd8,  6'd16, 5'd13, 15'd1};  // for d in range(D) D=1  input channel 
      IMM5 = {6'd10, 6'd16, 5'd14, 15'd5};  // for i in range(K) K=5  w size x-axis
      IMM6 = {6'd12, 6'd16, 5'd15, 15'd5};  // for j in range(K) K=5  w_size y-axis

      // n = 0
      // PE0
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd80, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd28, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd1,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd19}; imem_dina = {12'd11, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd20}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // Load filter in the second PE
      // PE1
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd0,  5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd25, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd5,  5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd1,  5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd13, 5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd14, 5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd15, 5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd1, 1'd1, 9'd8};  imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd1, 1'd1, 9'd9};  imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd80, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4


      imem_addra = {4'd1, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd1, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 32'h00097084
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // // // execute
      // PE1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd1, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x19) h0009fd84
      imem_addra = {4'd1, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 1(x20) h001a7d84
      imem_addra = {4'd1, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd1, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // ////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 1
      // PE2
      IMM_ADDR = -1812; // 4096 - 2284 = 1812
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {12'd105, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {-12'd1408, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (944) = 2284*4

      // addr and coefficient of output is written in var=1  imem_dina = {IMM_ADDR[10:0], 5'd0, 3'd0, 5'd20, 7'h13};
      imem_addra = {4'd2, 1'd1, 9'd15};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd16};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      
      // Load filter in the second PE
      // PE3
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd3, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd3, 1'd1, 9'd9}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {12'd105, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 45*4  -> W // Load and store in first PE
      imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {-12'd1408, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (944) = 2284*4


      imem_addra = {4'd3, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd3, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd2, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd2, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // execute
      // PE4
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd3, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd3, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd3, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd3, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 2
      // PE4
      IMM_ADDR = -1028; // 4096 - 3068 = 1028
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {12'd130, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {-12'd624, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-16) = 3068*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd4, 1'd1, 9'd15};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd16};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd18}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd19}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      

      // Load filter in the second PE
      // PE5
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd5, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd5, 1'd1, 9'd9}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {12'd130, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {-12'd624, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-16) = 3068*4

      imem_addra = {4'd5, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd5, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd4, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd4, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // // // execute
      // PE5
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd5, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd5, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd5, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd5, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 3
      // PE6
      IMM_ADDR = -244; // 4096-3852=244
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {12'd155, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd160, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-976) = 3852*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd6, 1'd1, 9'd15};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd16};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11
      

      // Load filter in the second PE
      // PE7
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd7, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd7, 1'd1, 9'd9}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {12'd155, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd160, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-976) = 3852*4

      imem_addra = {4'd7, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd7, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd6, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd6, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // // // execute
      // PE1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd7, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd7, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd7, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd7, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 4
      // PE8
      IMM_ADDR = 540; // 4096-4636=540
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {12'd180, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd944, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1936) = 4638*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd8, 1'd1, 9'd15};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd16};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd9, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd9, 1'd1, 9'd9}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {12'd180, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd944, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1936) = 4638*4

      imem_addra = {4'd9, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd9, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd8, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd8, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // // // execute
      // PE9
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd9, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd9, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd9, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd9, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 5
      // PE10
      IMM_ADDR = 1324; // 4096-5420=1324
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd784, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd28, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {12'd205, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20=20480
      imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd1728, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1200=5420*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd10, 1'd1, 9'd15};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd16};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      

      // Load filter in the second PE
      // PE9
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 784
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 28
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 28
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd11, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd11, 1'd1, 9'd9}; imem_dina = {-12'd2044, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-2044=513*4
      imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {12'd205, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20=21680
      imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd1728, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1200=5420*4

      imem_addra = {4'd11, 1'd1, 9'd13};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd11, 1'd1, 9'd14};  imem_dina = {12'd28,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd10, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lw x1, 0(x18)
      imem_addra = {4'd10, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
          
      // // // execute
      // PE1
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14};@(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd11, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x19)
      imem_addra = {4'd11, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lw x1, 1(x20) h0019f083
      imem_addra = {4'd11, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd11, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
    `endif


    `ifdef CMSIS_NET
      dma2_tx_sim(32'd700, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_im_int8.txt", 784/4); // write input image
      dma2_tx_sim(32'd21,  "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 152/4); // write filter 

      //                                                              rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};
      // BA address I = 513 (word addressable)
      // BA address W = 20 (word addressable)
      // BA address O = 1500 (word addressable)

      IMM1 = {6'd2,  6'd16, 5'd10, 15'd4};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd32}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd32}; // for y in range(Y) Y=28 output size y-axis
      IMM4 = {6'd8,  6'd16, 5'd13, 15'd3};  // for d in range(D) D=1  input channel 
      IMM5 = {6'd10, 6'd16, 5'd14, 15'd5};  // for i in range(K) K=5  w size x-axis
      IMM6 = {6'd12, 6'd16, 5'd15, 15'd5};  // for j in range(K) K=5  w_size y-axis

      // n = 0
      // PE0 BA_I=2800 BA_W=84, BA_O=6000
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd84, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd1024,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd32, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd1,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd19}; imem_dina = {12'd11, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd20}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // Load filter in the second PE
      // PE1 BA_I=2800 BA_W=84, BA_O=6000
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd75,  5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd25, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd5,  5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd1,  5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd13, 5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd14, 5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd15, 5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd1, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd1, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd84, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4


      imem_addra = {4'd1, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd1, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18) 32'h00097084
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // execute
      // PE1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd1, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19) h0009fd84
      imem_addra = {4'd1, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h001a7d84
      imem_addra = {4'd1, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd1, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // ////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE2 BA_I=2800 BA_W=384, BA_O=10096
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {12'd380, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 10096

      // addr and coefficient of output is written in var=1  imem_dina = {IMM_ADDR[10:0], 5'd0, 3'd0, 5'd20, 7'h13};
      imem_addra = {4'd2, 1'd1, 9'd15};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd16};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // Load filter in the second PE
      // PE3
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {12'd380, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 10096


      imem_addra = {4'd3, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd3, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd2, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd2, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // execute
      // PE4
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd3, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd3, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd3, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd3, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE4 BA_I=2800 BA_W=684, BA_O=14192
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {12'd684, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {3, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 14192

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd4, 1'd1, 9'd15};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd16};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd18}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd19}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE5
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd5, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd5, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {12'd684, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {3, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 14192

      imem_addra = {4'd5, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd5, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd4, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd4, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE5
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd5, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd5, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd5, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd5, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 3
      // PE6 BA_I=2800 BA_W=984, BA_O=18288
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {12'd984, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {4, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 18288

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd6, 1'd1, 9'd15};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd16};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // Load filter in the second PE
      // PE7
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd7, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd7, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {12'd984, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {4, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 18288

      imem_addra = {4'd7, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd7, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd6, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd6, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd7, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd7, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd7, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd7, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 4
      // PE8 BA_I=2800 BA_W=1284, BA_O=22384
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {12'd1284, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {5, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 22384

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd8, 1'd1, 9'd15};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd16};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd9, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd9, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {12'd1284, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {5, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1936) = 4638*4

      imem_addra = {4'd9, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd9, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd8, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd8, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE9
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd9, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd9, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd9, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd9, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 5
      // PE10 BA_I=2800 BA_W=1584, BA_O=26480
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {12'd1584, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {6, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=24576
      imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=26480

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd10, 1'd1, 9'd15};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd16};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd11, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd11, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {12'd1584, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {6, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=24576
      imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=26480

      imem_addra = {4'd11, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd11, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd10, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd10, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE11
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd11, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd11, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd7, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd11, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd11, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE12 BA_I=2800 BA_W=1884, BA_O=30576
      imem_addra = {4'd12, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd12, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd12, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd12, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd12, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd12, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd12, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd12, 1'd1, 9'd12}; imem_dina = {12'd1884, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {7, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=28672
      imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=30576

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd12, 1'd1, 9'd15};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd16};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd17};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd18}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd19}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd20}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE13
      imem_addra = {4'd13, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd13, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd13, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd13, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd13, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd13, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd13, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd13, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd13, 1'd1, 9'd10}; imem_dina = {12'd1884, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {7, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=28672
      imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=30576

      imem_addra = {4'd13, 1'd1, 9'd13};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd13, 1'd1, 9'd14};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd15};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd16}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd17}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd18}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd12, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd12, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd12, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd12, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd12, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd13, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd13, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd13, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd13, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd13, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE14 BA_I=2800 BA_W=2184, BA_O=34672
      imem_addra = {4'd14, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd14, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd2};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd14, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd14, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd14, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      imem_addra = {4'd14, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd14, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd14, 1'd1, 9'd12}; imem_dina = {1, 5'd10, `OPC_LUI}; @(posedge clk); // lui x19, 1; x19=4096
      imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {-12'd1912, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, -1912 -> W // 4096-1912=2184
      imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {8, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 8; x20=32768
      imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=34672

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd14, 1'd1, 9'd16};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd17};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd18};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd20}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE13
      imem_addra = {4'd15, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd15, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd15, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd15, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd15, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd15, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      imem_addra = {4'd15, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      imem_addra = {4'd15, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      imem_addra = {4'd15, 1'd1, 9'd10}; imem_dina = {1, 5'd10, `OPC_LUI}; @(posedge clk); // lui x19, 1; x19=4096
      imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {-12'd1912, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {8, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 8; x20=32768
      imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=34672

      imem_addra = {4'd15, 1'd1, 9'd14};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd15, 1'd1, 9'd15};  imem_dina = {12'd32,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd16};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd17}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd18}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd19}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd14, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd14, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd14, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd14, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd14, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd15, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd15, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd15, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd15, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd15, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
    `endif

    `ifdef CMSIS_L2
      dma2_tx_sim(32'd700, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_im_int8.txt", 784/4); // write input image
      dma2_tx_sim(32'd21,  "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 152/4); // write filter 

      //                                                              rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};
      // BA address I = 700 (word addressable)
      // BA address W = 21 (word addressable)
      // BA address O = 1500 (word addressable)
      // tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 8500;

      IMM1 = {6'd2,  6'd16, 5'd10, 15'd4};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd16}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd16}; // for y in range(Y) Y=28 output size y-axis
      IMM4 = {6'd8,  6'd16, 5'd13, 15'd32};  // for d in range(D) D=1  input channel 
      IMM5 = {6'd10, 6'd16, 5'd14, 15'd5};  // for i in range(K) K=5  w size x-axis
      IMM6 = {6'd12, 6'd16, 5'd15, 15'd5};  // for j in range(K) K=5  w_size y-axis

      // n = 0
      // PE0 BA_I=2800 BA_W=84, BA_O=6000
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 15000;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 6000;
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd84, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      // imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd256,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd16, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd1,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // Load filter in the second PE
      // PE1 BA_I=2800 BA_W=84, BA_O=6000
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[19] = 15000;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[20] = 6000;
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd75,  5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd25, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd5,  5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd1,  5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd13, 5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd14, 5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd15, 5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd1, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd1, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd84, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      // imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4


      imem_addra = {4'd1, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd1, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18) 32'h00097084
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // execute
      // PE1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd1, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19) h0009fd84
      imem_addra = {4'd1, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h001a7d84
      imem_addra = {4'd1, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd1, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // ////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE2 BA_I=2800 BA_W=384, BA_O=10096
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[19] = 18200;
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[20] = 7024;
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {12'd380, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      // imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 10096

      // addr and coefficient of output is written in var=1  imem_dina = {IMM_ADDR[10:0], 5'd0, 3'd0, 5'd20, 7'h13};
      imem_addra = {4'd2, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // Load filter in the second PE
      // PE3
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[19] = 18200;
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[20] = 7024;
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {12'd380, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      // imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 10096


      imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd2, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd2, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // execute
      // PE4
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd3, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd3, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd3, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd3, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE4 BA_I=2800 BA_W=684, BA_O=14192
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[19] = 21400;
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[20] = 8048;
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {12'd684, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {3, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      // imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 14192

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd4, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE5
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[19] = 21400;
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[20] = 8048;
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd5, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd5, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {12'd684, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {3, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      // imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 14192

      imem_addra = {4'd5, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd5, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd4, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd4, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE5
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd5, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd5, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd5, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd5, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 3
      // PE6 BA_I=2800 BA_W=984, BA_O=18288
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[19] = 24600;
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[20] = 9072;
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {12'd984, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {4, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      // imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 18288

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd6, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // Load filter in the second PE
      // PE7
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[19] = 24600;
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[20] = 9072;
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd7, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd7, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {12'd984, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {4, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      // imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 18288

      imem_addra = {4'd7, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd7, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd6, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd6, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd7, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd7, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd7, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd7, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 4
      // PE8 BA_I=2800 BA_W=1284, BA_O=22384
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[19] = 27800;
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[20] = 10096;
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {12'd1284, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      // imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {5, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      // imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 22384

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd8, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[19] = 27800;
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[20] = 10096;
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd9, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd9, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {12'd1284, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      // imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {5, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      // imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1936) = 4638*4

      imem_addra = {4'd9, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd9, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd8, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd8, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE9
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd9, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd9, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd9, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd9, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 5
      // PE10 BA_I=2800 BA_W=1584, BA_O=26480
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[19] = 31000;
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[20] = 11120;
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {12'd1584, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {6, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=24576
      // imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=26480

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd10, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[19] = 31000;
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[20] = 11120;
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd11, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd11, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {12'd1584, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {6, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=24576
      // imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=26480

      imem_addra = {4'd11, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd11, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd10, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd10, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE11
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd11, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd11, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd7, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd11, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd11, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE12 BA_I=2800 BA_W=1884, BA_O=30576
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[19] = 34200;
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[20] = 12144;
      imem_addra = {4'd12, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd12, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd12, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd12, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd12, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd12, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd12, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd12, 1'd1, 9'd12}; imem_dina = {12'd1884, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {7, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=28672
      // imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=30576

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd12, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE13
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[19] = 34200;
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[20] = 12144;
      imem_addra = {4'd13, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd13, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd13, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd13, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd13, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd13, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd13, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd13, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd13, 1'd1, 9'd10}; imem_dina = {12'd1884, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {7, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=28672
      // imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=30576

      imem_addra = {4'd13, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd13, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd12, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd12, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd12, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd12, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd12, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd13, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd13, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd13, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd13, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd13, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE14 BA_I=2800 BA_W=2184, BA_O=34672
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[19] = 37400;
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[20] = 13168;
      imem_addra = {4'd14, 1'd1, 9'd0};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd14, 1'd1, 9'd1};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd2};  imem_dina = {12'd16, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd14, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd14, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd14, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd14, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd14, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd14, 1'd1, 9'd12}; imem_dina = {1, 5'd10, `OPC_LUI}; @(posedge clk); // lui x19, 1; x19=4096
      // imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {-12'd1912, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, -1912 -> W // 4096-1912=2184
      // imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {8, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 8; x20=32768
      // imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=34672

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd14, 1'd1, 9'd10};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd11};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE13
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[18] = 40000;
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[19] = 37400;
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[20] = 13168;
      imem_addra = {4'd15, 1'd1, 9'd0};  imem_dina = {12'd75, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd15, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd15, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd15, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd15, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd15, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd15, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd15, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd15, 1'd1, 9'd10}; imem_dina = {1, 5'd10, `OPC_LUI}; @(posedge clk); // lui x19, 1; x19=4096
      // imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {-12'd1912, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {8, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 8; x20=32768
      // imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=34672

      imem_addra = {4'd15, 1'd1, 9'd8};  imem_dina = {12'd256, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd15, 1'd1, 9'd9};  imem_dina = {12'd16,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd14, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd14, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd14, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd14, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd14, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd15, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd15, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd15, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd15, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd15, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
    `endif

    `ifdef CMSIS_L3
      dma2_tx_sim(32'd700, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_im_int8.txt", 784/4); // write input image
      dma2_tx_sim(32'd21,  "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 152/4); // write filter 

      //                                                              rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};
      // BA address I = 700 (word addressable)
      // BA address W = 21 (word addressable)
      // BA address O = 1500 (word addressable)
      // tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 8500;

      IMM1 = {6'd2,  6'd16, 5'd10, 15'd16};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd16, 5'd11, 15'd8}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd16, 5'd12, 15'd8}; // for y in range(Y) Y=28 output size y-axis
      IMM4 = {6'd8,  6'd16, 5'd13, 15'd32};  // for d in range(D) D=1  input channel 
      IMM5 = {6'd10, 6'd16, 5'd14, 15'd5};  // for i in range(K) K=5  w size x-axis
      IMM6 = {6'd12, 6'd16, 5'd15, 15'd5};  // for j in range(K) K=5  w_size y-axis

      // n = 0
      // PE0 BA_I=2800 BA_W=84, BA_O=6000
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 15004;
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 6000;
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd84, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      // imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd64,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd8, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd1,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // Load filter in the second PE
      // PE1 BA_I=2800 BA_W=84, BA_O=6000
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[19] = 15004;
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[20] = 6000;
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd800,  5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd25, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd5,  5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd1,  5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd13, 5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd14, 5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd15, 5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd1, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd1, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd84, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {1, 5'd20, `OPC_LUI}; @(posedge clk); // lui x18, 1; x20=4096
      // imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk);// addi x20, x20, 1500; x20+=1904=1500*4


      imem_addra = {4'd1, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd1, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd0, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18) 32'h00097084
      imem_addra = {4'd0, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd0, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // execute
      // PE1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd1, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19) h0009fd84
      imem_addra = {4'd1, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h001a7d84
      imem_addra = {4'd1, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd1, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // ////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE2 BA_I=2800 BA_W=384, BA_O=10096
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[19] = 27804;
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[20] = 7024;
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {12'd380, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      // imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 10096

      // addr and coefficient of output is written in var=1  imem_dina = {IMM_ADDR[10:0], 5'd0, 3'd0, 5'd20, 7'h13};
      imem_addra = {4'd2, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // Load filter in the second PE
      // PE3
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[19] = 27804;
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[20] = 7024;
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {12'd380, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {2, 5'd20, `OPC_LUI}; @(posedge clk); // addi x20, x20, 1500 -> Output  // x20 = 8192
      // imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 10096


      imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd2, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd2, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd2, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // execute
      // PE4
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd3, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd3, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd3, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd3, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE4 BA_I=2800 BA_W=684, BA_O=14192
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[19] = 40604;
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[20] = 8048;
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {12'd684, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {3, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      // imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 14192

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd4, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE5
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[19] = 40604;
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[20] = 8048;
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd5, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd5, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {12'd684, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {3, 5'd20, `OPC_LUI}; @(posedge clk); @(posedge clk); // lui x20, 3; x20 = 12288
      // imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 14192

      imem_addra = {4'd5, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd5, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd4, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd4, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd4, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE5
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd5, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd5, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd5, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd5, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 3
      // PE6 BA_I=2800 BA_W=984, BA_O=18288
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[19] = 53404;
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[20] = 9072;
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {12'd984, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {4, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      // imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 18288

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd6, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // Load filter in the second PE
      // PE7
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[19] = 53404;
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[20] = 9072;
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd7, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd7, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {12'd984, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {4, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 4; x20 = 16384
      // imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 18288

      imem_addra = {4'd7, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd7, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd6, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd6, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd6, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd7, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd7, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd7, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd7, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // n = 4
      // PE8 BA_I=2800 BA_W=1284, BA_O=22384
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[19] = 66204;
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[20] = 10096;
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -1296; 4096-1296=700*4
      // imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {12'd1284, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      // imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {5, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      // imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (1904) = 22384

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd8, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[19] = 66204;
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[20] = 10096;
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd9, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd9, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {12'd1284, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 480  -> W // Load and store in first PE
      // imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {5, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 5; x20 = 20480
      // imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20 = x20 + (-1936) = 4638*4

      imem_addra = {4'd9, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd9, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd8, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd8, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd8, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE9
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd9, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd9, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd9, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd9, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS

      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

      // n = 5
      // PE10 BA_I=2800 BA_W=1584, BA_O=26480
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[19] = 79004;
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[20] = 11120;
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {12'd1584, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {6, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=24576
      // imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=26480

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd10, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE9
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[19] = 79004;
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[20] = 11120;
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd11, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd11, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {12'd1584, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {6, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=24576
      // imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=26480

      imem_addra = {4'd11, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd11, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd10, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd10, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd10, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE11
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd11, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd11, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd7, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd11, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd11, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE12 BA_I=2800 BA_W=1884, BA_O=30576
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[19] = 91804;
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[20] = 12144;
      imem_addra = {4'd12, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd12, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd12, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd12, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd12, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd12, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd12, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd12, 1'd1, 9'd12}; imem_dina = {12'd1884, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {7, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=28672
      // imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=30576

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd12, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE13
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[19] = 91804;
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[20] = 12144;
      imem_addra = {4'd13, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 75
      imem_addra = {4'd13, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd13, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd13, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd13, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd13, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd13, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd13, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd13, 1'd1, 9'd10}; imem_dina = {12'd1884, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {7, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 6; x20=28672
      // imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=30576

      imem_addra = {4'd13, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd13, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd12, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd12, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd12, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd12, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd12, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd13, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd13, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd13, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd13, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd13, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS


      // /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // PE14 BA_I=2800 BA_W=2184, BA_O=34672
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[19] = 104604;
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[20] = 13168;
      imem_addra = {4'd14, 1'd1, 9'd0};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd14, 1'd1, 9'd1};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd2};  imem_dina = {12'd8, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd5};  imem_dina = 32'h00d01014; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd14, 1'd1, 9'd6};  imem_dina = 32'h00b01094; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd7};  imem_dina = 32'h00e01114; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd14, 1'd1, 9'd8};  imem_dina = 32'h00c01194; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd14, 1'd1, 9'd9};  imem_dina = 32'h00f01214; @(posedge clk); // ppsrf.addi p4, p0, 15
      // imem_addra = {4'd14, 1'd1, 9'd10}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd14, 1'd1, 9'd11}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd14, 1'd1, 9'd12}; imem_dina = {1, 5'd10, `OPC_LUI}; @(posedge clk); // lui x19, 1; x19=4096
      // imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {-12'd1912, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, -1912 -> W // 4096-1912=2184
      // imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {8, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 8; x20=32768
      // imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=34672

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd14, 1'd1, 9'd10};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd11};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd12};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // Load filter in the second PE
      // PE13
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[18] = 2000;
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[19] = 104604;
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[20] = 13168;
      imem_addra = {4'd15, 1'd1, 9'd0};  imem_dina = {12'd800, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd15, 1'd1, 9'd1};  imem_dina = {12'd25,  5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 25
      imem_addra = {4'd15, 1'd1, 9'd2};  imem_dina = {12'd5,   5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 5
      imem_addra = {4'd15, 1'd1, 9'd3};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c2, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd4};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd5};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 13
      imem_addra = {4'd15, 1'd1, 9'd6};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd15, 1'd1, 9'd7};  imem_dina = {12'd15,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 15
      // imem_addra = {4'd15, 1'd1, 9'd8}; imem_dina = {1, 5'd18, `OPC_LUI}; @(posedge clk); // lui x18, 1; x18=4096
      // imem_addra = {4'd15, 1'd1, 9'd9}; imem_dina = {-12'd1296, 5'd18, 3'd0, 5'd18, 7'h13}; @(posedge clk); // addi x18, x18, -2044; 4096-1296=700*4
      // imem_addra = {4'd15, 1'd1, 9'd10}; imem_dina = {1, 5'd10, `OPC_LUI}; @(posedge clk); // lui x19, 1; x19=4096
      // imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {-12'd1912, 5'd0, 3'd0, 5'd19, 7'h13}; @(posedge clk); // addi x19, x19, 20  -> W // Load and store in first PE
      // imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {8, 5'd20, `OPC_LUI}; @(posedge clk); // lui x20, 8; x20=32768
      // imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd1904, 5'd20, 3'd0, 5'd20, 7'h13}; @(posedge clk); // x20+=1904=34672

      imem_addra = {4'd15, 1'd1, 9'd8};  imem_dina = {12'd64, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 100
      imem_addra = {4'd15, 1'd1, 9'd9};  imem_dina = {12'd8,  5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd10};  imem_dina = {12'd1,   5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {12'd0,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // // execute
      // Loop imm1
      imem_addra = {4'd14, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd14, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04};  @(posedge clk); // psrf.lb x1, 0(x18)
      imem_addra = {4'd14, 1'd0, 9'd14}; imem_dina = 32'h03c080b3; @(posedge clk); // mul x1, x1, x28
      imem_addra = {4'd14, 1'd0, 9'd15}; imem_dina = 32'h01c080b3; @(posedge clk); // addi x1, x1, x28
      imem_addra = {4'd14, 1'd0, 9'd16}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20) 32'h001a40a3;
            
      // // // execute
      // PE1
      imem_addra = {4'd15, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd6};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd7};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd8};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd9};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd10}; imem_dina = {IMM6[31:12],  5'd6,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd11}; imem_dina = {IMM6[11:0], 5'd6, 3'h2,  5'd6,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd12}; imem_dina = 32'h00000093; @(posedge clk); // addi x1, x0, 0
      imem_addra = {4'd15, 1'd0, 9'd13}; imem_dina = {12'd0, 5'd19, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x19)
      imem_addra = {4'd15, 1'd0, 9'd14}; imem_dina = {12'd1, 5'd20, 3'd0, 5'd27, 7'h04}; @(posedge clk); // psrf.lb x1, 1(x20) h0019f083
      imem_addra = {4'd15, 1'd0, 9'd15}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
      imem_addra = {4'd15, 1'd0, 9'd16}; imem_dina = 32'h00000013; @(posedge clk); // addi x0, x0, 0 -> NOPS
    `endif

    `ifdef PADDING
      // padding 0 
      // pad 

      dma2_tx_sim(32'd20, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/PhD_project/data_im_cifar_int8.txt", 768); // write input image
      //                                                  rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};
      // BA address I = 700 (word addressable)
      // BA address W = 21 (word addressable)
      // BA address O = 1500 (word addressable)
      // tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 8500;

      IMM1 = {6'd2,  6'd7, 5'd10, 15'd3};  // for n in range(N) N=6  output channel
      IMM2 = {6'd4,  6'd7, 5'd11, 15'd32}; // for x in range(X) X=28 output size x-axis
      IMM3 = {6'd6,  6'd7, 5'd12, 15'd32}; // for y in range(Y) Y=28 output size y-axis

      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 80; // BA_I
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 4000+74; // BA_P
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd1024, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd32, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd12,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd1296,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd36, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd1,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd10,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd11, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi



      imem_addra = {4'd0, 1'd0, 9'd6}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18) 32'h00097084
      imem_addra = {4'd0, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd19, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x20) 32'h001a40a3;
    `endif

    `ifdef IM2COL
      // im2col
      // row_index = 0
      // for oh in 0 to output_h - 1:
      //     for ow in 0 to output_w - 1:
      //         col_index = 0 
      //         for c in 0 to C - 1:
      //             for kh in 0 to kernel_h - 1:
      //                 for kw in 0 to kernel_w - 1:
      //                     ih = oh * stride + kh
      //                     iw = ow * stride + kw
      //                     im2col_matrix[row_index][col_index] = padded[c][ih][iw] 
      //                     col_index += 1   // x6
      //         row_index += 1 // x5

      dma2_tx_sim(32'd2000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/padded_data_im_cifar_8bit.txt", 972); // write input image
      //                                                  rs1        rd
      // imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {IMM[11:0], 5'd18, 3'd0, 5'd3, 7'h13};
      // kernel_h = kernel_w = 5 
      // output_h = output_w = 32 
      // C = 3 (channel)

      IMM1 = {6'd2,  6'd14, 5'd10, 15'd3};  // for oh in 0 to output_h - 1:
      IMM2 = {6'd4,  6'd14, 5'd11, 15'd36};  // for ow in 0 to output_w - 1:
      IMM3 = {6'd7,  6'd13, 5'd12, 15'd3};   // for c in 0 to C - 1:
      IMM4 = {6'd9,  6'd13, 5'd13, 15'd5};  // for kh in 0 to kernel_h - 1:
      IMM5 = {6'd11, 6'd13, 5'd14, 15'd5};  // for kw in 0 to kernel_w - 1:

      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 8000; // BA_Padded
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 12000; // BA_Matrix
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd36, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd36, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = {12'd12,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd13,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = {12'd14,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of output is written in var=1
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd36,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd1, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd5,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd6, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi

      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h15}; @(posedge clk); // psrf.rst col_index=0 (x6)


      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi

      imem_addra = {4'd0, 1'd0, 9'd7};  imem_dina = {IMM4[31:12],  5'd4,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd8};  imem_dina = {IMM4[11:0], 5'd4, 3'h2,  5'd4,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd9};  imem_dina = {IMM5[31:12],  5'd5,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd10};  imem_dina = {IMM5[11:0], 5'd5, 3'h2,  5'd5,  7'h14}; @(posedge clk); // hrLrf.addi

      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd18, 3'd0, 5'd1, 7'h04}; @(posedge clk); // psrf.lb x1, 0(x18) 32'h00097084
      imem_addra = {4'd0, 1'd0, 9'd12}; imem_dina = {12'd1, 5'd19, 3'd0, 5'd1, 7'h24}; @(posedge clk); // psrf.sb x1, 1(x19) 32'h001a40a3;     
      imem_addra = {4'd0, 1'd0, 9'd13};  imem_dina = {12'd1, 5'd6, 3'h0,  5'd6,  7'h15}; @(posedge clk); // psrf.addi col_index+=1

      imem_addra = {4'd0, 1'd0, 9'd14};  imem_dina = {12'd1, 5'd5, 3'h0,  5'd5,  7'h15}; @(posedge clk); // psrf.addi row_index+=1
    `endif

    `ifdef GEMM_SIMD
      dma2_tx_sim(32'd3000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/im2col_int8.txt", 9*36*25); // write input image
      dma2_tx_sim(32'd251, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 5*5*3*32/4); // write input image
      
      IMM1 = {6'd2,  6'd11, 5'd10, 15'd2};    // for i in range(D) -> x10
      IMM2 = {6'd4,  6'd11, 5'd11, 15'd1296};  // for j in range((H+2P)*(W+2P)) -> x11
      IMM3 = {6'd7,  6'd10, 5'd12, 15'd19};    // for k in range(C*kH*kW) -> x12 (75 val lw 75/4=19)


      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 1004; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 22000; // BA_Out
      
      // Output
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd1, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd75,  5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd1, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd75,  5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd1, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi

      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 

      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd0, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd0, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 

      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    
    `endif

    `ifdef GEMM_SIMD_SPLIT
      // matrix multiplication P=padding
      // im (C,H,W)-> im2col (H*W,C*kh*kW) kernel (D,C,kH,kW) Output (h-kH+1,W-kW+1)
      //  for i in range(D)
      //      for j in range((H+2P)*(W+2P))
      //          for k in range(C*kH*kW)
      //              Out[i][j] += im[j][k] * w[k][i]

      dma2_tx_sim(32'd3000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/im2col_int8.txt", 9*36*25); // write input image
      dma2_tx_sim(32'd251, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 5*5*3*32/4); // write input image

      IMM1 = {6'd2,  6'd11, 5'd10, 15'd2};    // for i in range(D) -> x10
      IMM2 = {6'd4,  6'd11, 5'd11, 15'd1296};  // for j in range((H+2P)*(W+2P)) -> x11
      IMM3 = {6'd7,  6'd10, 5'd12, 15'd19};    // for k in range(C*kH*kW) -> x12 (75 val lw 75/4=19)


      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 1004; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 22000; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*1; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*2; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*2; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*4; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*3; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*6; // BA_Out

      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+152*4; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+1296*8; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*5; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*10; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*6; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*12; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*7; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*14; // BA_Out

      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+152*8; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+1296*16; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*9; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*18; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*10; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*20; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*11; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*22; // BA_Out

      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+152*12; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+1296*24; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*13; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*26; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*14; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*28; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*15; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*30; // BA_Out
      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd75*4,  5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd0, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd0, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd3, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd3, 3'd1, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd1, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd1, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd1, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd1, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd1, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    


      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd2, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd2, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd2, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)   

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd3, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd3, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd3, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd3, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd4, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd4, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd4, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd5, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd5, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd5, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd5, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd5, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd6, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd6, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd6, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd7, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd7, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd7, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd7, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd7, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)  

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd8, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd8, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd8, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd9, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd9, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd9, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd9, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd9, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd10, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd10, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd10, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd11, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd11, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd11, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd11, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd11, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd12, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd12, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd12, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd12, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd12, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd12, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd12, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd12, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd12, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd12, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd12, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd12, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd12, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd13, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd13, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd13, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd13, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd13, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd13, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd13, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd13, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd13, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd13, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd13, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd13, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd13, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd13, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd13, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd13, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd14, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd14, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd14, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd14, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd14, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd14, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd14, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd14, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd14, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd14, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd14, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd14, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd14, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd15, 1'd1, 9'd0};  imem_dina = {12'd1296, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0] = 4096; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd15, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd15, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd15, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd15, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd15, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd15, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd15, 1'd1, 9'd10}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd15, 1'd1, 9'd17}; imem_dina = {12'd300, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd15, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd15, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd15, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd15, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd15, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd15, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd15, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)     
    `endif

    `ifdef GEMM_SPLIT_L2
      // matrix multiplication P=padding
      // im (C,H,W)-> im2col (H*W,C*kh*kW) kernel (D,C,kH,kW) Output (h-kH+1,W-kW+1)
      //  for i in range(D)
      //      for j in range((H+2P)*(W+2P))
      //          for k in range(C*kH*kW)
      //              Out[i][j] += im[j][k] * w[k][i]

      dma2_tx_sim(32'd3000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/im2col_int8.txt", 9*36*25); // write input image
      dma2_tx_sim(32'd251, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 5*5*3*32/4); // write input image

      IMM1 = {6'd2,  6'd11, 5'd10, 15'd2};    // for i in range(D) -> x10
      IMM2 = {6'd4,  6'd11, 5'd11, 15'd400};  // for j in range((H+2P)*(W+2P)) -> x11
      IMM3 = {6'd7,  6'd10, 5'd12, 15'd200};    // for k in range(C*kH*kW) -> x12 (75 val lw 75/4=19)


      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 1004; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 22000; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*1; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*2; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*2; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*4; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*3; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*6; // BA_Out

      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+152*4; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+1296*8; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*5; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*10; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*6; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*12; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*7; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*14; // BA_Out

      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+152*8; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+1296*16; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*9; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*18; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*10; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*20; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*11; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*22; // BA_Out

      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+152*12; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+1296*24; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+152*13; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+1296*26; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+152*14; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+1296*28; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+152*15; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+1296*30; // BA_Out

      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024

      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024

      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024

      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 1600; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 3200; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 3200; @(posedge clk); // corf.addi c0, c0, 1024

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15


      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd0, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd0, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd3, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd3, 3'd1, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd1, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd1, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd1, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd1, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd1, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd1, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd1, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd1, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd1, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd1, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd1, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd1, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd1, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd1, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd1, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd1, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd1, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd1, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd1, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd1, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd1, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd1, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd1, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    


      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd2, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd2, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd2, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd2, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd2, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd2, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd2, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd2, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd2, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd2, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd2, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd2, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd2, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd2, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd2, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd2, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd2, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd2, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd2, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd2, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd2, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)   

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd3, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd3, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd3, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd3, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd3, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd3, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd3, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd3, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd3, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd3, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd3, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd3, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd3, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd3, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd3, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd3, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd3, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd3, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd3, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd3, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd3, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd3, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd3, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd4, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd4, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd4, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd4, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd4, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd4, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd4, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd4, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd4, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd4, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd4, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd4, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd4, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd4, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd4, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd4, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd4, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd4, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd4, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd4, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd4, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd5, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd5, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd5, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd5, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd5, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd5, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd5, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd5, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd5, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd5, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd5, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd5, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd5, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd5, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd5, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd5, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd5, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd5, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd5, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd5, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd5, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd5, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd5, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd6, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd6, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd6, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd6, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd6, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd6, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd6, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd6, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd6, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd6, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd6, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd6, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd6, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd6, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd6, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd6, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd6, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd6, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd6, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd6, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd6, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd7, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd7, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd7, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd7, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd7, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd7, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd7, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd7, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd7, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd7, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd7, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd7, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd7, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd7, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd7, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd7, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd7, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd7, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd7, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd7, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd7, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd7, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd7, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)  

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd8, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd8, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd8, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd8, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd8, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd8, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd8, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd8, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd8, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd8, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd8, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd8, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd8, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd8, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd8, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd8, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd8, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd8, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd8, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd8, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd8, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd9, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd9, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd9, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd9, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd9, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd9, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd9, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd9, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd9, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd9, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd9, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd9, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd9, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd9, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd9, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd9, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd9, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd9, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd9, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd9, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd9, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd9, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd9, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd10, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd10, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd10, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd10, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd10, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd10, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd10, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd10, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd10, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd10, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd10, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd10, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd10, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd10, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd10, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd10, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd10, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd10, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd10, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd10, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd10, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd11, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd11, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd11, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd11, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd11, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd11, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd11, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd11, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd11, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd11, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd11, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd11, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd11, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd11, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd11, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd11, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd11, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd11, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd11, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd11, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd11, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd11, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd11, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd12, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd12, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd12, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd12, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd12, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd12, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd12, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd12, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd12, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd12, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd12, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd12, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd12, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd12, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd12, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd12, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd12, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd12, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd12, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd12, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd12, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd13, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd13, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd13, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd13, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd13, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd13, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd13, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd13, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd13, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd13, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd13, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd13, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd13, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd13, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd13, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd13, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd13, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd13, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd13, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd13, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd13, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd13, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd13, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd14, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd14, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd14, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd14, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd14, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd14, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd14, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd14, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd14, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd14, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd14, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd14, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd14, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd14, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd14, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd14, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd14, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd14, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd14, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd14, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd14, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd15, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd15, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd15, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd15, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd15, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd15, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd15, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd15, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15

      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd15, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd15, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd15, 1'd1, 9'd17}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd15, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd15, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd15, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd15, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11

      // // execute
      // Loop imm1
      imem_addra = {4'd15, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd6,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd15, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd15, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd15, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd15, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd15, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd1, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd15, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd1, 3'd0, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd15, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)  
    `endif

    `ifdef GEMM_SPLIT_L3
      // matrix multiplication P=padding
      // im (C,H,W)-> im2col (H*W,C*kh*kW) kernel (D,C,kH,kW) Output (h-kH+1,W-kW+1)
      //  for i in range(D)
      //      for j in range((H+2P)*(W+2P))
      //          for k in range(C*kH*kW)
      //              Out[i][j] += im[j][k] * w[k][i]

      // matrix multiplication P=padding
      // im (C,H,W)-> im2col (H*W,C*kh*kW) kernel (D,C,kH,kW) Output (h-kH+1,W-kW+1)
      //  for i in range(D)
      //      for j in range((H+2P)*(W+2P))
      //          for k in range(C*kH*kW)
      //              Out[i][j] += im[j][k] * w[k][i]

      dma2_tx_sim(32'd3000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/im2col_int8.txt", 9*36*25); // write input image
      dma2_tx_sim(32'd251, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/data_fi_int8.txt", 5*5*3*32/4); // write input image

      IMM1 = {6'd2,  6'd11, 5'd10, 15'd2};    // for i in range(D) -> x10
      IMM2 = {6'd4,  6'd11, 5'd11, 15'd3};  // for j in range((H+2P)*(W+2P)) -> x11
      IMM3 = {6'd7,  6'd10, 5'd12, 15'd4};    // for k in range(C*kH*kW) -> x12 (75 val lw 75/4=19)


      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[19] = 1004; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.rf.mem[20] = 22000; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+1600*1; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+100*2; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+1600*2; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+100*4; // BA_Out
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+1600*3; // BA_kernel
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+100*6; // BA_Out

      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+1600*4; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+100*8; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+1600*5; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+100*10; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+1600*6; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+100*12; // BA_Out
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+1600*7; // BA_kernel
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+100*14; // BA_Out

      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+1600*8; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+100*16; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+1600*9; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+100*18; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+1600*10; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+100*20; // BA_Out
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+1600*11; // BA_kernel
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+100*22; // BA_Out

      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[19] = 1004+1600*12; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.rf.mem[20] = 22000+100*24; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[19] = 1004+1600*13; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.rf.mem[20] = 22000+100*26; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[19] = 1004+1600*14; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.rf.mem[20] = 22000+100*28; // BA_Out
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[18] = 12000; // BA_Matrix
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[19] = 1004+1600*15; // BA_kernel
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.rf.mem[20] = 22000+100*30; // BA_Out

      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[0].genblk1.master_cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[0].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024

      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[1].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024

      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[2].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024

      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[0].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[1].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[2].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[0]  = 36; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[6]  = 8; @(posedge clk); // corf.addi c0, c0, 1024
      tb.grid_unit.genblk1[3].genblk1[3].genblk1.cpu.genblk1.agu.corf_mem[12] = 8; @(posedge clk); // corf.addi c0, c0, 1024

      /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // Output
      imem_addra = {4'd0, 1'd1, 9'd0};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd0, 7'h14}; @(posedge clk); // corf.addi c0, c0, 1024
      imem_addra = {4'd0, 1'd1, 9'd1};  imem_dina = {12'd4, 5'd0, 3'b0, 5'd1, 7'h14}; @(posedge clk); // corf.addi c1, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd2};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd2, 7'h14}; @(posedge clk); // corf.addi c2, c0, 32
      imem_addra = {4'd0, 1'd1, 9'd3};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd3, 7'h14}; @(posedge clk); // corf.addi c3, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd4};  imem_dina = {12'd0, 5'd0, 3'b0, 5'd4, 7'h14}; @(posedge clk); // corf.addi c4, c0, 1
      imem_addra = {4'd0, 1'd1, 9'd5};  imem_dina = {12'd10,  5'd0, 3'b1, 5'd0, 7'h14}; @(posedge clk); // ppsrf.addi p0, p0, 13
      imem_addra = {4'd0, 1'd1, 9'd6};  imem_dina = {12'd11,  5'd0, 3'b1, 5'd1, 7'h14}; @(posedge clk); // ppsrf.addi p1, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd7};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd2, 7'h14}; @(posedge clk); // ppsrf.addi p2, p0, 14
      imem_addra = {4'd0, 1'd1, 9'd8};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd3, 7'h14}; @(posedge clk); // ppsrf.addi p3, p0, 12
      imem_addra = {4'd0, 1'd1, 9'd9};  imem_dina = {12'd0,  5'd0, 3'b1, 5'd4, 7'h14}; @(posedge clk); // ppsrf.addi p4, p0, 15


      // addr and coefficient of input is written in var=1 im
      imem_addra = {4'd0, 1'd1, 9'd10}; imem_dina = {12'd0, 5'd0, 3'b0, 5'd6, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd11}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd7, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd12}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd8, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd13}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd9, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd14}; imem_dina = {12'd11,  5'd0, 3'b1, 5'd6, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd15}; imem_dina = {12'd12, 5'd0, 3'b1, 5'd7, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd16}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd8, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11


      // addr and coefficient of kernel is written in var=2 kernel
      imem_addra = {4'd0, 1'd1, 9'd17}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd12, 7'h14}; @(posedge clk); // corf.addi c6, c0, 0
      imem_addra = {4'd0, 1'd1, 9'd18}; imem_dina = {12'd4, 5'd0, 3'b0, 5'd13, 7'h14}; @(posedge clk); // corf.addi c7, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd19}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd14, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd20}; imem_dina = {12'd0,  5'd0, 3'b0, 5'd15, 7'h14}; @(posedge clk); // corf.addi c8, c0, 10
      imem_addra = {4'd0, 1'd1, 9'd21}; imem_dina = {12'd12,  5'd0, 3'b1, 5'd12, 7'h14}; @(posedge clk); // ppsrf.addi p6, p0, 10
      imem_addra = {4'd0, 1'd1, 9'd22}; imem_dina = {12'd10, 5'd0, 3'b1, 5'd13, 7'h14}; @(posedge clk); // ppsrf.addi p7, p0, 11
      imem_addra = {4'd0, 1'd1, 9'd23}; imem_dina = {12'd0, 5'd0, 3'b1, 5'd14, 7'h14}; @(posedge clk); // ppsrf.addi p8, p0, 11



      // // execute
      // Loop imm1
      imem_addra = {4'd0, 1'd0, 9'd0};  imem_dina = {IMM1[31:12],  5'd1,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd1};  imem_dina = {IMM1[11:0], 5'd1, 3'h2,  5'd1,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd2};  imem_dina = {IMM2[31:12],  5'd2,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd3};  imem_dina = {IMM2[11:0], 5'd2, 3'h2,  5'd2,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd4};  imem_dina = {12'd0, 5'd0, 3'h1,  5'd1,  7'h13}; @(posedge clk); // addi x1, x0, x0 
      imem_addra = {4'd0, 1'd0, 9'd5};  imem_dina = {IMM3[31:12],  5'd3,  7'h3C}; @(posedge clk); // hwLrf.lui 
      imem_addra = {4'd0, 1'd0, 9'd6};  imem_dina = {IMM3[11:0], 5'd3, 3'h2,  5'd3,  7'h14}; @(posedge clk); // hrLrf.addi
      imem_addra = {4'd0, 1'd0, 9'd7}; imem_dina = {12'd1, 5'd18, 3'd7, 5'd1, 7'h04}; @(posedge clk); // psrf.lw x1, 0(x18) 
      imem_addra = {4'd0, 1'd0, 9'd8}; imem_dina = {12'd2, 5'd19, 3'd7, 5'd2, 7'h04}; @(posedge clk); // psrf.lw x2, 1(x18) 
      imem_addra = {4'd0, 1'd0, 9'd9}; imem_dina = {7'd1, 5'd2, 5'd1, 3'd0, 5'd3, 7'h34}; @(posedge clk); // vmul x1, x1, x2
      imem_addra = {4'd0, 1'd0, 9'd10}; imem_dina = {7'd0, 5'd4, 5'd3, 3'd1, 5'd4, 7'h34}; @(posedge clk); // vsum x4, x4, x1 
      imem_addra = {4'd0, 1'd0, 9'd11}; imem_dina = {12'd0, 5'd20, 3'd4, 5'd1, 7'h24}; @(posedge clk); // psrf.sw x1, 1(x20)    

    `endif

    imem_wea = 4'h0; 
    @(posedge clk);
    @(posedge clk); 
    preload = 1; 
    @(posedge clk); 
    @(posedge clk); 
    preload = 0; 
    inst_en = 1; 
    @(posedge clk);
    @(posedge finish); 
    inst_en = 0;
    
    
    @(posedge clk);
    @(posedge clk);
    rst = 1; 
    @(posedge clk);
    inst_en = 1; 
    rst = 0; 
    @(posedge finish); 
    #200;
    
    @(posedge clk); 
    rst = 1; 
    #20; 
    inst_en = 0; 
    rst = 0;

    // dma2_rx_sim(32'd8500, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/read_data.txt", 14*14*6 + 3);
    // dma2_rx_sim(32'd1500, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/read_data.txt", 1176); // conv_split_test2
    // dma2_rx_sim(32'd1000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/read_data.txt", 9*36*3 + 3); // padding 2 cifar
    dma2_rx_sim(32'd3000, "/home/khongpra/PhD_project/RISC-V-CGRA-FPGA/vivado_project/vivado_project.srcs/sim_1/imports/software/read_data.txt", 9*36*25 + 3); // im2col_matrix

    $finish();

  end



endmodule

// localparam [2:0] cpu_state_fetch  = 3'b000; // 0
// localparam [2:0] cpu_state_rs     = 3'b001; // 1
// localparam [2:0] cpu_state_mem    = 3'b010; // 2
// localparam [2:0] cpu_state_idle   = 3'b011; // 3
// localparam [2:0] cpu_state_trap   = 3'b100; // 4
// localparam [2:0] cpu_state_wait   = 3'b101; // 5
// localparam [2:0] cpu_state_pc     = 3'b110; // 6