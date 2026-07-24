# TinyNPU Verification Plan

## Objective

Demonstrate that the standalone TinyNPU accelerator computes signed 4x4 INT8
matrix products correctly, follows its control protocol, terminates within a
bounded time, passes strict lint, and remains synthesizable.

## Verification Layers

| Layer | Implementation | Purpose |
|---|---|---|
| Unit RTL | `tb/mac_unit_tb.sv` | Directed signed MAC arithmetic |
| Core RTL | `tb/tinynpu_core_tb.sv` | Fixed end-to-end matrix operation |
| Golden model | `model/golden_model.py` | Independent expected results |
| Vector generation | `model/generate_vectors.py` | Reproducible directed and random matrices |
| Random RTL | `tb/tinynpu_random_tb.sv` | Hardware-versus-model result checking |
| Assertions | `tb/tinynpu_assertions.sv` | Protocol, state, and timeout checking |
| Coverage | `tb/tinynpu_coverage.sv` | Stimulus/result closure goals |
| Static checks | Verilator and Yosys | Lint and synthesizability |
| Automation | Make and GitHub Actions | Repeatable local and CI execution |

## Directed MAC Testing

The MAC testbench checks 10 cases covering:

- Positive x positive
- Negative x positive
- Positive x negative
- Negative x negative
- Positive and negative existing accumulators
- Zero multiplication
- Signed INT8 minimum (`-128`)
- Signed INT8 maximum (`127`)

Pass criterion: all expected accumulator values match exactly.

## Fixed Core Test

The core testbench loads two known 4x4 matrices, starts computation, waits for
completion, and compares all 16 signed result elements.

Pass criterion: 16/16 outputs match and no timeout occurs.

## Deterministic Vector Campaign

The vector generator writes matrices and golden results into a plain-text
simulation file. The default run uses:

```text
5 directed cases
25 randomized cases
seed = 20260711
```

Directed cases include:

- Zero matrices
- Identity multiplied by a signed pattern
- Signed pattern multiplied by identity
- All-maximum inputs multiplied by ones
- Alternating `-128`/`127` boundary inputs

Random matrices draw every value from the complete signed INT8 range. The seed
and random-case count are Makefile parameters.

For each case, the RTL testbench:

1. Loads all 16 A elements.
2. Loads all 16 B elements.
3. Pulses `start`.
4. Requires `busy` to assert.
5. Requires completion within 200 cycles.
6. Samples all 16 results.
7. Compares each result against the Python-generated value.

Default pass criterion: 30/30 cases and 480/480 result samples with zero
mismatches.

## Assertion Checks

The assertion monitor enforces:

- `busy` and `done` are never high together.
- Loads occur only in the idle protocol phase.
- `start` occurs only while inactive.
- Leaving `busy` transitions through `done`.
- `done` follows an active computation.
- Computation does not exceed `MAX_BUSY_CYCLES`.

Any failure terminates simulation with `$fatal`.

## Functional Coverage Goals

The coverage monitor requires:

- Exact expected operand-load count
- Exact expected result-sample count
- One `done` event per matrix case
- At least one positive input
- At least one negative input
- At least one zero input
- At least one INT8 minimum input
- At least one INT8 maximum input
- At least one positive output
- At least one negative output
- At least one zero output

These are executable release gates, not informational-only counters.

## Static Quality Gates

### Verilator

`make lint` runs `--lint-only -Wall` against the synthesizable core and treats
warnings as failures.

### Yosys

`make synth-check` reads the SystemVerilog, resolves `tinynpu_core` as the top,
runs process lowering and optimization, checks the design, and reports
statistics.

## Reproduction

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
make clean
make check
```

Custom deterministic campaign:

```bash
make clean
make random RANDOM_CASES=100 RANDOM_SEED=12345
```

## v0.2.0-alpha Baseline

```text
MAC cases:                  10 passed
Fixed core outputs:         16 passed
Vector cases:               30 passed
Vector result samples:      480
RTL/model mismatches:       0
Python tests:               4 passed
Assertion failures:         0
Coverage failures:          0
Verilator lint:             passed
Yosys design check:         passed
```
