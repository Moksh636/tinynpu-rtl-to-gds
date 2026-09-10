`timescale 1ns/1ps

module tinypc_regfile_tb;

    logic clk;
    logic rst_n;
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [31:0] rs1_rdata;
    logic [31:0] rs2_rdata;
    logic rd_we;
    logic [4:0] rd_addr;
    logic [31:0] rd_wdata;
    integer errors;

    tinypc_regfile dut (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_rdata(rs1_rdata),
        .rs2_rdata(rs2_rdata),
        .rd_we(rd_we),
        .rd_addr(rd_addr),
        .rd_wdata(rd_wdata)
    );

    always #5 clk = ~clk;

    task automatic write_reg(input logic [4:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            rd_we = 1'b1;
            rd_addr = addr;
            rd_wdata = data;
            @(posedge clk);
            #1;
            rd_we = 1'b0;
        end
    endtask

    task automatic check_reads(
        input logic [4:0] a1,
        input logic [31:0] e1,
        input logic [4:0] a2,
        input logic [31:0] e2,
        input string name
    );
        begin
            rs1_addr = a1;
            rs2_addr = a2;
            #1;
            if ((rs1_rdata !== e1) || (rs2_rdata !== e2)) begin
                $display("FAIL: %s rs1=0x%08x exp=0x%08x rs2=0x%08x exp=0x%08x",
                         name, rs1_rdata, e1, rs2_rdata, e2);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %s", name);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        rs1_addr = 5'd0;
        rs2_addr = 5'd0;
        rd_we = 1'b0;
        rd_addr = 5'd0;
        rd_wdata = 32'b0;
        errors = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        #1;

        check_reads(5'd0, 32'd0, 5'd1, 32'd0, "reset and x0");

        write_reg(5'd1, 32'h1234_5678);
        write_reg(5'd31, 32'hdead_beef);
        check_reads(5'd1, 32'h1234_5678, 5'd31, 32'hdead_beef, "dual combinational reads");

        write_reg(5'd0, 32'hffff_ffff);
        check_reads(5'd0, 32'd0, 5'd1, 32'h1234_5678, "x0 write suppressed");

        write_reg(5'd1, 32'ha5a5_5a5a);
        check_reads(5'd1, 32'ha5a5_5a5a, 5'd31, 32'hdead_beef, "overwrite register");

        rst_n = 1'b0;
        #1;
        @(posedge clk);
        #1;
        rst_n = 1'b1;
        check_reads(5'd1, 32'd0, 5'd31, 32'd0, "reset clears implementation state");

        if (errors != 0) begin
            $fatal(1, "TinyPC register-file tests failed: %0d errors", errors);
        end

        $display("TinyPC register-file tests PASSED.");
        $finish;
    end

endmodule
