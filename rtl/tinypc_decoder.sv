`timescale 1ns/1ps
`include "tinypc_cpu_defs.svh"

module tinypc_decoder (
    input  logic [31:0] instr,

    output logic        legal,
    output logic [4:0]  rs1_addr,
    output logic [4:0]  rs2_addr,
    output logic [4:0]  rd_addr,
    output logic        use_rs1,
    output logic        use_rs2,

    output logic        reg_write,
    output logic [3:0]  alu_op,
    output logic        alu_src_imm,
    output logic        alu_src_pc,
    output logic [2:0]  imm_sel,

    output logic        mem_read,
    output logic        mem_write,
    output logic [1:0]  mem_size,
    output logic        load_unsigned,

    output logic        branch,
    output logic [2:0]  branch_funct3,
    output logic        jump,
    output logic        jump_reg,

    output logic [1:0]  wb_sel,
    output logic        system_trap
);

    localparam logic [6:0] OPCODE_LUI      = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC    = 7'b0010111;
    localparam logic [6:0] OPCODE_JAL      = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR     = 7'b1100111;
    localparam logic [6:0] OPCODE_BRANCH   = 7'b1100011;
    localparam logic [6:0] OPCODE_LOAD     = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE    = 7'b0100011;
    localparam logic [6:0] OPCODE_OP_IMM   = 7'b0010011;
    localparam logic [6:0] OPCODE_OP       = 7'b0110011;
    localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111;
    localparam logic [6:0] OPCODE_SYSTEM   = 7'b1110011;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode   = instr[6:0];
    assign rd_addr  = instr[11:7];
    assign funct3   = instr[14:12];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign funct7   = instr[31:25];

    always_comb begin
        legal         = 1'b0;
        use_rs1       = 1'b0;
        use_rs2       = 1'b0;
        reg_write     = 1'b0;
        alu_op        = `TINYPC_ALU_ADD;
        alu_src_imm   = 1'b0;
        alu_src_pc    = 1'b0;
        imm_sel       = `TINYPC_IMM_NONE;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        mem_size      = `TINYPC_MEM_WORD;
        load_unsigned = 1'b0;
        branch        = 1'b0;
        branch_funct3 = funct3;
        jump          = 1'b0;
        jump_reg      = 1'b0;
        wb_sel        = `TINYPC_WB_ALU;
        system_trap   = 1'b0;

        case (opcode)
            OPCODE_LUI: begin
                legal       = 1'b1;
                reg_write   = 1'b1;
                alu_op      = `TINYPC_ALU_COPY_B;
                alu_src_imm = 1'b1;
                imm_sel     = `TINYPC_IMM_U;
            end

            OPCODE_AUIPC: begin
                legal       = 1'b1;
                reg_write   = 1'b1;
                alu_op      = `TINYPC_ALU_ADD;
                alu_src_imm = 1'b1;
                alu_src_pc  = 1'b1;
                imm_sel     = `TINYPC_IMM_U;
            end

            OPCODE_JAL: begin
                legal       = 1'b1;
                reg_write   = 1'b1;
                imm_sel     = `TINYPC_IMM_J;
                jump        = 1'b1;
                wb_sel      = `TINYPC_WB_PC4;
            end

            OPCODE_JALR: begin
                if (funct3 == 3'b000) begin
                    legal       = 1'b1;
                    use_rs1     = 1'b1;
                    reg_write   = 1'b1;
                    alu_op      = `TINYPC_ALU_ADD;
                    alu_src_imm = 1'b1;
                    imm_sel     = `TINYPC_IMM_I;
                    jump        = 1'b1;
                    jump_reg    = 1'b1;
                    wb_sel      = `TINYPC_WB_PC4;
                end
            end

            OPCODE_BRANCH: begin
                case (funct3)
                    3'b000, // BEQ
                    3'b001, // BNE
                    3'b100, // BLT
                    3'b101, // BGE
                    3'b110, // BLTU
                    3'b111: begin // BGEU
                        legal     = 1'b1;
                        use_rs1   = 1'b1;
                        use_rs2   = 1'b1;
                        imm_sel   = `TINYPC_IMM_B;
                        branch    = 1'b1;
                    end
                    default: begin
                    end
                endcase
            end

            OPCODE_LOAD: begin
                case (funct3)
                    3'b000: begin // LB
                        legal         = 1'b1;
                        mem_size      = `TINYPC_MEM_BYTE;
                        load_unsigned = 1'b0;
                    end
                    3'b001: begin // LH
                        legal         = 1'b1;
                        mem_size      = `TINYPC_MEM_HALF;
                        load_unsigned = 1'b0;
                    end
                    3'b010: begin // LW
                        legal         = 1'b1;
                        mem_size      = `TINYPC_MEM_WORD;
                        load_unsigned = 1'b0;
                    end
                    3'b100: begin // LBU
                        legal         = 1'b1;
                        mem_size      = `TINYPC_MEM_BYTE;
                        load_unsigned = 1'b1;
                    end
                    3'b101: begin // LHU
                        legal         = 1'b1;
                        mem_size      = `TINYPC_MEM_HALF;
                        load_unsigned = 1'b1;
                    end
                    default: begin
                    end
                endcase

                if (legal) begin
                    use_rs1     = 1'b1;
                    reg_write   = 1'b1;
                    alu_op      = `TINYPC_ALU_ADD;
                    alu_src_imm = 1'b1;
                    imm_sel     = `TINYPC_IMM_I;
                    mem_read    = 1'b1;
                    wb_sel      = `TINYPC_WB_MEM;
                end
            end

            OPCODE_STORE: begin
                case (funct3)
                    3'b000: begin // SB
                        legal    = 1'b1;
                        mem_size = `TINYPC_MEM_BYTE;
                    end
                    3'b001: begin // SH
                        legal    = 1'b1;
                        mem_size = `TINYPC_MEM_HALF;
                    end
                    3'b010: begin // SW
                        legal    = 1'b1;
                        mem_size = `TINYPC_MEM_WORD;
                    end
                    default: begin
                    end
                endcase

                if (legal) begin
                    use_rs1     = 1'b1;
                    use_rs2     = 1'b1;
                    alu_op      = `TINYPC_ALU_ADD;
                    alu_src_imm = 1'b1;
                    imm_sel     = `TINYPC_IMM_S;
                    mem_write   = 1'b1;
                end
            end

            OPCODE_OP_IMM: begin
                use_rs1     = 1'b1;
                reg_write   = 1'b1;
                alu_src_imm = 1'b1;
                imm_sel     = `TINYPC_IMM_I;

                case (funct3)
                    3'b000: begin // ADDI
                        legal  = 1'b1;
                        alu_op = `TINYPC_ALU_ADD;
                    end
                    3'b010: begin // SLTI
                        legal  = 1'b1;
                        alu_op = `TINYPC_ALU_SLT;
                    end
                    3'b011: begin // SLTIU
                        legal  = 1'b1;
                        alu_op = `TINYPC_ALU_SLTU;
                    end
                    3'b100: begin // XORI
                        legal  = 1'b1;
                        alu_op = `TINYPC_ALU_XOR;
                    end
                    3'b110: begin // ORI
                        legal  = 1'b1;
                        alu_op = `TINYPC_ALU_OR;
                    end
                    3'b111: begin // ANDI
                        legal  = 1'b1;
                        alu_op = `TINYPC_ALU_AND;
                    end
                    3'b001: begin // SLLI
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_SLL;
                        end
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: begin // SRLI
                                legal  = 1'b1;
                                alu_op = `TINYPC_ALU_SRL;
                            end
                            7'b0100000: begin // SRAI
                                legal  = 1'b1;
                                alu_op = `TINYPC_ALU_SRA;
                            end
                            default: begin
                            end
                        endcase
                    end
                    default: begin
                    end
                endcase

                if (!legal) begin
                    use_rs1     = 1'b0;
                    reg_write   = 1'b0;
                    alu_src_imm = 1'b0;
                    imm_sel     = `TINYPC_IMM_NONE;
                end
            end

            OPCODE_OP: begin
                use_rs1   = 1'b1;
                use_rs2   = 1'b1;
                reg_write = 1'b1;

                case (funct3)
                    3'b000: begin
                        case (funct7)
                            7'b0000000: begin // ADD
                                legal  = 1'b1;
                                alu_op = `TINYPC_ALU_ADD;
                            end
                            7'b0100000: begin // SUB
                                legal  = 1'b1;
                                alu_op = `TINYPC_ALU_SUB;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b001: begin // SLL
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_SLL;
                        end
                    end
                    3'b010: begin // SLT
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_SLT;
                        end
                    end
                    3'b011: begin // SLTU
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_SLTU;
                        end
                    end
                    3'b100: begin // XOR
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_XOR;
                        end
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: begin // SRL
                                legal  = 1'b1;
                                alu_op = `TINYPC_ALU_SRL;
                            end
                            7'b0100000: begin // SRA
                                legal  = 1'b1;
                                alu_op = `TINYPC_ALU_SRA;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b110: begin // OR
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_OR;
                        end
                    end
                    3'b111: begin // AND
                        if (funct7 == 7'b0000000) begin
                            legal  = 1'b1;
                            alu_op = `TINYPC_ALU_AND;
                        end
                    end
                    default: begin
                    end
                endcase

                if (!legal) begin
                    use_rs1   = 1'b0;
                    use_rs2   = 1'b0;
                    reg_write = 1'b0;
                end
            end

            OPCODE_MISC_MEM: begin
                // Base RV32I FENCE. The current single-master, in-order system
                // has no externally observable reordering, so FENCE is a legal NOP.
                if (funct3 == 3'b000) begin
                    legal = 1'b1;
                end
            end

            OPCODE_SYSTEM: begin
                // v0.5 treats ECALL/EBREAK as a simulation-visible trap request.
                if ((instr == 32'h0000_0073) || (instr == 32'h0010_0073)) begin
                    legal       = 1'b1;
                    system_trap = 1'b1;
                end
            end

            default: begin
            end
        endcase
    end

endmodule
