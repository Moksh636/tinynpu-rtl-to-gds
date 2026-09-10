`ifndef TINYPC_CPU_DEFS_SVH
`define TINYPC_CPU_DEFS_SVH

// ALU operations
`define TINYPC_ALU_ADD     4'd0
`define TINYPC_ALU_SUB     4'd1
`define TINYPC_ALU_SLL     4'd2
`define TINYPC_ALU_SLT     4'd3
`define TINYPC_ALU_SLTU    4'd4
`define TINYPC_ALU_XOR     4'd5
`define TINYPC_ALU_SRL     4'd6
`define TINYPC_ALU_SRA     4'd7
`define TINYPC_ALU_OR      4'd8
`define TINYPC_ALU_AND     4'd9
`define TINYPC_ALU_COPY_B  4'd10

// Immediate formats
`define TINYPC_IMM_NONE    3'd0
`define TINYPC_IMM_I       3'd1
`define TINYPC_IMM_S       3'd2
`define TINYPC_IMM_B       3'd3
`define TINYPC_IMM_U       3'd4
`define TINYPC_IMM_J       3'd5

// Writeback source
`define TINYPC_WB_ALU      2'd0
`define TINYPC_WB_MEM      2'd1
`define TINYPC_WB_PC4      2'd2

// Memory access size
`define TINYPC_MEM_BYTE    2'd0
`define TINYPC_MEM_HALF    2'd1
`define TINYPC_MEM_WORD    2'd2

`endif
