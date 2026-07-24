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
