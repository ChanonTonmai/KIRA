# Data Memory System (TCDM)

Tightly Coupled Data Memory (TCDM) is a distributed, multi-banked L1 scratchpad memory system used within the XVI-V accelerator's clusters. It is designed to provide high-bandwidth data access for the Processing Elements (PEs) and is a key component in the accelerator's scalable architecture.

## Architecture and Access
Each XVI-V cluster, which contains 16 PEs, has its own dedicated TCDM. This TCDM is not a single memory block but is composed of 16 identical, single-port memory banks. This design provides 16 ports, matching the number of PEs, to ensure a high degree of parallel access.

- PE Access: The 16 PEs within a cluster access their shared TCDM through a logarithmic interconnect. This interconnect allows any PE to access any data within its cluster's TCDM. Load and store operations take a minimum of two cycles, assuming there are no memory bank conflicts.

- Host Access: The host processor manages data transfer between the main DDR memory and the TCDMs using a DMA engine through a TCDM-interface (TI).



- Each bank can store upto 4096x32 words or 16536 bytes. It is byte-addressable from programming perspective. Forming 16 memory banks can considered as a huge memory size 256 KB. Since we have 16 memory banks, therefore there are 16 memory port per cluster. 


## Memory Conflicts
A primary performance bottleneck in the system is memory conflicts, which occur when multiple PEs attempt to access the same memory bank simultaneously.

Resolution: When a conflict happens, the logarithmic interconnect arbitrates access and serves each PE's request sequentially, which introduces additional delay cycles.

Disaggregation Benefit: The core innovation of XVI-V is the disaggregation of the architecture into smaller clusters, each with its own TCDM. This structurally limits the maximum number of potential conflicts within any single TCDM to 16 (the number of PEs in a cluster), significantly reducing the overall memory contention compared to a larger, non-clustered "State-of-the-Art" (SoA) CGRA with a single TCDM.