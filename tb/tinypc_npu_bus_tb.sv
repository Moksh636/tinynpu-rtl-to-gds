`timescale 1ns/1ps

module tinypc_npu_bus_tb;

    localparam logic [31:0] NPU_BASE     = 32'h4000_0000;
    localparam logic [31:0] ADDR_CONTROL = NPU_BASE + 32'h000;
    localparam logic [31:0] ADDR_STATUS  = NPU_BASE + 32'h004;
    localparam logic [31:0] ADDR_A_INDEX = NPU_BASE + 32'h010;
    localparam logic [31:0] ADDR_A_DATA  = NPU_BASE + 32'h014;
    localparam logic [31:0] ADDR_B_INDEX = NPU_BASE + 32'h018;
    localparam logic [31:0] ADDR_B_DATA  = NPU_BASE + 32'h01C;
    localparam logic [31:0] ADDR_C_INDEX = NPU_BASE + 32'h020;
    localparam logic [31:0] ADDR_C_DATA  = NPU_BASE + 32'h024;

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
    integer i;
    integer polls;

    logic signed [7:0] matrix_a [0:15];
    logic signed [7:0] matrix_b [0:15];

    tinypc_interconnect dut (
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
        output logic [31:0] rdata,
        output logic        err
    );
        integer timeout_cycles;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = write;
            req_addr  = address;
            req_wdata = wdata;
            req_wstrb = write ? 4'b1111 : 4'b0000;

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

            timeout_cycles = 0;
            while (!rsp_valid && timeout_cycles < 20) begin
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

    task automatic bus_write(
        input logic [31:0] address,
        input logic [31:0] data
    );
        logic [31:0] unused;
        logic        err;
        begin
            bus_transaction(1'b1, address, data, unused, err);
            if (err) begin
                $error("FAIL: bus write error at 0x%08h", address);
                errors = errors + 1;
            end
        end
    endtask

    task automatic bus_read(
        input  logic [31:0] address,
        output logic [31:0] data
    );
        logic err;
        begin
            bus_transaction(1'b0, address, 32'b0, data, err);
            if (err) begin
                $error("FAIL: bus read error at 0x%08h", address);
                errors = errors + 1;
            end
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

    logic [31:0] read_data;

    initial begin
        $dumpfile("waves/tinypc_npu_bus.vcd");
        $dumpvars(0, tinypc_npu_bus_tb);

        errors    = 0;
        req_valid = 1'b0;
        req_write = 1'b0;
        req_addr  = 32'b0;
        req_wdata = 32'b0;
        req_wstrb = 4'b0;
        rst_n     = 1'b0;

        /* A includes signed and boundary values in row-major order. */
        matrix_a[0]  = -128; matrix_a[1]  = -64;
        matrix_a[2]  = -7;   matrix_a[3]  = -1;
        matrix_a[4]  = 0;    matrix_a[5]  = 1;
        matrix_a[6]  = 2;    matrix_a[7]  = 3;
        matrix_a[8]  = 7;    matrix_a[9]  = 15;
        matrix_a[10] = 31;   matrix_a[11] = 63;
        matrix_a[12] = 64;   matrix_a[13] = 100;
        matrix_a[14] = 126;  matrix_a[15] = 127;

        for (i = 0; i < 16; i = i + 1) begin
            matrix_b[i] = 0;
        end

        /* B is a 4x4 identity matrix, so C must equal A. */
        matrix_b[0]  = 1;
        matrix_b[5]  = 1;
        matrix_b[10] = 1;
        matrix_b[15] = 1;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("Starting CPU-style TinyNPU bus computation test...");

        for (i = 0; i < 16; i = i + 1) begin
            bus_write(ADDR_A_INDEX, i);
            bus_write(ADDR_A_DATA, {{24{matrix_a[i][7]}}, matrix_a[i]});
            bus_write(ADDR_B_INDEX, i);
            bus_write(ADDR_B_DATA, {{24{matrix_b[i][7]}}, matrix_b[i]});
        end

        bus_read(ADDR_STATUS, read_data);
        if (!read_data[3]) begin
            $error("FAIL: OPERANDS_READY did not assert");
            errors = errors + 1;
        end
        else begin
            $display("PASS: OPERANDS_READY asserted");
        end

        bus_write(ADDR_CONTROL, 32'h00000001);

        polls = 0;
        read_data = 32'b0;
        while (!read_data[1] && polls < 100) begin
            bus_read(ADDR_STATUS, read_data);
            polls = polls + 1;
        end

        if (!read_data[1]) begin
            $error("FAIL: timed out waiting for TinyNPU DONE");
            errors = errors + 1;
        end
        else begin
            $display("PASS: TinyNPU DONE after %0d status polls", polls);
        end

        if (read_data[2]) begin
            $error("FAIL: TinyNPU ERROR sticky bit asserted unexpectedly");
            errors = errors + 1;
        end

        for (i = 0; i < 16; i = i + 1) begin
            bus_write(ADDR_C_INDEX, i);
            bus_read(ADDR_C_DATA, read_data);
            expect_value(
                read_data,
                {{24{matrix_a[i][7]}}, matrix_a[i]},
                "signed identity-matrix result"
            );
        end

        /* Reuse the loaded operands for a second CPU-controlled run. */
        bus_write(ADDR_CONTROL, 32'h00000002);
        bus_write(ADDR_CONTROL, 32'h00000001);
        polls = 0;
        read_data = 32'b0;
        while (!read_data[1] && polls < 100) begin
            bus_read(ADDR_STATUS, read_data);
            polls = polls + 1;
        end
        if (!read_data[1]) begin
            $error("FAIL: timed out waiting for second TinyNPU DONE");
            errors = errors + 1;
        end

        bus_write(ADDR_C_INDEX, 0);
        bus_read(ADDR_C_DATA, read_data);
        expect_value(read_data, 32'hFFFFFF80, "reused operands result C[0]");
        bus_write(ADDR_C_INDEX, 15);
        bus_read(ADDR_C_DATA, read_data);
        expect_value(read_data, 32'h0000007F, "reused operands result C[15]");

        if (errors == 0) begin
            $display("CPU-style TinyNPU bus computation PASSED.");
        end
        else begin
            $fatal(1, "CPU-style TinyNPU bus computation FAILED with %0d errors", errors);
        end

        $finish;
    end

endmodule
