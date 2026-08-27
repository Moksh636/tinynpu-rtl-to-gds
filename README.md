# TinyPC-NPU FPGA SoC

[![TinyPC-NPU CI](https://github.com/Moksh636/tinynpu-rtl-to-gds/actions/workflows/ci.yml/badge.svg)](https://github.com/Moksh636/tinynpu-rtl-to-gds/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Moksh636/tinynpu-rtl-to-gds?include_prereleases)](https://github.com/Moksh636/tinynpu-rtl-to-gds/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

TinyPC-NPU is a SystemVerilog hardware project being developed toward a small
FPGA computer with a pipelined RV32I-compatible CPU and a CPU-controlled INT8
neural-processing accelerator.

> **Development milestone:** `v0.4.0-alpha`
>
> The TinyNPU accelerator, APB3/MMIO wrapper, internal system interconnect,
> boot ROM, and program/data RAM are implemented. CPU, firmware, UART, timer,
> VGA, FPGA deployment, and ASIC physical design remain roadmap items.

The latest published GitHub release before this milestone is
`v0.3.0-alpha`. The v0.4 release gate has passed locally with
`make clean && make check`; the milestone is ready for commit, CI, and tagging.

## Implemented System

```text
Future RV32I CPU
      |
      | request / response
      v
+-----------------------+
| TinyPC interconnect   |
+----+-------------+----+
     |             |
     |             +----------------------+
     v                                    v
Boot ROM                               TinyNPU
4 KiB                                  APB3/MMIO
0x0000_0000                            0x4000_0000
     |
     +-------> Program/Data RAM
               16 KiB
               0x1000_0000
```

The system bus accepts one outstanding request at a time. RAM supports byte
write strobes. Boot-ROM writes, unaligned transactions, unmapped accesses,
partial-width TinyNPU writes, and TinyNPU APB errors return a system bus error.

Future peripheral windows are reserved now so CPU software can use a stable
memory map as UART, timer, and VGA are added.

See [System Memory Map](docs/system_memory_map.md).

## TinyNPU Accelerator

The current accelerator computes:

```text
C = A x B
```

with signed INT8 inputs and signed INT32 accumulation/results. The default
configuration is 4x4 and uses a single MAC datapath, requiring 64 busy cycles
for one matrix product.

The v0.3 APB3 wrapper exposes control, status, operand, and result registers to
software. The v0.4 interconnect now makes that APB peripheral reachable from
the system bus.

## Verification

The accelerator verification flow includes:

- directed MAC and matrix tests;
- deterministic Python-generated randomized vectors;
- Python/NumPy golden-model comparison;
- protocol/progress assertions and functional coverage;
- Verilator lint;
- Yosys synthesizability checks;
- GitHub Actions CI.

v0.4 adds two system-level tests:

- `tinypc_interconnect_tb.sv`: ROM, RAM, byte strobes, decode boundaries,
  unaligned/unmapped errors, NPU APB timing, and error propagation;
- `tinypc_npu_bus_tb.sv`: CPU-style operand loading, start, polling, signed
  result reads, and a second computation without reloading operands.

The integration test uses a signed matrix containing `-128` through `127`
boundary values and an identity matrix, so all 16 expected INT32 outputs are
unambiguous.

The v0.4 local release gate passed the complete accelerator, APB, interconnect,
and CPU-style TinyNPU regressions. It also passed Verilator lint and Yosys
synthesizability checks. GitHub Actions will provide the independent clean-run
confirmation after the milestone branch is pushed.

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

### Run v0.4 Only

```bash
make soc
```

### Existing Individual Checks

```bash
make mac
make core
make random
make model
make apb
make lint
make synth-check
```

Override the randomized accelerator campaign while preserving reproducibility:

```bash
make clean
make random RANDOM_CASES=100 RANDOM_SEED=12345
```

## Repository Structure

```text
rtl/                 Synthesizable accelerator, APB, interconnect, and memory RTL
tb/                  Directed, randomized, APB, and system-level testbenches
model/               Python golden model and vector generator
mk/                  Milestone-specific Makefile rules
docs/                Architecture, interfaces, memory map, and release notes
.github/workflows/   GitHub Actions continuous integration
sim/                 Generated simulation files (ignored)
waves/               Generated waveform files (ignored)
reports/             Generated local reports (ignored)
```

## Development Roadmap

See [ROADMAP.md](ROADMAP.md). The next implementation milestone is
`v0.5.0-alpha`: the pipelined RV32I-compatible CPU that will become the first
real master of the v0.4 system bus.

## Skills Demonstrated

- SystemVerilog RTL design
- Signed fixed-width arithmetic
- Parameterized accelerator design
- Finite-state-machine control
- APB3 peripheral integration
- Memory-mapped register design
- SoC address decoding and bus-error handling
- Boot-ROM and byte-write RAM design
- Self-checking system-level testbenches
- Python reference modeling
- Deterministic randomized verification
- Assertions and functional coverage
- Verilator lint and Yosys synthesis checks
- Regression automation and continuous integration
- Git-based milestone and release management

## Release Notes

- [v0.4.0-alpha](docs/releases/v0.4.0-alpha.md)
- [v0.3.0-alpha](docs/releases/v0.3.0-alpha.md)
- [v0.2.0-alpha](docs/releases/v0.2.0-alpha.md)
- [v0.1.0-alpha](docs/releases/v0.1.0-alpha.md)

## License

Released under the [MIT License](LICENSE).
