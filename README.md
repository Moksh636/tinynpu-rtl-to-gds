# TinyNPU RTL-to-GDS Project

TinyNPU is a small INT8 matrix-multiply accelerator project focused on ASIC/VLSI learning.

## Project Goals

1. Design a synthesizable INT8 matrix-multiply accelerator in SystemVerilog.
2. Verify the design using a Python golden model and self-checking testbench.
3. Add assertions, coverage, and regression tests.
4. Bring the design onto FPGA with a simple host interface.
5. Run the design through an OpenLane/OpenROAD RTL-to-GDS physical design flow.
6. Document architecture, verification, timing, area, utilization, and layout results.

## Initial Target

Compute:

C = A x B

Where:
- A is a 4x4 signed INT8 matrix
- B is a 4x4 signed INT8 matrix
- C is a 4x4 signed INT32 matrix

## Planned Project Stages

1. TinyNPU core RTL
2. SystemVerilog simulation testbench
3. Python golden model
4. Randomized regression testing
5. Assertions and coverage
6. FPGA demo
7. OpenLane/OpenROAD physical implementation
8. Final project report and resume-ready documentation
