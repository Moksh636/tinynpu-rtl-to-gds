# TinyPC-NPU FPGA SoC

[![TinyPC-NPU CI](https://github.com/Moksh636/tinynpu-rtl-to-gds/actions/workflows/ci.yml/badge.svg)](https://github.com/Moksh636/tinynpu-rtl-to-gds/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Moksh636/tinynpu-rtl-to-gds?include_prereleases)](https://github.com/Moksh636/tinynpu-rtl-to-gds/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

TinyPC-NPU is a SystemVerilog hardware project being developed toward a small
FPGA computer with a pipelined CPU and a CPU-controlled INT8 neural-processing
accelerator.

> **Project status:** `v0.2.0-alpha`
>
> The parameterized TinyNPU accelerator and its hardened verification flow are
> implemented. The memory-mapped wrapper, CPU, SoC bus, memories, UART, VGA,
> FPGA integration, and ASIC backend flow remain roadmap items.

## Current Release

`v0.2.0-alpha` strengthens the accelerator foundation with reproducible,
hardware-versus-model verification:

- Parameterized signed INT8 matrix-multiplication core
- Signed INT32 accumulation
- Deterministic Python-generated RTL vectors
- Five directed matrix cases and 25 randomized cases by default
- Self-checking comparison of every result element
- Protocol and timeout assertions
- Functional coverage counters with enforced coverage goals
- Strict Verilator lint
- Yosys synthesizability checks
- Makefile regression and GitHub Actions CI

The implemented accelerator is still a standalone compute block. It does not
yet expose a memory-mapped software interface.

## Verified Release Results

The `v0.2.0-alpha` release gate completed with:

```text
Directed MAC cases:          10 passed
Fixed matrix outputs:        16 passed
Vector campaign:             30/30 cases passed
Vector result samples:       480
RTL/model mismatches:        0
Python golden-model tests:   4 passed
Assertion failures:          0
Coverage goals missed:       0
Verilator lint:              passed
Yosys design check:          passed
```

Default deterministic campaign:

```text
Directed matrix cases:       5
Randomized matrix cases:     25
Random seed:                 20260711
Computation latency:         64 busy cycles per 4x4 case
```

Functional coverage observed in the release run:

```text
Operand loads:               960
Positive input values:       461
Negative input values:       439
Zero input values:           60
INT8 minimum values:         13
INT8 maximum values:         28
Busy cycles:                 1920
Done events:                 30
Positive output values:      228
Negative output values:      234
Zero output values:          18
```

## Accelerator Architecture

The current design computes:

```text
C = A x B
```

where `A` and `B` are signed INT8 matrices and `C` is a signed INT32 result
matrix.

```text
              load interface
                    |
       +------------+------------+
       |                         |
+------+-------+          +------+-------+
| Matrix A RAM |          | Matrix B RAM |
+------+-------+          +------+-------+
       |                         |
       +------------+------------+
                    |
             +------+------+
             | Signed MAC  |
             +------+------+
                    |
             +------+------+
             | Result RAM  |
             +-------------+
                    ^
                    |
       IDLE -> COMPUTE -> DONE controller
          row / column / inner-product indices
```

The baseline uses one MAC datapath and performs one multiply-accumulate per
compute cycle. For the default 4x4 configuration, one matrix product requires
`4^3 = 64` busy cycles.

See:

- [Architecture](docs/architecture.md)
- [Microarchitecture](docs/microarchitecture.md)
- [Verification plan](docs/verification_plan.md)
- [Engineering case study](docs/engineering_case_study.md)

## Planned Final SoC

```text
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
```

The planned system includes a custom RV32I-compatible pipeline, memories,
internal interconnect, UART, VGA text output, bare-metal firmware, FPGA timing
closure, and an OpenLane/OpenROAD PPA study. These blocks are future scope and
are not part of this alpha release.

## Quick Start

### Requirements

- Linux or WSL
- GNU Make
- Python 3
- Icarus Verilog
- Verilator
- Yosys
- NumPy
- Pytest

### Set Up Python

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

### Run the Complete Release Gate

```bash
make clean
make check
```

### Run Individual Checks

```bash
make mac
make core
make random
make model
make lint
make synth-check
```

Override the random campaign while preserving reproducibility:

```bash
make clean
make random RANDOM_CASES=100 RANDOM_SEED=12345
```

### Open Waveforms

```bash
gtkwave waves/mac_unit.vcd
gtkwave waves/tinynpu_core.vcd
gtkwave waves/tinynpu_random.vcd
```

## Repository Structure

```text
rtl/                 Synthesizable accelerator RTL
tb/                  Directed, randomized, assertion, and coverage RTL
model/               Python golden model and vector generator
docs/                Architecture, plans, case study, and release notes
.github/workflows/   GitHub Actions continuous integration
sim/                 Generated simulation files (ignored)
waves/               Generated waveform files (ignored)
reports/             Generated local reports (ignored)
```

## Development Roadmap

See [ROADMAP.md](ROADMAP.md). The next implementation milestone is a
memory-mapped accelerator wrapper with software-visible control, status,
operand, and result registers.

## Skills Demonstrated

- SystemVerilog RTL design
- Signed fixed-width arithmetic
- Parameterized hardware design
- Finite-state-machine control
- Self-checking testbench development
- Python reference modeling
- Deterministic constrained-random-style stimulus
- Assertions and timeout protection
- Functional coverage and closure checks
- Verilator lint and Yosys synthesis checks
- Regression automation and continuous integration
- Git-based milestone and release management

## Release Notes

- [v0.2.0-alpha](docs/releases/v0.2.0-alpha.md)
- [v0.1.0-alpha](docs/releases/v0.1.0-alpha.md)

## License

Released under the [MIT License](LICENSE).
