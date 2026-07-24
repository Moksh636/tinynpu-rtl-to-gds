# TinyNPU Architecture

## Scope

The implemented `v0.2.0-alpha` block is a standalone signed-integer matrix
accelerator. It accepts two matrices through a load interface, computes their
product, and exposes the result through an indexed read port.

The current release does **not** contain a CPU, bus wrapper, UART, VGA block,
boot ROM, RAM, firmware, FPGA top level, or physical-design implementation.

## Mathematical Operation

```text
C = A x B
```

For the default parameters:

- `A`: 4x4 signed INT8
- `B`: 4x4 signed INT8
- `C`: 4x4 signed INT32

Each output is calculated as:

```text
C[i][j] = sum(A[i][k] * B[k][j]), k = 0 ... N-1
```

## External Interface

| Signal | Direction | Purpose |
|---|---:|---|
| `clk` | input | Rising-edge clock |
| `rst_n` | input | Active-low asynchronous controller reset |
| `load_en` | input | Loads one operand element while idle |
| `load_sel` | input | Selects matrix A (`0`) or B (`1`) |
| `load_addr` | input | Linear operand-memory address |
| `load_data` | input | Signed operand value |
| `start` | input | Starts a loaded matrix operation |
| `result_addr` | input | Linear result-memory address |
| `result_data` | output | Signed result value |
| `busy` | output | High during matrix computation |
| `done` | output | High after completion until `start` is low |

## Main Blocks

```text
+----------------+       +----------------+
| Matrix A memory|       | Matrix B memory|
+-------+--------+       +--------+-------+
        |                         |
        +------------+------------+
                     |
              +------+------+
              |  mac_unit   |
              +------+------+
                     |
              +------+------+
              | Matrix C RAM|
              +-------------+
                     ^
                     |
             controller and indices
```

### Operand Memories

Two local arrays store `N*N` signed operand elements. Loads are accepted only
in `S_IDLE`. The memories intentionally do not reset because every operand is
loaded before use; avoiding reset also improves future FPGA memory inference.

### MAC Datapath

`mac_unit` performs a signed multiplication and explicitly sign-extends the
product to the accumulator width before addition. This avoids implicit-width
behavior and supports strict linting.

### Result Memory

The result array stores one signed accumulated value for each output element.
An output is written when the final inner-product term is processed.

### Controller

The controller tracks row `i`, column `j`, and inner-product index `k`. It
iterates in row-major output order and drives a single MAC datapath.

## State Machine

```text
          start
IDLE --------------> COMPUTE
 ^                       |
 |                       | final i,j,k
 | start == 0            v
 +-------------------- DONE
```

- `S_IDLE`: accepts operand loads and waits for `start`.
- `S_COMPUTE`: performs one multiply-accumulate per cycle.
- `S_DONE`: asserts `done`; returns to idle after `start` is deasserted.

`busy` and `done` are derived directly from the controller state and are
mutually exclusive.

## Addressing

Matrices use row-major linear addressing:

```text
A index = i*N + k
B index = k*N + j
C index = i*N + j
```

## Latency and Throughput

The baseline architecture contains one MAC datapath, so computation requires:

```text
N * N * N = N^3 busy cycles
```

At `N=4`, the measured computation time is 64 busy cycles per matrix pair.
Operand loading and result sampling occur outside this compute interval.

## Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `N` | 4 | Square-matrix dimension |
| `DATA_WIDTH` | 8 | Signed operand width |
| `ACC_WIDTH` | 32 | Signed accumulator/result width |
| `ADDR_WIDTH` | `$clog2(N*N)` | Linear memory-address width |

The RTL is parameterized, while the current Python model and randomized
verification campaign remain intentionally fixed at 4x4 INT8/INT32.

## Next Integration Boundary

The next milestone wraps this interface with software-visible registers. That
wrapper will own operand/result addressing, legal-operation checks, and bus
responses while preserving `tinynpu_core` as the compute engine.
