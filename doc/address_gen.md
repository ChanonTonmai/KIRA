# Address Generation Unit 
In the loop execution, to provide programming convenience, generating an address for variable execution provides an increase in efficiency and reduces the cycle workload related to address calculation. Decoupling the address generation out of the loop execution provides significantly reduced instruction counts. 


## Idea & Concept 
The array address calculation can be generalized to the notion of affine computations [1], which are linear combinations of scalars and loop iterations and which can be executed efficiently by exploiting their degree of regularity across the loop iterations. Figure 1 shows how array addresses are considered as affine computations with the loop iterations. First, we see that affine computations can be compactly represented as affine tuples:The value of A[i][k] starts at 0x100 (as the base address) in iteration 0 and then increases with the linear combination of i and k corresponding with their offset, represented as (0x100, [256, 4]). Similarly, the array B[k][j] can be represented as the tuple (0x200, [256, 4]). 


## Microarchitecture 
The address generation unit needs to compute the affine computations, e.g., addr = ai+bj+ck, where a, b, and c are the offsets (coefficients). Utilizing the multiplication seems to be expensive in the logic design. We observe that the current address depends on the previous address. Therefore, instead of multiplication, we can add the address iteratively. First of all, to implement this in hardware, we introduce two new register files: the coefficient register file (CoRF) and the partial sum register file (PSRF). 


CoRF is responsible for storing the coefficient information (constant value). XVI-V supports up to 3 variables in the loop, and each variable can store up to 6 coefficients. Therefore, the size of the CoRF register is 18x32 bits. The PSRF is responsible for storing the partial sum between the equations, which also has a tag to decide where the updated partial sum is. The value for each partial sum is 32 bits, stored in [36:5], while the tag is the lower 5 bits, stored in [4:0]. Thus, the size of the PSRF register is 18x37 bits. It is depicted as an array initialization:

```verilog
localparam CORF_PSRF_MEM_DEPTH = 18;

reg [36:0] psrf_mem [0:CORF_PSRF_MEM_DEPTH-1];
initial begin
  integer i;
  for (i=0; i<CORF_PSRF_MEM_DEPTH; i=i+1) begin
      psrf_mem[i] = 37'b0;
  end
end

reg [31:0] corf_mem [0:CORF_PSRF_MEM_DEPTH-1];
initial begin
  integer i;
  for (i=0; i<CORF_PSRF_MEM_DEPTH; i=i+1) begin
      corf_mem[i] = 32'b0;
  end
end
```

To write the value in these two register files, we utilized the instructions like LUI and ADDI named corf.lui, corf.addi, and ppsrf.addi. The ppsrf.addi is responsible for writing the tag information to the PSRF register. The corf.lui will write the upper 20 bits, while corf.addi will write the 12 lower bits for the CoRF register. We also need to add new instructions to perform load and store operations, namely psrf.lw and psrf.sw. To utilize this hardware, apart from the new special load store operation, we also introduce new instructions: psrf.addi and psrf.{branch}. Essentially, the loop index increments using the addi instruction. The prsf.addi not only performs the same operation as the addi but also updates the PSRF based on the tag. In addition, to return the value back to its base, psrf.branch is asserted. It performs everything the same as the branch but also resets the value in both RF and PSRF to its base (normally zero). To load or store, the value in the PSRF is added together, resulting in the corrected address. The functional point of view of the instructions is listed as shown in the list below. Therefore, we will use these instructions in the loop instead. 

```verilog
psrf.lw rd, var(rs1)  
    addr = sum(ps[6var+i:6var+i+3]) + rd[rs1] 
    R[rd] = M[addr] 

psrf.sw rs2, var(rs1)  
    addr = sum(ps[6var+i:6var+i+3]) + rd[rs1]
    M[addr] = R[rs2]

psrf.addi xd,xd, imm 
    xd = xd + imm
    for i in range(len(psrf_mem)): 
        if ps[i][tag] == xd:
            ps[i] = ps[i] + c[i]

psrf.branch xs1, xs2, imm ->
    if branch: 
        pc = pc + imm
    else not branch
        for i in range(len(psrf_mem)): 
            if psrf_mem[i][tag] == xd:
                psrf_mem[i] = 0
```
The Verilog code below describes the utilization of the CoRF and PSRF register files with the corf.lui, corf.addi, and ppsrf.addi instructions. Assume the control signal from the conventional CPU:
- regwen_x is register write enable (active when we need to write some value back to register)
- wa is the write address specified in which register to write 
- wd is write data, specifying the data to write

```verilog
always @(*) begin
  if (is_corf_lui || is_corf_addi) begin 
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
    offs_we = regwen_x;
    offs_wa = wa[4:0]; 
    offs_wd = offs_mem[offs_wa] | imm;
  end else begin
    offs_we = '0;
    offs_wa = '0; 
    offs_wd = '0; 
  end
end

always @(posedge clk) begin
  // ppsrf write the tag information only
  if (is_ppsrf_addi) begin 
    if (psrf_we) begin
      psrf_mem[wa[4:0]][4:0] <= wd[4:0];
    end
  end 

  ... // other work for psrf_mem
end
```

However, the address generation unit needs to work seamlessly with the hardware loop engine. Thus, the loop control mechanism is not significant (psrf.addi and psrf.{branch}) since the loop control mechanism is controlled by the hardware loop engine. For the hardware loop, considering the PSRF register update, there are some conditions to meet before the update. The hardware loop engine should send the information of the executed loop, which is the corresponding tag (variable that iterates in the loop), to AGU. Then, all the PSRF registers need to be checked to see if they are equal to that tag or not. The checking mechanism performs once the loop is finished or we begin a new loop. If each PSRF tag is equal to the hardware loop tag, we need to update the PSRF register in that location. 

```verilog
always @(posedge clk) begin
  if (is_ppsrf_addi) begin 
    ... 
  else begin 
    if (( grid_state == '0 && is_hwloop_pc_end ) 
          || (is_hwLrf_lui)  
        )    
    
      begin
      if  ((psrf_mem[0][4:0] == psrf_wa && (is_psrf_addi || is_psrf_rst || is_hwLrf_lui  || is_psrf_branch)) || // For not using HW Loop
            psrf_mem[0][4:0] == hwl_tag_en_1 || psrf_mem[0][4:0] == hwl_tag_en_2 ||  // For using HW loop
            psrf_mem[0][4:0] == hwl_tag_en_3 || psrf_mem[0][4:0] == hwl_tag_en_4 || 
            psrf_mem[0][4:0] == hwl_tag_en_5 || psrf_mem[0][4:0] == hwl_tag_en_6 || 
            psrf_mem[0][4:0] == hwl_tag_en_7
      ) begin 
        if (((is_hwLrf_lui || is_psrf_rst) && psrf_mem[0][4:0] == psrf_wa )) begin
          psrf_mem[0][36:5] <= '0;
        end else begin
          if (is_hwLrf_lui || psrf_mem[0][4:0] == 0) begin 
            psrf_mem[0][36:5] <= psrf_mem[0][36:5]; 
          end else begin 
            psrf_mem[0][36:5] <= psrf_mem[0][36:5] + corf_mem[0]; 
          end
        end
      end 

      ...
    end
  end 
```

When the psrf.lw or psrf.sw is invoked, we need to read all the value bits in the PSRF file (psrf_mem[36:5]). Then, the address for the desired variable is the sum of all values in the corresponding psrf_mem. 
```verilog
always @(*) begin
  if (is_psrf_lw || is_psrf_sw) begin 
    if (psrf_var == 0) begin
      a_6add = psrf_mem[0][36:5]; 
      b_6add = psrf_mem[1][36:5];
      c_6add = psrf_mem[2][36:5]; 
      d_6add = psrf_mem[3][36:5]; 
      e_6add = psrf_mem[4][36:5]; 
      f_6add = psrf_mem[5][36:5];
      psrf_addr_temp = out_6add;
    end 
    else if (psrf_var == 1) begin 
      a_6add = psrf_mem[6][36:5]; 
      b_6add = psrf_mem[7][36:5];
      c_6add = psrf_mem[8][36:5]; 
      d_6add = psrf_mem[9][36:5]; 
      e_6add = psrf_mem[10][36:5]; 
      f_6add = psrf_mem[11][36:5];
      psrf_addr_temp = out_6add;
    end 
    else if (psrf_var == 2) begin 
      a_6add = psrf_mem[12][36:5]; 
      b_6add = psrf_mem[13][36:5];
      c_6add = psrf_mem[14][36:5]; 
      d_6add = psrf_mem[15][36:5]; 
      e_6add = psrf_mem[16][36:5]; 
      f_6add = psrf_mem[17][36:5];
      psrf_addr_temp = out_6add;
    end 
  end
  ...
end

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

```

## Reference

[1] Caroline Collange, David Defour, Yao Zhang. Dynamic detection of uniform and affine vectors in GPGPU computations. Euro-Par Parallel Processing Workshops 2009, Aug 2009, Delft, Netherlands. pp.46-55, 10.1007/978-3-642-14122-5_8. hal-00396719v2