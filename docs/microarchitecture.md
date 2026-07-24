# TinyNPU Microarchitecture

## Design Goal

The current microarchitecture prioritizes correctness, visibility, and a clean
verification target over peak throughput. A single signed MAC is reused for
all 64 products in a default 4x4 matrix multiplication.

## Datapath

`mac_unit` contains:

1. Signed `DATA_WIDTH x DATA_WIDTH` multiplication.
2. Explicit sign extension from product width to `ACC_WIDTH`.
3. Addition to the current accumulator.

The explicit extension was added during lint hardening so arithmetic intent is
unambiguous across simulators, linters, and synthesis tools.

## Storage

- `a_mem[N*N]`: signed operand matrix A
- `b_mem[N*N]`: signed operand matrix B
- `c_mem[N*N]`: signed result matrix C
- `acc`: partial sum for the current output element

A and B are loaded before `start`. C is written only on the final `k` cycle of
each output element.

## Control Sequence

At the start of an operation:

```text
i = 0
j = 0
k = 0
acc = 0
```

Each compute cycle evaluates:

```text
mac_out = acc + A[i][k] * B[k][j]
```

When `k` is not the final index, `mac_out` becomes the next accumulator and
`k` increments.

When `k` is the final index:

1. `mac_out` is written to `C[i][j]`.
2. `acc` and `k` clear.
3. `j` advances, or wraps while `i` advances.
4. The final `(i,j)` transitions the controller to `S_DONE`.

## Default Cycle Count

For `N=4`:

- 16 output elements
- 4 products per output
- 64 compute cycles total

The randomized testbench confirms every case finishes in 64 busy cycles.

## Reset Strategy

Controller state, indices, and the accumulator use active-low asynchronous
reset. Matrix arrays intentionally do not reset because the verification and
future software contract require operands to be initialized before execution.
This separation also avoids reset logic that can interfere with memory
inference.

## Protocol Assumptions

- Operand loads occur only while idle.
- `start` is pulsed only while idle.
- Operands are fully loaded before `start`.
- Results are sampled after `done`.
- `start` returns low before the controller leaves `S_DONE`.

The v0.2 assertion monitor converts these assumptions into executable checks.

## Current Tradeoffs

### Advantages

- Small and understandable datapath
- Deterministic latency
- Straightforward debug waveforms
- Easy hardware-versus-model comparison
- Good baseline for future PPA comparisons

### Limitations

- One MAC limits throughput
- No tiling or streaming input
- No saturation or overflow flag
- No software-visible register interface
- No backpressure or bus protocol

Parallel MAC arrays are intentionally deferred until the single-MAC baseline
has synthesis, timing, and area measurements for comparison.
