// SPDX-License-Identifier: CERN-OHL-S-2.0
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
// You may obtain a copy of the License at:
//     https://ohwr.org/cern_ohl_s_v2.txt
// -----------------------------------------------------------------------------
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    load_ex
// Module Name:    load_ex
// File Name:      load_ex.sv
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
//   - This module is used to extend the load value based on the instruction.
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, 
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A 
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
// -----------------------------------------------------------------------------
// Additional Comments:
//   - Key Features:
//       * Handles load operations based on `func3` and `addr` alignment.
//       * Supports:
//         - Load Word (func3 = 010): Returns the full input word.
//         - Load Half-Word (func3 = 001/101): Returns and extends half-words based on address alignment.
//         - Load Byte (func3 = 000/100): Returns and extends bytes based on address alignment.
//       * Sign or zero extension based on the MSB of the selected portion and `func3`.
//   - Requires proper integration with processor instruction decode and memory subsystems.
// ==============================================================================


module load_ex(
    input clk, rst, 
    input [31:0] in,
    input [31:0] inst,
    input [31:0] addr,
    input [2:0] cpu_state, 
    input imem_ena, 
    output reg [31:0] out
);
    /* 
        1. If inst is not a load operation (I-Type), then do whatever.
        2. If the instruction is a load type instruction (opcode is always 7'h03).
            - If it's a load word -> func3 is 010 -> return the entire input
            - If it's a half word -> func3 is 001 / 101 -> if addr[1] == 0, then first half [31:16], otherwise second half [15:0]
            - If it's a byte -> func3 is 000 / 100 -> if addr[1:0] = 0 [31:25], 1 [24:16] 2 [15:7] 3 [7:0]
        Extension -> Check top byte, extend on basis of it.
    */

    localparam [2:0] cpu_state_fetch  = 3'b000; // 0
    localparam [2:0] cpu_state_rs     = 3'b001; // 1
    localparam [2:0] cpu_state_mem    = 3'b010; // 2
    localparam [2:0] cpu_state_idle   = 3'b011; // 3
    localparam [2:0] cpu_state_trap   = 3'b100; // 4
    localparam [2:0] cpu_state_wait   = 3'b101; // 5
    localparam [2:0] cpu_state_pc     = 3'b110; // 6
    
    logic [2:0] func3, func3_x;
    assign func3 = inst[14:12];

    logic [6:0] opc, opc_x;
    assign opc = inst[6:0];



    always @(posedge clk) begin 
        if (rst) begin
            func3_x <= '0; 
            opc_x <= '0; 
        end else begin
            if (imem_ena) begin 
                func3_x <= func3; 
                opc_x <= opc; 
            end 
      end
    end


    always @(*) begin
        if (opc == 7'h03 || opc_x == 7'h03) begin // Load instruction
            if (cpu_state == cpu_state_fetch) begin 
                if (func3[1:0] == 2'b10) begin // Load word
                    out = in;
                end 
            end else begin 
                if (func3_x[1:0] == 2'b10) begin // Load word
                    out = in;
                end 
            end
        end 
        else if (opc == 7'h04 || opc_x == 7'h04) begin // psrf.lw 
            if (cpu_state == cpu_state_fetch) begin
                if (func3[2:0] == 3'b111 || func3[2:0] == 3'b110) begin // Load word
                    out = in;
                end                 
                else begin
                    out = '0;
                end
                // else if (func3[1:0] == 2'b00) begin 
                //     if (addr[1:0] == 2'b11) begin // Load first half
                //         out[7:0] = in[31:24];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[31] ? 'hfffffff : 'h0;
                //         end else begin // Unsigned
                //             out[31:8] = 'h0;
                //         end
                //     end else if (addr[1:0] == 2'b10) begin // Load second half
                //         out[7:0] = in[23:16];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[23] ? 'hffffff : 'h0;                        
                //         end else begin
                //             out[31:8] = 'h0;
                //         end
                //     end else if (addr[1:0] == 2'b01) begin // Load third half
                //         out[7:0] = in[15:8];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[15] ? 'hffffff : 'h0;
                //         end else begin
                //             out[31:8] = 'h0;
                //         end
                //     end else begin
                //         out[7:0] = in[7:0];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[7] ? 'hffffff : 'h0;
                //         end else begin
                //             out[31:8] = 'h0;
                //         end
                //     end
                // end
            end else begin 
                if (func3_x[2:0] == 3'b111 || func3_x[2:0] == 3'b110) begin // Load word
                    out = in;
                end 
                else begin
                    out = '0;
                end
                // else if (func3_x[1:0] == 2'b00) begin 
                //     if (addr[1:0] == 2'b11) begin // Load first half
                //         out[7:0] = in[31:24];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[31] ? 'hfffffff : 'h0;
                //         end else begin // Unsigned
                //             out[31:8] = 'h0;
                //         end
                //     end else if (addr[1:0] == 2'b10) begin // Load second half
                //         out[7:0] = in[23:16];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[23] ? 'hffffff : 'h0;                        
                //         end else begin
                //             out[31:8] = 'h0;
                //         end
                //     end else if (addr[1:0] == 2'b01) begin // Load third half
                //         out[7:0] = in[15:8];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[15] ? 'hffffff : 'h0;
                //         end else begin
                //             out[31:8] = 'h0;
                //         end
                //     end else begin
                //         out[7:0] = in[7:0];
                //         if (func3[2] == 0) begin // Not unsigned
                //             out[31:8] = in[7] ? 'hffffff : 'h0;
                //         end else begin
                //             out[31:8] = 'h0;
                //         end
                //     end
                // end


            end
        end 
        else begin
            out = in;
        end
    end

endmodule
