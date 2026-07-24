# TinyNPU APB3 Interface Specification

## Purpose

The `tinynpu_apb` module exposes the existing TinyNPU matrix
multiplication core as a software-accessible APB3 peripheral.

The wrapper does not change the mathematical implementation of
`tinynpu_core`. It translates APB register transactions into the
core's matrix-loading, start, status, and result interfaces.

## APB Interface

The wrapper uses a 32-bit APB3 slave interface:

- `PCLK`
- `PRESETn`
- `PSEL`
- `PENABLE`
- `PWRITE`
- `PADDR[11:0]`
- `PWDATA[31:0]`
- `PRDATA[31:0]`
- `PREADY`
- `PSLVERR`

The first implementation is zero-wait-state:

```systemverilog
assign PREADY = 1'b1;


For the current implementation, CONFIG returns `0x10200804`:

- matrix dimension: 4
- input width: 8
- accumulator width: 32
- matrix element count: 16
