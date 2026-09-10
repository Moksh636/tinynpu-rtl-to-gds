`timescale 1ns/1ps
`include "tinypc_cpu_defs.svh"

module tinypc_imm_gen (
    input  logic [31:7] instr,
    input  logic [2:0]  imm_sel,
    output logic [31:0] imm
);

    always @* begin
        case (imm_sel)
            `TINYPC_IMM_I:
                imm = {{20{instr[31]}}, instr[31:20]};

            `TINYPC_IMM_S:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            `TINYPC_IMM_B:
                imm = {{19{instr[31]}}, instr[31], instr[7],
                       instr[30:25], instr[11:8], 1'b0};

            `TINYPC_IMM_U:
                imm = {instr[31:12], 12'b0};

            `TINYPC_IMM_J:
                imm = {{11{instr[31]}}, instr[31], instr[19:12],
                       instr[20], instr[30:21], 1'b0};

            default:
                imm = 32'b0;
        endcase
    end

endmodule
