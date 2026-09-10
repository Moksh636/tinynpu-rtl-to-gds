`timescale 1ns/1ps
`include "tinypc_cpu_defs.svh"

module tinypc_decoder_tb;

    logic [31:0] instr;
    logic legal;
    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic use_rs1, use_rs2;
    logic reg_write;
    logic [3:0] alu_op;
    logic alu_src_imm, alu_src_pc;
    logic [2:0] imm_sel;
    logic mem_read, mem_write;
    logic [1:0] mem_size;
    logic load_unsigned;
    logic branch;
    logic [2:0] branch_funct3;
    logic jump, jump_reg;
    logic [1:0] wb_sel;
    logic system_trap;
    integer errors;

    localparam logic [6:0] OP_LUI      = 7'b0110111;
    localparam logic [6:0] OP_AUIPC    = 7'b0010111;
    localparam logic [6:0] OP_JAL      = 7'b1101111;
    localparam logic [6:0] OP_JALR     = 7'b1100111;
    localparam logic [6:0] OP_BRANCH   = 7'b1100011;
    localparam logic [6:0] OP_LOAD     = 7'b0000011;
    localparam logic [6:0] OP_STORE    = 7'b0100011;
    localparam logic [6:0] OP_OPIMM    = 7'b0010011;
    localparam logic [6:0] OP_OP       = 7'b0110011;
    localparam logic [6:0] OP_MISC_MEM = 7'b0001111;

    tinypc_decoder dut (
        .instr(instr),
        .legal(legal),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .use_rs1(use_rs1),
        .use_rs2(use_rs2),
        .reg_write(reg_write),
        .alu_op(alu_op),
        .alu_src_imm(alu_src_imm),
        .alu_src_pc(alu_src_pc),
        .imm_sel(imm_sel),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_size(mem_size),
        .load_unsigned(load_unsigned),
        .branch(branch),
        .branch_funct3(branch_funct3),
        .jump(jump),
        .jump_reg(jump_reg),
        .wb_sel(wb_sel),
        .system_trap(system_trap)
    );

    function automatic [31:0] enc_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic [31:0] enc_i(
        input logic [11:0] imm12,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_i = {imm12, rs1, funct3, rd, opcode};
    endfunction

    function automatic [31:0] enc_s(
        input logic [11:0] imm12,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [6:0] opcode
    );
        enc_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
    endfunction

    function automatic [31:0] enc_b(
        input logic [12:0] imm13,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [6:0] opcode
    );
        enc_b = {imm13[12], imm13[10:5], rs2, rs1, funct3,
                 imm13[4:1], imm13[11], opcode};
    endfunction

    function automatic [31:0] enc_u(
        input logic [19:0] imm20,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_u = {imm20, rd, opcode};
    endfunction

    function automatic [31:0] enc_j(
        input logic [20:0] imm21,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        enc_j = {imm21[20], imm21[10:1], imm21[11],
                 imm21[19:12], rd, opcode};
    endfunction

    task automatic fail(input string name, input string why);
        begin
            $display("FAIL: %s -- %s (instr=0x%08x)", name, why, instr);
            errors = errors + 1;
        end
    endtask

    task automatic check_r_alu(
        input logic [31:0] value,
        input logic [3:0] expected_alu,
        input string name
    );
        begin
            instr = value;
            #1;
            if (!legal) fail(name, "illegal");
            if (!use_rs1 || !use_rs2) fail(name, "source-use flags");
            if (!reg_write) fail(name, "reg_write");
            if (alu_op !== expected_alu) fail(name, "alu_op");
            if (alu_src_imm || alu_src_pc) fail(name, "ALU source select");
            if (mem_read || mem_write || branch || jump || system_trap) fail(name, "unexpected side effect");
            if ((rs1_addr != 5'd1) || (rs2_addr != 5'd2) || (rd_addr != 5'd3)) fail(name, "register fields");
            if (legal && use_rs1 && use_rs2 && reg_write && (alu_op === expected_alu))
                $display("PASS: %s", name);
        end
    endtask

    task automatic check_i_alu(
        input logic [31:0] value,
        input logic [3:0] expected_alu,
        input string name
    );
        begin
            instr = value;
            #1;
            if (!legal) fail(name, "illegal");
            if (!use_rs1 || use_rs2) fail(name, "source-use flags");
            if (!reg_write) fail(name, "reg_write");
            if (!alu_src_imm || alu_src_pc) fail(name, "ALU source select");
            if (imm_sel !== `TINYPC_IMM_I) fail(name, "imm_sel");
            if (alu_op !== expected_alu) fail(name, "alu_op");
            if (mem_read || mem_write || branch || jump || system_trap) fail(name, "unexpected side effect");
            if (legal && (alu_op === expected_alu)) $display("PASS: %s", name);
        end
    endtask

    task automatic check_load(
        input logic [2:0] f3,
        input logic [1:0] expected_size,
        input logic expected_unsigned,
        input string name
    );
        begin
            instr = enc_i(12'h010, 5'd1, f3, 5'd3, OP_LOAD);
            #1;
            if (!legal || !use_rs1 || use_rs2 || !reg_write || !alu_src_imm)
                fail(name, "base load controls");
            if ((alu_op !== `TINYPC_ALU_ADD) || (imm_sel !== `TINYPC_IMM_I))
                fail(name, "address-generation controls");
            if (!mem_read || mem_write || (wb_sel !== `TINYPC_WB_MEM))
                fail(name, "memory/writeback controls");
            if ((mem_size !== expected_size) || (load_unsigned !== expected_unsigned))
                fail(name, "load size/sign");
            if (legal && mem_read) $display("PASS: %s", name);
        end
    endtask

    task automatic check_store(
        input logic [2:0] f3,
        input logic [1:0] expected_size,
        input string name
    );
        begin
            instr = enc_s(12'h010, 5'd2, 5'd1, f3, OP_STORE);
            #1;
            if (!legal || !use_rs1 || !use_rs2 || reg_write || !alu_src_imm)
                fail(name, "base store controls");
            if ((alu_op !== `TINYPC_ALU_ADD) || (imm_sel !== `TINYPC_IMM_S))
                fail(name, "address-generation controls");
            if (mem_read || !mem_write || (mem_size !== expected_size))
                fail(name, "memory controls");
            if (legal && mem_write) $display("PASS: %s", name);
        end
    endtask

    task automatic check_branch(input logic [2:0] f3, input string name);
        begin
            instr = enc_b(13'h004, 5'd2, 5'd1, f3, OP_BRANCH);
            #1;
            if (!legal || !use_rs1 || !use_rs2 || reg_write)
                fail(name, "base branch controls");
            if (!branch || jump || (imm_sel !== `TINYPC_IMM_B))
                fail(name, "branch controls");
            if (branch_funct3 !== f3) fail(name, "branch funct3");
            if (legal && branch) $display("PASS: %s", name);
        end
    endtask

    task automatic check_illegal(input logic [31:0] value, input string name);
        begin
            instr = value;
            #1;
            if (legal) fail(name, "unexpectedly legal");
            else $display("PASS: %s rejected", name);
        end
    endtask

    initial begin
        errors = 0;
        instr = 32'b0;
        #1;

        // Register-register ALU instructions.
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, OP_OP), `TINYPC_ALU_ADD,  "ADD");
        check_r_alu(enc_r(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd3, OP_OP), `TINYPC_ALU_SUB,  "SUB");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b001, 5'd3, OP_OP), `TINYPC_ALU_SLL,  "SLL");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b010, 5'd3, OP_OP), `TINYPC_ALU_SLT,  "SLT");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b011, 5'd3, OP_OP), `TINYPC_ALU_SLTU, "SLTU");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd3, OP_OP), `TINYPC_ALU_XOR,  "XOR");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b101, 5'd3, OP_OP), `TINYPC_ALU_SRL,  "SRL");
        check_r_alu(enc_r(7'b0100000, 5'd2, 5'd1, 3'b101, 5'd3, OP_OP), `TINYPC_ALU_SRA,  "SRA");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd3, OP_OP), `TINYPC_ALU_OR,   "OR");
        check_r_alu(enc_r(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd3, OP_OP), `TINYPC_ALU_AND,  "AND");

        // Immediate ALU instructions.
        check_i_alu(enc_i(12'h005, 5'd1, 3'b000, 5'd3, OP_OPIMM), `TINYPC_ALU_ADD,  "ADDI");
        check_i_alu(enc_i(12'hfff, 5'd1, 3'b010, 5'd3, OP_OPIMM), `TINYPC_ALU_SLT,  "SLTI");
        check_i_alu(enc_i(12'hfff, 5'd1, 3'b011, 5'd3, OP_OPIMM), `TINYPC_ALU_SLTU, "SLTIU");
        check_i_alu(enc_i(12'h0aa, 5'd1, 3'b100, 5'd3, OP_OPIMM), `TINYPC_ALU_XOR,  "XORI");
        check_i_alu(enc_i(12'h0aa, 5'd1, 3'b110, 5'd3, OP_OPIMM), `TINYPC_ALU_OR,   "ORI");
        check_i_alu(enc_i(12'h0aa, 5'd1, 3'b111, 5'd3, OP_OPIMM), `TINYPC_ALU_AND,  "ANDI");
        check_i_alu(enc_i({7'b0000000, 5'd7}, 5'd1, 3'b001, 5'd3, OP_OPIMM), `TINYPC_ALU_SLL, "SLLI");
        check_i_alu(enc_i({7'b0000000, 5'd7}, 5'd1, 3'b101, 5'd3, OP_OPIMM), `TINYPC_ALU_SRL, "SRLI");
        check_i_alu(enc_i({7'b0100000, 5'd7}, 5'd1, 3'b101, 5'd3, OP_OPIMM), `TINYPC_ALU_SRA, "SRAI");

        // Upper immediates.
        instr = enc_u(20'h12345, 5'd3, OP_LUI);
        #1;
        if (!legal || !reg_write || (alu_op !== `TINYPC_ALU_COPY_B) ||
            !alu_src_imm || alu_src_pc || (imm_sel !== `TINYPC_IMM_U))
            fail("LUI", "controls");
        else $display("PASS: LUI");

        instr = enc_u(20'h12345, 5'd3, OP_AUIPC);
        #1;
        if (!legal || !reg_write || (alu_op !== `TINYPC_ALU_ADD) ||
            !alu_src_imm || !alu_src_pc || (imm_sel !== `TINYPC_IMM_U))
            fail("AUIPC", "controls");
        else $display("PASS: AUIPC");

        // Jumps.
        instr = enc_j(21'h004, 5'd3, OP_JAL);
        #1;
        if (!legal || !reg_write || !jump || jump_reg ||
            (imm_sel !== `TINYPC_IMM_J) || (wb_sel !== `TINYPC_WB_PC4))
            fail("JAL", "controls");
        else $display("PASS: JAL");

        instr = enc_i(12'h004, 5'd1, 3'b000, 5'd3, OP_JALR);
        #1;
        if (!legal || !use_rs1 || !reg_write || !jump || !jump_reg ||
            (imm_sel !== `TINYPC_IMM_I) || (wb_sel !== `TINYPC_WB_PC4))
            fail("JALR", "controls");
        else $display("PASS: JALR");

        // Branches.
        check_branch(3'b000, "BEQ");
        check_branch(3'b001, "BNE");
        check_branch(3'b100, "BLT");
        check_branch(3'b101, "BGE");
        check_branch(3'b110, "BLTU");
        check_branch(3'b111, "BGEU");

        // Loads and stores.
        check_load(3'b000, `TINYPC_MEM_BYTE, 1'b0, "LB");
        check_load(3'b001, `TINYPC_MEM_HALF, 1'b0, "LH");
        check_load(3'b010, `TINYPC_MEM_WORD, 1'b0, "LW");
        check_load(3'b100, `TINYPC_MEM_BYTE, 1'b1, "LBU");
        check_load(3'b101, `TINYPC_MEM_HALF, 1'b1, "LHU");

        check_store(3'b000, `TINYPC_MEM_BYTE, "SB");
        check_store(3'b001, `TINYPC_MEM_HALF, "SH");
        check_store(3'b010, `TINYPC_MEM_WORD, "SW");

        // Base FENCE is accepted as a NOP for this in-order single-master CPU.
        instr = enc_i(12'h000, 5'd0, 3'b000, 5'd0, OP_MISC_MEM);
        #1;
        if (!legal || reg_write || mem_read || mem_write || branch || jump)
            fail("FENCE", "NOP controls");
        else $display("PASS: FENCE as legal NOP");

        // ECALL and EBREAK are legal trap requests.
        instr = 32'h0000_0073;
        #1;
        if (!legal || !system_trap) fail("ECALL", "trap controls");
        else $display("PASS: ECALL");

        instr = 32'h0010_0073;
        #1;
        if (!legal || !system_trap) fail("EBREAK", "trap controls");
        else $display("PASS: EBREAK");

        // Representative illegal encodings.
        check_illegal(enc_r(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd3, OP_OP), "M-extension MUL encoding");
        check_illegal(enc_i({7'b1111111, 5'd1}, 5'd1, 3'b001, 5'd3, OP_OPIMM), "illegal SLLI funct7");
        check_illegal(enc_i(12'h000, 5'd1, 3'b011, 5'd3, OP_LOAD), "illegal LOAD funct3");
        check_illegal(enc_s(12'h000, 5'd2, 5'd1, 3'b011, OP_STORE), "illegal STORE funct3");
        check_illegal(enc_b(13'h004, 5'd2, 5'd1, 3'b010, OP_BRANCH), "illegal BRANCH funct3");
        check_illegal(enc_i(12'h000, 5'd1, 3'b001, 5'd3, OP_JALR), "illegal JALR funct3");
        check_illegal(32'h0020_0073, "unsupported SYSTEM encoding");
        check_illegal(32'h0000_0000, "zero instruction");

        if (errors != 0) begin
            $fatal(1, "TinyPC decoder tests failed: %0d errors", errors);
        end

        $display("TinyPC decoder tests PASSED.");
        $finish;
    end

endmodule
