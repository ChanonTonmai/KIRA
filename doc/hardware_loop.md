# Hardware Loop

A **hardware loop** is a specialized mechanism designed to efficiently manage loop execution in a processor, primarily by eliminating the overhead of traditional software-based loop control. 

In a conventional software loop, control flow relies on dedicated instructions: a counter is typically decremented, a comparison is made, and a conditional branch is executed at the end of each iteration. This process consumes execution cycles and can cause significant performance penalties, especially if branch prediction fails and triggers a pipeline flush. A Hardware Loop Engine (HLE) offers a more efficient solution by handling the loop's control flow (counting and branching) directly in hardware, separate from the instruction stream. This is often called **zero-overhead looping**.

---

## Core Concept

The core concept involves storing the loop's control parameters in dedicated hardware registers. These parameters typically include:

* **`pc_start`**: The program counter (PC) address of the first instruction in the loop.
* **`pc_end`**: The PC address of the last instruction in the loop.
* **`loop_count`**: The total number of iterations.
* **`tag`**: An identifier used to associate the loop with specific operations, such as address updates in an Address Generation Unit (AGU).

To use the hardware loop, the processor first initializes these registers. Once configured, the HLE takes over. At the end of each iteration (when the PC reaches `pc_end`), the HLE decrements the `loop_count` and automatically redirects the PC back to `pc_start` without executing any branch instructions. When `loop_count` reaches zero, the HLE allows the PC to advance past `pc_end`, effectively exiting the loop.

---

## Microarchitecture

The microarchitecture is centered around a **Hardware Loop Register File** (`hwLrf`) that stores the control parameters for active loops.

### Hardware Loop Register File (`hwLrf`)

This implementation supports up to **seven nested loops**. The main storage is a register array, `hwLrf_mem`, which is initialized using custom instructions.

An key optimization is storing `pc_end_offset` relative to `pc_start` instead of the full `pc_end` address, which reduces the required bit width. When the PC matches the calculated end address, the `loop_count` for the current loop level (`loop_lv`) is decremented.


```verilog
reg [31:0] hwLrf_mem [0:7];

// since we store the offset, when we check the pc_end, we need to add the loop start. 
assign is_hwloop_pc_end = (pc == ({'0, ({3'b0, hwLrf_mem[loop_lv][22:17]} + loop_start),2'b00} | RESET_PC) && still_hw_loop) ? 1:0; 

always @(posedge clk) begin
  if (is_hwLrf_lui || is_hwLrf_addi) begin 
    if (is_hwLrf_lui) begin
      hwLrf_mem[hwLrf_wa[2:0]] <= wd[31:0]; 
    end else begin
      hwLrf_mem[hwLrf_wa[2:0]] <= hwLrf_mem[hwLrf_wa[2:0]] | imm;
    end
  end 
  else begin 
    if (loop_lv > 0 && (is_hwloop_pc_end) && ena_inst) begin
      hwLrf_mem[loop_lv][11:0] <= hwLrf_mem[loop_lv][11:0] - 1;
    end
  end 
end
```

A counter, loop_lv, tracks the current nesting depth. It increments when a new loop is initialized and decrements when one or more loops terminate. The signal is_loopcnt_almostend becomes active during the final iteration (loop_count == 1) to prepare for loop exit.

```verilog
assign is_loopcnt_almostend = (hwLrf_mem[loop_lv][11:0] == 1 && still_hw_loop && !is_hwLrf_addi && !is_hwLrf_lui) ? 1:0;
always @(posedge clk) begin 
  is_loopcnt_almostend_reg <= is_loopcnt_almostend;
end

// is_loopcnt_almostend_e is the edge detected of is_loopcnt_almostend
assign is_loopcnt_almostend_e = ~is_loopcnt_almostend_reg & (is_loopcnt_almostend);

always @(posedge clk) begin
  if (is_hwLrf_addi) begin
    loop_lv <= loop_lv + 1; 
  end else begin
    if (is_loopcnt_almostend) begin
      if (is_loopcnt_almostend_e == 1 && !is_hwLrf_addi && !is_hwLrf_lui) begin 
        if (loop_lv < number_of_ended_loop) begin 
          loop_lv <= loop_lv; 
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
```
A key challenge is handling cases where multiple nested loops terminate on the same cycle. The logic must calculate number_of_ended_loop to correctly update loop_lv. This is done in three steps:

1. Identify Loops About to End: A bitmask, loop_count_is_one, is created. Bit i is set if loop level i has a count of 1.

```verilog
logic [7:0] loop_count_is_one; 
assign loop_count_is_one = {(hwLrf_mem[7][11:0] == 1), (hwLrf_mem[6][11:0] == 1), (hwLrf_mem[5][11:0] == 1), 
                            (hwLrf_mem[4][11:0] == 1), (hwLrf_mem[3][11:0] == 1), (hwLrf_mem[2][11:0] == 1), 
                            (hwLrf_mem[1][11:0] == 1), (hwLrf_mem[0][11:0] == 1)} ;
```

2. Find the Innermost Terminating Loop: A priority encoder finds the index of the innermost loop (highest bit set) that is about to finish.

```verilog
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
        default: begin     leading_one = 3'b000; end
    endcase
end
```

3. Count Consecutive Terminating Loops: The logic then counts how many consecutive parent loops are also terminating, starting from the leading_one. This sum gives the final number_of_ended_loop.

```verilog
logic [7:0] loop_temp2; 
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

assign number_of_ended_loop = {2'b0, loop_temp[0]} + {2'b0, loop_temp[1]} + {2'b0, loop_temp[2]} + {2'b0, loop_temp[3]} +
                              {2'b0, loop_temp[4]} + {2'b0, loop_temp[5]} + {2'b0, loop_temp[6]} + {2'b0, loop_temp[7]};
```

The PC logic is straightforward. If a hardware loop is active and the PC reaches the loop's end address, a multiplexer redirects the PC back to the loop's start address. This happens with zero overhead, as no branch instruction is fetched or executed.

```verilog
assign loop_endx4 = {24'd0, loop_end, 2'b00};
always @(*) begin 
  if (is_loop_notend) begin 
    if (pc == loop_endx4 + RESET_PC) begin 
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
```

For data-intensive tasks, hardware loops can integrate with an Address Generation Unit (AGU) to handle automatic pointer arithmetic. The tag stored in the hwLrf signals the AGU which address registers to modify (e.g., post-increment) for each completed loop iteration. A state machine ensures that the correct tags are sent to the AGU when a memory instruction (lw or sw) is encountered.


```verilog
hwl_state_idle: begin 
  hwl_tag_en_1_reg <= '0;
  hwl_tag_en_2_reg <= '0;
  hwl_tag_en_3_reg <= '0; 
  hwl_tag_en_4_reg <= '0; 
  hwl_tag_en_5_reg <= '0; 
  hwl_tag_en_6_reg <= '0; 
  hwl_tag_en_7_reg <= '0; 
  if (is_lw || is_sw) begin 
    hwl_state <= hwl_state_mem; 
    hwl_loop_lv <= {2'b0, loop_lv}; 
    hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
  end else begin 
    hwl_state <= hwl_state_idle;
  end
end
```

In this state, we determine which loops have completed since the last memory operation by comparing the saved 'hwl_loop_lv' with the current 'loop_lv'. Based on the difference, the appropriate tags are enabled. For brevity, only one condition is shown. The full implementation includes 'else if' clauses for differences from 1 to 6.

```verilog
hwl_state_mem: begin 
  if (grid_state == '0) begin
    hwl_state <= hwl_state_var;
    
    if (hwl_loop_lv == {2'b0, loop_lv}) begin 
      hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
      hwl_tag_en_2_reg <= '0;
      hwl_tag_en_3_reg <= '0;
      hwl_tag_en_4_reg <= '0;
      hwl_tag_en_5_reg <= '0;
      hwl_tag_en_6_reg <= '0;
      hwl_tag_en_7_reg <= '0;
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 1) begin 
      hwl_tag_en_1_reg <= '0; // hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0;
      hwl_tag_en_4_reg <= '0;
      hwl_tag_en_5_reg <= '0;
      hwl_tag_en_6_reg <= '0;
      hwl_tag_en_7_reg <= '0;
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 2) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0;
      hwl_tag_en_5_reg <= '0;
      hwl_tag_en_6_reg <= '0;
      hwl_tag_en_7_reg <= '0;
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 3) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= '0;
      hwl_tag_en_6_reg <= '0;
      hwl_tag_en_7_reg <= '0;
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 4) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= hwLrf_mem[hwl_loop_lv-4][16:12];
      hwl_tag_en_6_reg <= '0;
      hwl_tag_en_7_reg <= '0;
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 5) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
      hwl_tag_en_6_reg <= hwLrf_mem[hwl_loop_lv-5][16:12];
      hwl_tag_en_7_reg <= '0;
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 6) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
      hwl_tag_en_6_reg <= '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
      hwl_tag_en_7_reg <= hwLrf_mem[hwl_loop_lv-6][16:12];
    end 
  end else begin 
    hwl_state <= hwl_state_mem;
  end
end

hwl_state_var: begin 
  if (is_lw || is_sw) begin 
    hwl_state <= hwl_state_mem; 
    if (hwl_loop_lv == {2'b0, loop_lv}) begin 
      hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 1) begin 
      hwl_tag_en_1_reg <= '0; // hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= hwLrf_mem[hwl_loop_lv-1][16:12];
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 2) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= hwLrf_mem[hwl_loop_lv-2][16:12];
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 3) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= hwLrf_mem[hwl_loop_lv-3][16:12];
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 4) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= hwLrf_mem[hwl_loop_lv-4][16:12];
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 5) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
      hwl_tag_en_6_reg <= hwLrf_mem[hwl_loop_lv-5][16:12];
    end else if (hwl_loop_lv - {2'b0, loop_lv} == 6) begin 
      hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
      hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
      hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
      hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
      hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
      hwl_tag_en_6_reg <= '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
      hwl_tag_en_7_reg <= hwLrf_mem[hwl_loop_lv-6][16:12];
    end 
  end else begin
    if (is_hwloop_pc_end) begin 
      hwl_state <= hwl_state_idle; 
    end else begin
      hwl_state <= hwl_state_mem; 
      if (hwl_loop_lv == {2'b0, loop_lv}) begin 
        hwl_tag_en_1_reg <= hwLrf_mem[loop_lv][16:12];
      end else if (hwl_loop_lv - {2'b0, loop_lv} == 1) begin 
        hwl_tag_en_1_reg <= '0; // hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg <= hwLrf_mem[hwl_loop_lv-1][16:12];
      end else if (hwl_loop_lv - {2'b0, loop_lv} == 2) begin 
        hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg <= hwLrf_mem[hwl_loop_lv-2][16:12];
      end else if (hwl_loop_lv - {2'b0, loop_lv} == 3) begin 
        hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg <= hwLrf_mem[hwl_loop_lv-3][16:12];
      end else if (hwl_loop_lv - {2'b0, loop_lv} == 4) begin 
        hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg <= hwLrf_mem[hwl_loop_lv-4][16:12];
      end else if (hwl_loop_lv - {2'b0, loop_lv} == 5) begin 
        hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
        hwl_tag_en_6_reg <= hwLrf_mem[hwl_loop_lv-5][16:12];
      end else if (hwl_loop_lv - {2'b0, loop_lv} == 6) begin 
        hwl_tag_en_1_reg <= '0; //hwLrf_mem[hwl_loop_lv][16:12];
        hwl_tag_en_2_reg <= '0; //hwLrf_mem[hwl_loop_lv-1][16:12];
        hwl_tag_en_3_reg <= '0; //hwLrf_mem[hwl_loop_lv-2][16:12];
        hwl_tag_en_4_reg <= '0; //hwLrf_mem[hwl_loop_lv-3][16:12];
        hwl_tag_en_5_reg <= '0; //hwLrf_mem[hwl_loop_lv-4][16:12];
        hwl_tag_en_6_reg <= '0; //hwLrf_mem[hwl_loop_lv-5][16:12];
        hwl_tag_en_7_reg <= hwLrf_mem[hwl_loop_lv-6][16:12];
      end 
    end
  end
end
```