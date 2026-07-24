# TinyPC-NPU Development Roadmap

TinyPC-NPU is developed as independently testable hardware milestones. A box
is checked only when the implementation, verification, and supporting
documentation are present in the repository.

## v0.1.0-alpha: Accelerator Foundation

- [x] Signed INT8 multiply-accumulate unit
- [x] Self-checking MAC testbench
- [x] Sequential 4x4 INT8 matrix-multiplication core
- [x] Signed INT32 result accumulation
- [x] Self-checking fixed-matrix testbench
- [x] Python golden model
- [x] Unified Makefile regression
- [x] GitHub Actions continuous integration

## v0.2.0-alpha: Verification Hardening

- [x] Parameterize matrix, data, accumulator, and address dimensions
- [x] Connect deterministic randomized RTL tests to the Python golden model
- [x] Add five directed matrix-vector cases
- [x] Add simulation timeout protection
- [x] Add protocol and progress assertions
- [x] Add functional coverage counters and enforced coverage goals
- [x] Add strict Verilator lint
- [x] Add Yosys synthesizability checks
- [x] Run the complete verification gate in CI
- [x] Document architecture, microarchitecture, verification, and results

## v0.3.0-alpha: Memory-Mapped Accelerator

- [ ] Freeze the TinyNPU software-visible register map
- [ ] Implement a lightweight request/response or APB-like wrapper
- [ ] Add control, status, start, busy, and done registers
- [ ] Add indexed operand and result data windows
- [ ] Define behavior for invalid addresses and writes while busy
- [ ] Verify register reads, writes, reset values, and back-to-back operations
- [ ] Add a software-style driver test sequence

## v0.4.0-alpha: SoC Interconnect and Memory

- [ ] Define the complete system memory map
- [ ] Implement the internal request/response bus
- [ ] Implement boot ROM
- [ ] Implement program and data RAM
- [ ] Add bus-error and unmapped-address handling
- [ ] Verify bus reads, writes, stalls, and peripheral decoding

## v0.5.0-alpha: Pipelined CPU

- [ ] Implement RV32I instruction decode
- [ ] Implement register file and ALU
- [ ] Implement IF, ID, EX, MEM, and WB pipeline stages
- [ ] Implement forwarding
- [ ] Implement load-use hazard detection
- [ ] Implement stalls and pipeline flushing
- [ ] Implement branches, jumps, loads, and stores
- [ ] Run bare-metal CPU programs in simulation

## v0.6.0-alpha: UART and VGA System

- [ ] Add UART transmitter and receiver
- [ ] Add UART RX and TX FIFOs
- [ ] Add memory-mapped UART registers
- [ ] Add VGA timing generator
- [ ] Add text framebuffer and font ROM
- [ ] Add bare-metal terminal and display firmware

## v0.7.0-beta: FPGA Demonstration

- [ ] Integrate the complete FPGA SoC
- [ ] Add board constraints
- [ ] Complete synthesis and implementation
- [ ] Close timing
- [ ] Program the FPGA
- [ ] Demonstrate CPU-controlled TinyNPU operation
- [ ] Capture hardware measurements and utilization reports

## v0.8.0-beta: ASIC Backend Exploration

- [ ] Synthesize key blocks with Yosys
- [ ] Run OpenLane/OpenROAD physical implementation
- [ ] Generate timing, area, and power reports
- [ ] Compare one-MAC, 2x2-MAC, and 4x4-MAC architectures
- [ ] Document PPA tradeoffs
