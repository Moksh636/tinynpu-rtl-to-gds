# TinyPC-NPU System Memory Map

The v0.4 system uses a 32-bit byte-addressed address space. All CPU-visible
transactions are 32-bit requests; RAM supports byte write strobes while the
TinyNPU peripheral accepts full-word MMIO writes only.

| Address range | Size | Block | v0.4 behavior |
|---|---:|---|---|
| `0x0000_0000`-`0x0000_0FFF` | 4 KiB | Boot ROM | Read-only, implemented |
| `0x1000_0000`-`0x1000_3FFF` | 16 KiB | Program/data RAM | Read/write, implemented |
| `0x4000_0000`-`0x4000_0FFF` | 4 KiB | TinyNPU | MMIO/APB3 bridge, implemented |
| `0x4000_1000`-`0x4000_1FFF` | 4 KiB | UART | Reserved for v0.6 |
| `0x4000_2000`-`0x4000_2FFF` | 4 KiB | Timer | Reserved for v0.6 |
| `0x4000_3000`-`0x4000_3FFF` | 4 KiB | VGA/text display | Reserved for v0.6 |

All other addresses, including currently reserved peripheral windows, return a
bus error until their target block is implemented.

## Internal request/response bus

The v0.4 interconnect accepts one outstanding request at a time.

### Request

- `req_valid`: request is present.
- `req_ready`: interconnect can accept the request.
- `req_write`: `1` for write, `0` for read.
- `req_addr[31:0]`: byte address.
- `req_wdata[31:0]`: write data.
- `req_wstrb[3:0]`: byte write enables for RAM.

A request is accepted when `req_valid && req_ready` is true on a rising clock
edge.

### Response

- `rsp_valid`: response is valid for one cycle.
- `rsp_rdata[31:0]`: read data.
- `rsp_err`: transaction failed.

The first CPU implementation can simply stall after issuing a request until
`rsp_valid` is observed, so no response back-pressure signal is required in
this milestone.

## Error behavior

`rsp_err` is asserted for:

- any unaligned 32-bit address;
- writes to boot ROM;
- unmapped or not-yet-implemented address windows;
- partial-width TinyNPU writes;
- any APB `PSLVERR` returned by the TinyNPU wrapper.

RAM writes use `req_wstrb` and may update any subset of the four bytes.

## TinyNPU bridge timing

A request targeting the TinyNPU is translated into a legal APB3 setup phase
followed by an access phase. The CPU-facing request remains outstanding until
`PREADY` completes the APB transfer. `PRDATA` and `PSLVERR` are then returned
through the normal system response.
