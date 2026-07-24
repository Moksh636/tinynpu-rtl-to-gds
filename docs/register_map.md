# Proposed TinyNPU Register Map

> **Status:** Design proposal for the next milestone. No memory-mapped wrapper
> is implemented in `v0.2.0-alpha`.

The first wrapper should expose a compact word-addressed interface while
keeping the current `tinynpu_core` load/start/result protocol internal.

## Proposed Registers

| Offset | Name | Access | Proposed purpose |
|---:|---|---|---|
| `0x00` | `CONTROL` | RW | Bit 0 issues `start`; other bits reserved |
| `0x04` | `STATUS` | RO | Bit 0 `busy`, bit 1 `done`, bit 2 optional error |
| `0x08` | `A_ADDR` | RW | Matrix A element index |
| `0x0C` | `A_DATA` | RW | Signed operand data for matrix A |
| `0x10` | `B_ADDR` | RW | Matrix B element index |
| `0x14` | `B_DATA` | RW | Signed operand data for matrix B |
| `0x18` | `C_ADDR` | RW | Result element index |
| `0x1C` | `C_DATA` | RO | Signed result data |
| `0x20` | `CONFIG` | RO | Encoded matrix and data-width information |

## Questions to Resolve Before RTL

- Whether `start` is write-one-to-pulse or level-sensitive
- Whether `done` clears on read, on a new start, or through an explicit bit
- Whether operand writes auto-increment addresses
- Response behavior for writes while busy
- Response behavior for out-of-range addresses
- Bus protocol choice: custom valid/ready or APB-like

This document must be frozen before the v0.3 wrapper implementation begins.

<!-- BEGIN V0.3 APB REGISTER MAP -->

## APB3 Peripheral Register Map

TinyNPU v0.3 exposes the matrix-multiplication accelerator through a
32-bit APB3 slave interface.

The interface uses zero wait states. `PREADY` remains asserted, and
each transfer completes during the APB access phase.

All registers require 32-bit-aligned accesses.

| Address | Register | Access | Description |
|---:|---|---|---|
| `0x000` | `CONTROL` | Write | Start computation and clear sticky status |
| `0x004` | `STATUS` | Read | Busy, completion, error, and operand status |
| `0x008` | `CONFIG` | Read | Hardware configuration |
| `0x010` | `A_INDEX` | Read/write | Select matrix A element |
| `0x014` | `A_DATA` | Read/write | Access selected matrix A element |
| `0x018` | `B_INDEX` | Read/write | Select matrix B element |
| `0x01C` | `B_DATA` | Read/write | Access selected matrix B element |
| `0x020` | `C_INDEX` | Read/write | Select result matrix element |
| `0x024` | `C_DATA` | Read | Read selected result element |

### CONTROL — `0x000`

CONTROL fields are write-one actions. They do not retain their written
values.

| Bit | Field | Behavior |
|---:|---|---|
| 0 | `START` | Start matrix multiplication |
| 1 | `CLEAR_DONE` | Clear `DONE_STICKY` |
| 2 | `CLEAR_ERROR` | Clear `ERROR_STICKY` |
| 31:3 | Reserved | Write zero |

A START request is rejected when the core is busy or when all matrix A
and B elements have not been loaded.

### STATUS — `0x004`

| Bit | Field | Meaning |
|---:|---|---|
| 0 | `BUSY` | Computation is active |
| 1 | `DONE_STICKY` | At least one computation completed |
| 2 | `ERROR_STICKY` | An invalid APB operation occurred |
| 3 | `OPERANDS_READY` | All A and B elements have been loaded |
| 31:4 | Reserved | Read as zero |

`DONE_STICKY` and `ERROR_STICKY` remain asserted until software clears
them through CONTROL.

### CONFIG — `0x008`

| Bits | Field | Current value |
|---:|---|---:|
| 7:0 | Matrix dimension | 4 |
| 15:8 | Operand width | 8 |
| 23:16 | Accumulator/result width | 32 |
| 31:24 | Matrix element count | 16 |

The current CONFIG value is:

```text
0x10200804
```

### Operand access

Software writes an element by first selecting its index and then
writing its signed INT8 value:

```text
write A_INDEX = element_number
write A_DATA  = signed_operand
```

The same sequence applies to matrix B.

A and B reads return the selected INT8 value sign-extended to 32 bits.

Legal element indexes are 0 through 15.

### Result access

Software selects and reads a signed INT32 result:

```text
write C_INDEX = element_number
read  C_DATA
```

### Error conditions

`PSLVERR` is asserted for:

- unaligned transfers,
- undefined addresses,
- writes to read-only registers,
- indexes greater than 15,
- operand writes while the core is busy,
- START with incomplete operands,
- START while the core is busy.

Every rejected transfer also sets `ERROR_STICKY`.

<!-- END V0.3 APB REGISTER MAP -->
