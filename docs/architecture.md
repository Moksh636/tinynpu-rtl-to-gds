# TinyNPU Architecture

## Overview

TinyNPU is a small INT8 matrix-multiply accelerator. The first version computes a 4x4 matrix multiplication:

C = A x B

A and B contain signed 8-bit integers. C contains signed 32-bit accumulated results.

## Main Blocks

1. `tinynpu_top`
   - Top-level wrapper.
   - Connects control, input buffers, compute datapath, and output buffer.

2. `reg_file`
   - Stores control and status registers.
   - Later versions may expose these through APB-lite or UART.

3. `matmul_ctrl`
   - FSM controlling load, compute, and done states.

4. `mac_unit`
   - Signed multiply-accumulate unit.

5. Input buffers
   - Store matrix A and matrix B.

6. Output buffer
   - Stores matrix C.

## First Milestone

The first milestone is simulation-only:

- Load fixed matrices into the testbench.
- Run TinyNPU.
- Compare output against expected C values.
- Print PASS or FAIL.

## Later Milestones

- Python golden model
- Randomized tests
- Assertions
- Coverage counters
- FPGA demo
- OpenLane/OpenROAD physical design
