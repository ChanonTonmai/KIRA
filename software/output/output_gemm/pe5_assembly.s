# Assembly for PE5 (Cluster 5)
# Generated with PSRF, HWL and function support
.text
.global _start

_start:
    # Base address loading section for cluster 5
    # Loading x18 with address 0x28C8 (10440)
    # Using lui 3 and addi -1848 to create 10440
    lui x18, 3
    addi x18, x18, -1848

    # Loading x19 with address 0x4E20 (20000)
    # Using lui 5 and addi -480 to create 20000
    lui x19, 5
    addi x19, x19, -480

    # Loading x20 with address 0xC444 (50244)
    # Using lui 12 and addi 1092 to create 50244
    lui x20, 12
    addi x20, x20, 1092

    # Preload section for PSRF variables and coefficients
    # Using var=0 (registers 0-5)
    ppsrf.addi v0, v0, 10
    ppsrf.addi v1, v0, 12
    corf.addi c0, c0, 256
    corf.addi c1, c0, 4
    # Using var=1 (registers 6-11)
    ppsrf.addi v6, v6, 12
    ppsrf.addi v7, v6, 11
    corf.addi c6, c6, 256
    corf.addi c7, c6, 4
    # Using var=2 (registers 12-17)
    ppsrf.addi v12, v12, 10
    ppsrf.addi v13, v12, 11
    corf.addi c12, c12, 256
    corf.addi c13, c12, 4
    # Using var=2 (registers 12-17)
    ppsrf.addi v12, v12, 10
    ppsrf.addi v13, v12, 11
    corf.addi c12, c12, 256
    corf.addi c13, c12, 4

    # ========== Execution Section Begin ==========
    # hwl_imm_1 = ((2 << 23) + (9 << 17) + (10 << 12) + 8
    # Original pc_start=2, pc_stop=11, delay=0
    hwlrf.lui L1, 4394
    hwlrf.addi L1, L1, 8
    # hwl_imm_2 = ((4 << 23) + (7 << 17) + (11 << 12) + 64
    # Original pc_start=4, pc_stop=11, delay=0
    hwlrf.lui L2, 8427
    hwlrf.addi L2, L2, 64
    # hwl_imm_3 = ((6 << 23) + (5 << 17) + (12 << 12) + 64
    # Original pc_start=6, pc_stop=11, delay=0
    hwlrf.lui L3, 12460
    hwlrf.addi L3, L3, 64
    psrf.lw x1, 0(x18)
    psrf.lw x2, 1(x19)
    psrf.lw x3, 2(x20)
    mul x1, x1, x2
    add x3, x3, x1
    psrf.sw x3, 2(x20)
    # End of program
    ret
