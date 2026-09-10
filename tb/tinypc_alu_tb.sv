`timescale 1ns/1ps
`include "tinypc_cpu_defs.svh"

module tinypc_alu_tb;

    logic [3:0]  alu_op;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [31:0] result;
    integer errors;

    tinypc_alu dut (
        .alu_op(alu_op),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(result)
    );

    task automatic check(
        input logic [3:0]  op,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] expected,
        input string       name
    );
        begin
            alu_op = op;
            operand_a = a;
            operand_b = b;
            #1;
            if (result !== expected) begin
                $display("FAIL: %s got=0x%08x expected=0x%08x", name, result, expected);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %s = 0x%08x", name, result);
            end
        end
    endtask

    initial begin
        errors = 0;

        check(`TINYPC_ALU_ADD,    32'd5,        32'd7,        32'd12,       "ADD");
        check(`TINYPC_ALU_ADD,    32'hffff_ffff, 32'd1,        32'd0,        "ADD wrap");
        check(`TINYPC_ALU_SUB,    32'd5,        32'd7,        32'hffff_fffe, "SUB");
        check(`TINYPC_ALU_SLL,    32'd1,        32'd31,       32'h8000_0000, "SLL");
        check(`TINYPC_ALU_SLT,    32'hffff_ffff, 32'd1,        32'd1,        "SLT signed");
        check(`TINYPC_ALU_SLT,    32'h7fff_ffff, 32'h8000_0000, 32'd0,       "SLT signed boundary");
        check(`TINYPC_ALU_SLTU,   32'hffff_ffff, 32'd1,        32'd0,        "SLTU");
        check(`TINYPC_ALU_XOR,    32'h55aa_00ff, 32'h0f0f_f0f0, 32'h5aa5_f00f, "XOR");
        check(`TINYPC_ALU_SRL,    32'h8000_0000, 32'd31,       32'd1,        "SRL");
        check(`TINYPC_ALU_SRA,    32'h8000_0000, 32'd31,       32'hffff_ffff, "SRA");
        check(`TINYPC_ALU_OR,     32'h5500_00ff, 32'h00aa_ff00, 32'h55aa_ffff, "OR");
        check(`TINYPC_ALU_AND,    32'h55aa_00ff, 32'h0f0f_f0f0, 32'h050a_00f0, "AND");
        check(`TINYPC_ALU_COPY_B, 32'hdead_beef, 32'h1234_5678, 32'h1234_5678, "COPY_B");
        check(`TINYPC_ALU_SLL,    32'h1234_5678, 32'd32,       32'h1234_5678, "shift amount masks to 5 bits");

        if (errors != 0) begin
            $fatal(1, "TinyPC ALU tests failed: %0d errors", errors);
        end

        $display("TinyPC ALU tests PASSED.");
        $finish;
    end

endmodule
