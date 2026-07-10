# TinyPC-NPU FPGA SoC

[![TinyPC-NPU CI](https://github.com/Moksh636/tinynpu-rtl-to-gds/actions/workflows/ci.yml/badge.svg)](https://github.com/Moksh636/tinynpu-rtl-to-gds/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Moksh636/tinynpu-rtl-to-gds?include_prereleases)](https://github.com/Moksh636/tinynpu-rtl-to-gds/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

TinyPC-NPU is a SystemVerilog hardware project that is being developed into a
small FPGA computer with a pipelined CPU and a CPU-controlled INT8 neural
processing accelerator.

> **Project status:** `v0.1.0-alpha`
>
> The verified TinyNPU accelerator foundation is implemented. The CPU, SoC
> bus, memories, UART, VGA output, FPGA integration, and ASIC backend flow are
> active roadmap items and are not yet complete.

## Current Release

The current alpha release contains:

- Signed INT8 multiply-accumulate datapath
- Signed INT32 accumulation
- Sequential 4x4 matrix-multiplication core
- Controller for row, column, and inner-product traversal
- Self-checking SystemVerilog testbenches
- Python/NumPy golden model
- Pytest verification
- Makefile regression flow
- GitHub Actions continuous integration

## Current Verification Results

The complete regression checks:

- 10 directed signed MAC cases
- All 16 outputs of a 4x4 matrix multiplication
- Positive and negative operand combinations
- Zero behavior
- Existing-accumulator behavior
- INT8 boundary values
- 4 Python golden-model tests

Current result:

~~~text
MAC failures:               0
Matrix-result mismatches:   0
Python test failures:       0
~~~

## TinyNPU Baseline Architecture

The v0.1.0-alpha accelerator uses a single MAC datapath to calculate a 4x4
matrix product sequentially.

~~~text
Matrix A Storage ─┐
                  ├──> Controller ──> Signed MAC ──> Result Storage
Matrix B Storage ─┘         │
                            └── row / column / inner index control
~~~

The mathematical operation is:

~~~text
C = A × B
~~~

Where:

- `A` is a 4x4 signed INT8 matrix
- `B` is a 4x4 signed INT8 matrix
- `C` is a 4x4 signed INT32 result matrix

## Planned Final SoC

~~~text
Laptop / Python Host
         |
        UART
         |
+----------------------------------------------------+
|                TinyPC-NPU FPGA SoC                 |
|                                                    |
|  +----------+       +---------------------------+  |
|  | 5-Stage  |       | RAM / Boot ROM            |  |
|  | CPU      |       | UART / Timer / VGA        |  |
|  +----+-----+       +-------------+-------------+  |
|       |                           |                |
|       +------- Memory-Mapped Bus -+                |
|                    |                               |
|              +-----+------+                        |
|              |  TinyNPU   |                        |
|              | Accelerator|                        |
|              +------------+                        |
+----------------------------------------------------+
~~~

The planned final system includes:

- Custom 5-stage RV32I-compatible CPU
- Forwarding and hazard detection
- Pipeline stalls and flushes
- Boot ROM and system RAM
- Memory-mapped internal bus
- UART terminal and boot interface
- VGA text display
- CPU-controlled INT8 TinyNPU
- Bare-metal firmware
- FPGA synthesis, implementation, and timing closure
- OpenLane/OpenROAD backend analysis
- PPA comparison of multiple accelerator architectures

## Quick Start

### Requirements

- Linux or WSL
- GNU Make
- Python 3
- Icarus Verilog
- NumPy
- Pytest

### Set Up the Python Environment

~~~bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
~~~

### Run the Complete Regression

~~~bash
make clean
make test
~~~

### Run Individual Test Groups

~~~bash
make mac
make core
make model
~~~

### Open Waveforms

After running the RTL tests:

~~~bash
gtkwave waves/mac_unit.vcd
gtkwave waves/tinynpu_core.vcd
~~~

## Repository Structure

~~~text
rtl/                 Synthesizable SystemVerilog RTL
tb/                  Self-checking SystemVerilog testbenches
model/               Python golden model and tests
docs/                Architecture, verification, and release documents
scripts/             Automation scripts
fpga/                Future FPGA constraints and build files
openlane/            Future ASIC backend configuration
.github/workflows/   Continuous-integration configuration
waves/               Generated simulation waveforms
sim/                 Generated simulation executables
reports/             Generated reports
~~~

Generated simulation files, waveforms, virtual environments, and reports are
excluded from version control.

## Engineering Case Study

A detailed engineering case study is being developed alongside this project
and will be expanded as each milestone is completed.

The case study will document:

- Architecture and microarchitecture decisions
- Design tradeoffs and alternative approaches
- Verification strategy and test development
- Bugs encountered and how they were resolved
- Waveform analysis and debugging examples
- CPU, bus, memory, and accelerator integration
- FPGA synthesis, utilization, and timing results
- ASIC area, timing, power, and PPA comparisons
- Lessons learned throughout the development process

> **Case study status:** In progress. New sections, measurements, diagrams,
> and results will be added as the project advances from the accelerator
> foundation to the complete FPGA SoC and ASIC backend exploration.

## Development Roadmap

See [ROADMAP.md](ROADMAP.md) for the planned CPU, SoC, UART, VGA, FPGA, and
ASIC implementation stages.

## Skills Demonstrated

This project is intended to demonstrate practical experience with:

- SystemVerilog RTL design
- Self-checking hardware verification
- Signed fixed-width arithmetic
- Finite-state-machine design
- Datapath and controller separation
- Computer architecture
- Memory-mapped peripheral design
- Python reference modeling
- Regression automation
- FPGA design flow
- ASIC synthesis and physical-design exploration
- Git and continuous integration

## Release Notes

See the [v0.1.0-alpha release notes](docs/releases/v0.1.0-alpha.md).

## License

This project is released under the [MIT License](LICENSE).
