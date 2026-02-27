# Grid 

A grid architecture in computing connects a distributed network of computers, allowing them to function as a single, powerful system. This setup is designed to handle large-scale computational tasks that would be too demanding for a single machine. In the context of the provided paper, this concept is applied at a smaller scale within a hardware accelerator.

The XVI-V accelerator innovates on the traditional grid model by using a disaggregated or clustered grid architecture. Instead of one large, monolithic grid, XVI-V is built from multiple smaller, independent grids, referred to as clusters.




## Key features of this architecture include:


- Structure: Each cluster is a self-contained 4x4 grid of RISC-V PEs, complete with its own local memory (TCDM) and interconnect.

- Scalability: The total computing power is scaled by adding more of these 4x4 clusters. This approach avoids the performance degradation and resource utilization issues that occur when simply enlarging a single, "flatten" grid.

- Independence: Each grid operates with its own memory space, which allows for more flexible data management and helps reduce memory access conflicts.

By breaking down a large grid into multiple smaller, interconnected ones, the XVI-V architecture achieves better scalability and maintains stable performance as the number of processing elements increases.



