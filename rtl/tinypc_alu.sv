`timescale 1ns/1ps
`include "tinypc_cpu_defs.svh"

module tinypc_alu (
    input  logic [3:0]  alu_op,
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    output logic [31:0] result
);

    always @* begin
        case (alu_op)
            `TINYPC_ALU_ADD:    result = operand_a + operand_b;
            `TINYPC_ALU_SUB:    result = operand_a - operand_b;
            `TINYPC_ALU_SLL:    result = operand_a << operand_b[4:0];
            `TINYPC_ALU_SLT:    result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            `TINYPC_ALU_SLTU:   result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            `TINYPC_ALU_XOR:    result = operand_a ^ operand_b;
            `TINYPC_ALU_SRL:    result = operand_a >> operand_b[4:0];
            `TINYPC_ALU_SRA:    result = $signed(operand_a) >>> operand_b[4:0];
            `TINYPC_ALU_OR:     result = operand_a | operand_b;
            `TINYPC_ALU_AND:    result = operand_a & operand_b;
            `TINYPC_ALU_COPY_B: result = operand_b;
            default:            result = 32'b0;
        endcase
    end

endmodule
