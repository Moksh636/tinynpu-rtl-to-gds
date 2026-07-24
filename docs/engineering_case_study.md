# TinyNPU Engineering Case Study

## Project Objective

The long-term objective is a small FPGA computer containing a custom CPU and a
software-controlled INT8 accelerator. The first two public milestones isolate
the accelerator so its arithmetic, control, and verification can mature before
SoC integration.

## What Is Implemented

The current hardware is a parameterized square-matrix engine using signed
operands, signed accumulation, local operand/result storage, and a three-state
controller. The default configuration computes a 4x4 INT8 matrix product into
16 INT32 results.

The design uses one MAC datapath. This is slower than a parallel array, but it
creates a small, observable baseline for verification and later PPA comparison.

## Development Sequence

### 1. MAC Foundation

The project began with a signed multiply-accumulate unit and a directed,
self-checking testbench. This isolated sign handling, accumulator behavior, and
INT8 boundary cases before introducing controller complexity.

### 2. Sequential Matrix Core

The MAC was integrated into a controller that traverses row `i`, column `j`,
and inner index `k`. A fixed-matrix testbench then validated every output of a
complete 4x4 multiplication.

### 3. Python Reference Model

A Python model provided an independent expression of the matrix operation.
Pytest checks validated the model itself before it was used to generate RTL
expectations.

### 4. Verification Hardening

The v0.2 work connected deterministic Python-generated vectors to the RTL,
then added protocol assertions, timeout protection, functional coverage,
strict lint, synthesis checks, and CI automation.

## Important Debugging Work

### Arithmetic Widths

Strict Verilator lint exposed implicit width expansion around the signed
product and accumulator. The MAC now explicitly sign-extends its product to
the accumulator width before addition. This makes the arithmetic intent clear
and removes tool-dependent ambiguity.

### Matrix Index Widths

Parameterized row, column, and inner-product indices required explicit sizing
when converted into linear memory addresses. Typed casts and explicit
extension removed width warnings while preserving parameterization.

### Reset and Memory Inference

A combined reset style caused lint concerns and would make future FPGA memory
inference less natural. Controller state remains asynchronously reset, while
matrix arrays intentionally have no reset and are initialized through the
load protocol.

### Bounded Completion

A functional design can still hang because of an FSM regression. The random
testbench and assertion monitor therefore enforce completion within 200 cycles.
The expected default computation uses exactly 64 busy cycles.

## Verification Architecture

```text
Python matrices
      |
      v
Python golden model ---> deterministic vector file
                                |
                                v
                         SystemVerilog testbench
                                |
                    +-----------+-----------+
                    |                       |
                    v                       v
                 TinyNPU              assertions/coverage
                    |
                    v
             result-by-result compare
```

The default release run combines five directed matrices with 25 seeded random
matrices. Every one of the 480 generated output elements is checked.

## v0.2.0-alpha Results

```text
10/10 directed MAC cases passed
16/16 fixed core outputs passed
30/30 vector cases passed
480/480 vector results matched
4/4 Python tests passed
0 assertion failures
0 coverage-goal failures
Verilator lint passed
Yosys design check passed
GitHub Actions main-branch CI passed
```

The functional coverage report included both signed extremes, positive,
negative, and zero inputs, plus positive, negative, and zero outputs.

## Engineering Tradeoffs

### Why One MAC?

- Minimal area for the first implementation
- Deterministic and easy-to-debug sequencing
- Clear reference point for future parallel versions
- Simple result writeback behavior

The cost is 64 compute cycles for a default 4x4 operation, excluding load and
readback time.

### Why Deterministic Randomization?

A fixed seed makes failures reproducible locally and in CI. The number of
random cases and seed can still be overridden from Make without changing code.

### Why Executable Coverage Goals?

Printing counters is not coverage closure. The monitor terminates the test if
required categories or expected transaction counts are absent, turning
coverage intent into a release criterion.

## Current Limitations

- The Python model and vector format are fixed at 4x4 despite parameterized RTL.
- There is no MMIO or bus wrapper.
- There is no saturation, overflow status, tiling, or streaming.
- No FPGA synthesis/implementation measurements exist yet.
- No OpenLane/OpenROAD layout exists yet.
- CPU and full-SoC blocks remain future work.

## Next Milestone

The next stage is a memory-mapped accelerator wrapper. It will convert software
reads and writes into the existing operand-load, start, status, and result-read
protocol. Verification will focus on register semantics, illegal accesses,
writes while busy, repeated operations, and software-style transaction flows.
