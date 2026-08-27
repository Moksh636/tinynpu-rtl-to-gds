`timescale 1ns/1ps

module tinypc_interconnect_tb;

    localparam logic [31:0] ROM_BASE = 32'h0000_0000;
    localparam logic [31:0] RAM_BASE = 32'h1000_0000;
    localparam logic [31:0] NPU_BASE = 32'h4000_0000;

    logic        clk;
    logic        rst_n;
    logic        req_valid;
    logic        req_ready;
    logic        req_write;
    logic [31:0] req_addr;
    logic [31:0] req_wdata;
    logic [3:0]  req_wstrb;
    logic        rsp_valid;
    logic [31:0] rsp_rdata;
    logic        rsp_err;

    integer errors;
    integer stall_cycles;

    tinypc_interconnect #(
        .ROM_INIT_FILE("tb/data/boot_rom_test.hex"),
        .ROM_INIT_WORDS(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wstrb(req_wstrb),
        .rsp_valid(rsp_valid),
        .rsp_rdata(rsp_rdata),
        .rsp_err(rsp_err)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic bus_transaction(
        input  logic        write,
        input  logic [31:0] address,
        input  logic [31:0] wdata,
        input  logic [3:0]  wstrb,
        output logic [31:0] rdata,
        output logic        err,
        output integer      stalls
    );
        integer timeout_cycles;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = write;
            req_addr  = address;
            req_wdata = wdata;
            req_wstrb = wstrb;

            timeout_cycles = 0;
            while (!req_ready && timeout_cycles < 20) begin
                timeout_cycles = timeout_cycles + 1;
                @(negedge clk);
            end
            if (!req_ready) begin
                $fatal(1, "Bus request timeout at address 0x%08h", address);
            end

            @(posedge clk);
            @(negedge clk);

            req_valid = 1'b0;
            req_write = 1'b0;
            req_addr  = 32'b0;
            req_wdata = 32'b0;
            req_wstrb = 4'b0;

            stalls = 0;
            timeout_cycles = 0;
            while (!rsp_valid && timeout_cycles < 20) begin
                if (!req_ready) begin
                    stalls = stalls + 1;
                end
                timeout_cycles = timeout_cycles + 1;
                @(negedge clk);
            end
            if (!rsp_valid) begin
                $fatal(1, "Bus response timeout at address 0x%08h", address);
            end

            rdata = rsp_rdata;
            err   = rsp_err;

            @(posedge clk);
        end
    endtask

    task automatic expect_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       name
    );
        begin
            if (actual !== expected) begin
                $error("FAIL: %s expected 0x%08h got 0x%08h", name, expected, actual);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %s = 0x%08h", name, actual);
            end
        end
    endtask

    task automatic expect_bit(
        input logic  actual,
        input logic  expected,
        input string name
    );
        begin
            if (actual !== expected) begin
                $error("FAIL: %s expected %0b got %0b", name, expected, actual);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %s = %0b", name, actual);
            end
        end
    endtask

    logic [31:0] read_data;
    logic        transfer_error;

    initial begin
        $dumpfile("waves/tinypc_interconnect.vcd");
        $dumpvars(0, tinypc_interconnect_tb);

        errors     = 0;
        req_valid  = 1'b0;
        req_write  = 1'b0;
        req_addr   = 32'b0;
        req_wdata  = 32'b0;
        req_wstrb  = 4'b0;
        rst_n      = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("Starting TinyPC interconnect tests...");

        bus_transaction(1'b0, ROM_BASE, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "ROM read error");
        expect_value(read_data, 32'h00000297, "ROM word 0");

        bus_transaction(1'b0, ROM_BASE + 32'h004, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "ROM second read");
        expect_value(read_data, 32'h01028293, "ROM word 1");

        bus_transaction(1'b1, ROM_BASE, 32'hDEADBEEF, 4'b1111,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "ROM write rejected");

        bus_transaction(1'b1, RAM_BASE, 32'h11223344, 4'b1111,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "RAM full-word write");

        bus_transaction(1'b0, RAM_BASE, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "RAM full-word read");
        expect_value(read_data, 32'h11223344, "RAM full-word value");

        bus_transaction(1'b1, RAM_BASE, 32'hAABBCCDD, 4'b0101,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "RAM byte-strobe write");

        bus_transaction(1'b0, RAM_BASE, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_value(read_data, 32'h11BB33DD, "RAM byte-strobe result");

        bus_transaction(1'b0, RAM_BASE + 32'h2, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "unaligned read rejected");

        bus_transaction(1'b0, 32'h80000000, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "unmapped read rejected");

        /* Decode-boundary checks. */
        bus_transaction(1'b0, ROM_BASE + 32'h1000, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "ROM upper boundary unmapped");

        bus_transaction(1'b1, RAM_BASE + 32'h3FFC, 32'hCAFEBABE, 4'b1111,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "RAM last-word write");
        bus_transaction(1'b0, RAM_BASE + 32'h3FFC, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_value(read_data, 32'hCAFEBABE, "RAM last-word value");

        bus_transaction(1'b0, RAM_BASE + 32'h4000, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "RAM upper boundary unmapped");

        bus_transaction(1'b0, NPU_BASE + 32'h008, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b0, "NPU CONFIG read");
        expect_value(read_data, 32'h10200804, "NPU CONFIG value");
        if (stall_cycles < 2) begin
            $error("FAIL: NPU APB bridge did not stall master as expected");
            errors = errors + 1;
        end
        else begin
            $display("PASS: NPU APB bridge stalled for %0d cycles", stall_cycles);
        end

        bus_transaction(1'b0, NPU_BASE + 32'h00C, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "NPU PSLVERR propagated");

        bus_transaction(1'b1, NPU_BASE + 32'h010, 32'h00000001, 4'b0011,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "partial NPU write rejected");

        bus_transaction(1'b0, NPU_BASE + 32'h1000, 32'b0, 4'b0000,
                        read_data, transfer_error, stall_cycles);
        expect_bit(transfer_error, 1'b1, "NPU upper boundary unmapped");

        if (errors == 0) begin
            $display("TinyPC interconnect tests PASSED.");
        end
        else begin
            $fatal(1, "TinyPC interconnect tests FAILED with %0d errors", errors);
        end

        $finish;
    end

endmodule
