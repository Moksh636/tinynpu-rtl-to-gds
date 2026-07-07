# TinyPC-NPU FPGA SoC

TinyPC-NPU is a SystemVerilog project to build a small FPGA-based computer system with a CPU-controlled INT8 neural processing accelerator.

## Final Goal

Build a tiny computer system on FPGA with:

- 5-stage RISC-V-style CPU
- RAM and boot ROM
- memory-mapped bus
- UART terminal interface
- VGA text display
- INT8 TinyNPU matrix-multiply accelerator
- Python golden-model checking
- SystemVerilog verification
- FPGA hardware demo
- OpenLane/OpenROAD backend reports for key blocks

## Current Progress

Completed so far:

- GitHub repo and Linux/WSL toolchain setup
- signed MAC unit
- self-checking MAC testbench
- sequential 4x4 INT8 TinyNPU core
- Python golden model
- basic project test target

## System Vision

Laptop terminal or Python host app communicates with the FPGA over UART. The FPGA system boots a small CPU from ROM. The CPU writes matrix data into the TinyNPU accelerator, starts computation, waits for completion, reads the result, and prints or displays PASS/FAIL.

## Planned System Architecture

```text
Laptop / Python Host
        |
      UART
        |
TinyPC-NPU FPGA SoC
        |
+-------+-----------------------------+
| CPU   | RAM | ROM | UART | Display |
+-------+-----------------------------+
        |
   Memory-Mapped Bus
        |
     TinyNPU
```

## TinyNPU Function

The accelerator computes:

C = A x B

Where:

- A is a 4x4 signed INT8 matrix
- B is a 4x4 signed INT8 matrix
- C is a 4x4 signed INT32 result matrix

## Build and Test

Activate the Python environment:

source .venv/bin/activate

Run all current tests:

make test
