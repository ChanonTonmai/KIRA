# Instruction-Set Architecture
Each CPU instruction is 32 bits long complince with RISC-V ISA. Since XVI-V provides the hardware loop engine and address generation unit, new ISAs are added. The following describes every supported ISA for XVI-V. 


## Arithmetic Operations
##### ADD
```
Format: add rd, rs1, rs2
Description: R[rd] = R[rs1] + R[rs2]
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|           0x0 |        rs2 | rs1        | 0x0           | rd       | 0x33        |

##### SUB
```
Format: sub rd, rs1, rs2
Description: R[rd] = R[rs1] - R[rs2]
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x20 |        rs2 | rs1        | 0x0           | rd       | 0x33        |


##### SLL
```
Format: sll rd, rs1, rs2
Description: R[rd] = R[rs1] << R[rs2] // Shift left
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x1           | rd       | 0x33        |

##### SLT
```
Format: slt rd, rs1, rs2
Description: R[rd] = (R[rs1] < R[rs2]) ? 1:0 // Set less than
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x2           | rd       | 0x33        |

##### SLTU
```
Format: sltu rd, rs1, rs2
Description: R[rd] = (R[rs1] < R[rs2]) ? 1:0 // Set less than unsigned
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x3           | rd       | 0x33        |


##### XOR
```
Format: xor rd, rs1, rs2
Description: R[rd] = R[rs1] xor R[rs2]
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x4           | rd       | 0x33        |


##### SRL
```
Format: srl rd, rs1, rs2
Description: R[rd] = R[rs1] >> R[rs2] // Shift Right (word)
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x5           | rd       | 0x33        |


##### SRA
```
Format: sra rd, rs1, rs2
Description: R[rd] = R[rs1] >> R[rs2] // Shift Right Arithmetic
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x20 |        rs2 | rs1        | 0x5           | rd       | 0x33        |


##### OR
```
Format: or rd, rs1, rs2
Description: R[rd] = R[rs1] or R[rs2] // logical or
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x6           | rd       | 0x33        |

##### AND
```
Format: and rd, rs1, rs2
Description: R[rd] = R[rs1] and R[rs2] // logical and
```

| funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---------------|------------|------------|---------------|----------|-------------|
|          0x00 |        rs2 | rs1        | 0x7           | rd       | 0x33        |



## Arithmetic Immediate Operations
##### ADDI
```
Format: addi rd, rs1, imm
Description: R[rd] = R[rs1] + imm 
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x0           | rd       | 0x13        |


##### SLLI
```
Format: slli rd, rs1, imm
Description: R[rd] = R[rs1] << imm // shift left immediate 
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x1           | rd       | 0x13        |

##### SLTI
```
Format: slti rd, rs1, imm
Description: R[rd] = (R[rs1] < imm) ? 1:0 // set less than immediate 
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x2           | rd       | 0x13        |


##### SLTIU
```
Format: sltiu rd, rs1, imm
Description: R[rd] = (R[rs1] < imm) ? 1:0 // set less than immediate unsigned
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x3           | rd       | 0x13        |

##### XORI
```
Format: xori rd, rs1, imm
Description: R[rd] = R[rs1] xor imm 
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x4           | rd       | 0x13        |

##### SRLI
```
Format: srli rd, rs1, imm
Description: R[rd] = R[rs1] >> imm // shift right immediate
```

| imm[31:25]  |imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|---|---------|------------|---------------|----------|-------------|
|  0x00  |    imm |  rs1       | 0x5           | rd       | 0x13        |

##### SRAI
```
Format: srli rd, rs1, imm
Description: R[rd] = R[rs1] >> imm // shift right arithmetic immediate
```

|imm[31:25]  |imm[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|--    |----------|------------|---------------|----------|-------------|
|  0x20 |      imm |  rs1       | 0x5           | rd       | 0x13        |

##### ORI
```
Format: xori rd, rs1, imm
Description: R[rd] = R[rs1] or imm 
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x6           | rd       | 0x13        |

##### ANDI
```
Format: xori rd, rs1, imm
Description: R[rd] = R[rs1] and imm 
```

| imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0] |
|------------|------------|---------------|----------|-------------|
|        imm |  rs1       | 0x7           | rd       | 0x13        |


##### LUI
```
Format: lui rd, imm
Description: R[rd] = {imm, 12'b0} // load upper immediate
```

| imm[31:12] | rd[11:7] | opcode[6:0] |
|------------|----------|-------------|
|      imm   | rd       | 0x37        |

##### AUIPC
```
Format: auipc rd, imm
Description: R[rd] = PC + {imm, 12'b0} // add upper immediate to PC
```

| imm[31:12] | rd[11:7] | opcode[6:0] |
|------------|----------|-------------|
|      imm   | rd       | 0x37        |

## Memory Instructions 


##### LB
```
Format: lb rd, imm(rs1)
Description: R[rd] = {M[R[rs1]+imm](7:0)} // Load byte
```
| imm[31:20] | rs1[19:15] | funt3[13:12] |rd[11:7] | opcode[6:0] |
|------------|----------  |------------- |-        | -           |
|      imm   | rs1        | 0x0          |rd       | 0x3         |

##### LH
```
Format: lh rd, imm(rs1)
Description: R[rd] = {M[R[rs1]+imm](15:0)} // Load halfword
```
| imm[31:20] | rs1[19:15] | funt3[13:12] |rd[11:7] | opcode[6:0] |
|------------|----------  |------------- |-        | -           |
|      imm   | rs1        | 0x1          |rd       | 0x3         |

##### LW
```
Format: lw rd, imm(rs1)
Description: R[rd] = {M[R[rs1]+imm](31:0)} // Load word
```
| imm[31:20] | rs1[19:15] | funt3[13:12] |rd[11:7] | opcode[6:0] |
|------------|----------  |------------- |-        | -           |
|      imm   | rs1        | 0x2          |rd       | 0x3         |

##### LBU
```
Format: lbu rd, imm(rs1)
Description: R[rd] = {M[R[rs1]+imm](7:0)} // Load byte unsigned
```
| imm[31:20] | rs1[19:15] | funt3[13:12] |rd[11:7] | opcode[6:0] |
|------------|----------  |------------- |-        | -           |
|      imm   | rs1        | 0x4          |rd       | 0x3         |

##### LHU
```
Format: lhu rd, imm(rs1)
Description: R[rd] = {M[R[rs1]+imm](15:0)} // Load halfword unsigned
```
| imm[31:20] | rs1[19:15] | funt3[13:12] |rd[11:7] | opcode[6:0] |
|------------|----------  |------------- |-        | -           |
|      imm   | rs1        | 0x5          |rd       | 0x3         |


##### SB
```
Format: sb rd, imm(rs1)
Description: M[R[rs1]+imm](7:0) = R[rs2](7:0) // Load halfword unsigned
```
| imm[31:25] | rs1[24:20] | rs1[19:15] |funt3[13:12] | imm[11:7] | opcode[6:0] |
|------------|----------  |-           |-------------|-          | -           |
| imm[11:5]  | rs2        | rs1        |0x0          | imm[4:0]  | 0x23        |

##### SH
```
Format: sh rd, imm(rs1)
Description: M[R[rs1]+imm](15:0) = R[rs2](15:0) // Load halfword unsigned
```
| imm[31:25] | rs1[24:20] | rs1[19:15] |funt3[13:12] | imm[11:7] | opcode[6:0] |
|------------|----------  |-           |-------------|-          | -           |
| imm[11:5]  | rs2        | rs1        |0x1          | imm[4:0]  | 0x23        |

##### SW
```
Format: sw rd, imm(rs1)
Description: M[R[rs1]+imm](31:0) = R[rs2](31:0) // Load halfword unsigned
```
| imm[31:25] | rs1[24:20] | rs1[19:15] |funt3[13:12] | imm[11:7] | opcode[6:0] |
|------------|----------  |-           |-------------|-          | -           |
| imm[11:5]  | rs2        | rs1        |0x2          | imm[4:0]  | 0x23        |

## Special Instruction designed for XVI-V


##### psrf.lw
```
psrf.lw rd, var(rs1)  
Description: addr = sum(ps[6var+i:6var+i+3]) + rd[rs1] 
             R[rd] = M[addr] 
             // architecturally support var upto 3 variables (2025)
```

| imm[31:20]          | [19:15] | Funct3[14:12] | [11:7]    | Opcode[6:0]      |
|---------------------|---------|---------------|-----------|------------------|
| var                 | rs1     | 111           | rd        | 0000100  (0x4)   |


##### psrf.sw

```
psrf.sw rs2, var(rs1)  
  addr = sum(ps[6var+i:6var+i+3]) + rd[rs1]
  M[addr] = R[rs2]
```
| imm[31:25] | [24:20] | [19:15] | Funct3[14:12] | imm[11:7] | Opcode[6:0] |
|------------|---------|---------|---------------|-----------|-------------|
| imm[11:5]  | rs2     | rs1     | 100           | imm[4:0]  | 0100100 (0x24)   |


##### psrf.addi
```
psrf.addi xd,xd, imm 
  xd = xd + imm
  for i in range(len(psrf_mem)): 
    if ps[i][tag] == xd:
      ps[i] = ps[i] + c[i]
```


| imm[31:20]          | [19:15] | Funct3[14:12] | [11:7]    | Opcode[6:0]     |
|---------------------|---------|---------------|-----------|-------------    |
| imm[11:0]           | px      | 000           | rd        | 0010101 (0x15)  |


##### psrf.{branch}
```
psrf.branch xs1, xs2, imm ->
  if branch: 
    pc = pc + imm
  else not branch
    for i in range(len(psrf_mem)): 
      if psrf_mem[i][tag] == xd:
        psrf_mem[i] = 0
```
| imm[31:25]    |  [24:20]    | [19:15] | Funct3[14:12] | [11:7] | Opcode[6:0] |
|---------------|------|---------|---------------|-----------|-------------|
| imm[12,10:0]     |   px2   | px1      | 000           | imm[4:1,11] | 1100100 (0x64)     |


##### corf.lui
```
corf.lui cx, imm
Description: corf[rd] = {imm, 12'b0} // load upper immediate
```

| imm[31:12]            | [11:7]    | Opcode[6:0] |
|---------------------  |-----------|-------------|
| imm                   | cx        | 111011 (0x3B)     |


##### corf.addi
```
corf.addi cx , cx, imm
```

| imm[31:20]          | [19:15] | Funct3[14:12] | [11:7] | Opcode[6:0] |
|---------------------|---------|---------------|-----------|-------------|
| imm[11:0]          | cx     | 000           | rd | 0010100 (0x14)     |


##### ppsrf.addi
```
ppsrf.addi px , px, imm
Description: psrf[rd] = {imm, 12'b0} // load upper immediate
```

| imm[31:20]          | [19:15] | Funct3[14:12] | [11:7] | Opcode[6:0] |
|---------------------|---------|---------------|-----------|-------------|
| imm[11:0]           | px      | 001           | rd | 0010100 (0x14)     |