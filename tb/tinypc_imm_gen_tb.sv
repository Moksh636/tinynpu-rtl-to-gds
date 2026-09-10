`timescale 1ns/1ps
`include "tinypc_cpu_defs.svh"

module tinypc_imm_gen_tb;

    logic [31:0] instr;
    logic [2:0] imm_sel;
    logic [31:0] imm;
    integer errors;

    tinypc_imm_gen dut (
        .instr(instr[31:7]),
        .imm_sel(imm_sel),
        .imm(imm)
    );

    task automatic check(
        input logic [31:0] test_instr,
        input logic [2:0]  sel,
        input logic [31:0] expected,
        input string       name
    );
        begin
            instr = test_instr;
            imm_sel = sel;
            #1;
            if (imm !== expected) begin
                $display("FAIL: %s got=0x%08x expected=0x%08x instr=0x%08x",
                         name, imm, expected, instr);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %s = 0x%08x", name, imm);
            end
        end
    endtask

    function automatic [31:0] enc_i(input logic [11:0] value);
        enc_i = {value, 20'b0};
    endfunction

    function automatic [31:0] enc_s(input logic [11:0] value);
        enc_s = {value[11:5], 13'b0, value[4:0], 7'b0};
    endfunction

    function automatic [31:0] enc_b(input logic [12:0] value);
        enc_b = {value[12], value[10:5], 13'b0, value[4:1], value[11], 7'b0};
    endfunction

    function automatic [31:0] enc_u(input logic [31:12] value);
        enc_u = {value, 12'b0};
    endfunction

    function automatic [31:0] enc_j(input logic [20:0] value);
        enc_j = {value[20], value[10:1], value[11], value[19:12], 12'b0};
    endfunction

    initial begin
        errors = 0;

        check(enc_i(12'h7ff), `TINYPC_IMM_I, 32'h0000_07ff, "I positive max");
        check(enc_i(12'h800), `TINYPC_IMM_I, 32'hffff_f800, "I negative min");
        check(enc_i(12'hfff), `TINYPC_IMM_I, 32'hffff_ffff, "I minus one");

        check(enc_s(12'h123), `TINYPC_IMM_S, 32'h0000_0123, "S positive");
        check(enc_s(12'hf80), `TINYPC_IMM_S, 32'hffff_ff80, "S negative");

        check(enc_b(13'h07fe), `TINYPC_IMM_B, 32'h0000_07fe, "B positive");
        check(enc_b(13'h1000), `TINYPC_IMM_B, 32'hffff_f000, "B negative");

        check(enc_u(20'habcde), `TINYPC_IMM_U, 32'habcde000, "U immediate");

        check(enc_j(21'h0fffe), `TINYPC_IMM_J, 32'h0000_fffe, "J positive");
        check(enc_j(21'h100000), `TINYPC_IMM_J, 32'hfff0_0000, "J negative");

        check(32'hffff_ffff, `TINYPC_IMM_NONE, 32'd0, "NONE");

        if (errors != 0) begin
            $fatal(1, "TinyPC immediate-generator tests failed: %0d errors", errors);
        end

        $display("TinyPC immediate-generator tests PASSED.");
        $finish;
    end

endmodule
