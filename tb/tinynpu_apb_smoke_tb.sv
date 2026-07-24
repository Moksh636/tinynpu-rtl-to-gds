`timescale 1ns/1ps

module tinynpu_apb_smoke_tb;

    localparam logic [11:0] ADDR_CONTROL = 12'h000;
    localparam logic [11:0] ADDR_STATUS  = 12'h004;
    localparam logic [11:0] ADDR_CONFIG  = 12'h008;

    localparam logic [11:0] ADDR_A_INDEX = 12'h010;
    localparam logic [11:0] ADDR_A_DATA  = 12'h014;
    localparam logic [11:0] ADDR_B_INDEX = 12'h018;
    localparam logic [11:0] ADDR_B_DATA  = 12'h01C;
    localparam logic [11:0] ADDR_C_INDEX = 12'h020;

    logic        PCLK;
    logic        PRESETn;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [11:0] PADDR;
    logic [31:0] PWDATA;

    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    integer errors;

    tinynpu_apb dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),

        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    /*
     * Reusable APB behavior checker.
     *
     * Internal wrapper signals are connected hierarchically so the
     * checker does not alter the synthesizable module interface.
     */
    tinynpu_apb_assertions u_apb_assertions (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),

        .PREADY(PREADY),
        .PSLVERR(PSLVERR),

        .core_busy(dut.core_busy),
        .core_done(dut.core_done),
        .core_start(dut.core_start),
        .core_load_en(dut.core_load_en),

        .operands_ready(dut.operands_ready),
        .done_sticky(dut.done_sticky),
        .error_sticky(dut.error_sticky)
    );

    tinynpu_apb_coverage #(
        .PROFILE(0)
    ) u_apb_coverage (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),

        .PSLVERR(PSLVERR),

        .core_busy(dut.core_busy),
        .core_done(dut.core_done)
    );

    /*
     * 100 MHz test clock:
     * 10 ns period, 5 ns per half-cycle.
     */
    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    /*
     * Perform one APB write.
     *
     * APB setup phase:
     *   PSEL = 1, PENABLE = 0
     *
     * APB access phase:
     *   PSEL = 1, PENABLE = 1
     */
    task automatic apb_write(
        input  logic [11:0] address,
        input  logic [31:0] data,
        output logic        error
    );
        begin
            @(negedge PCLK);
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b1;
            PADDR   = address;
            PWDATA  = data;

            @(negedge PCLK);
            PENABLE = 1'b1;

            /*
             * Sample the zero-wait-state APB response during the
             * access phase, before the accepting rising edge.
             */
            #1;
            error = PSLVERR;

            /*
             * The DUT accepts the transaction on this rising edge.
             */
            @(posedge PCLK);

            @(negedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = '0;
            PWDATA  = '0;
        end
    endtask

    /*
     * Perform one APB read.
     */
    task automatic apb_read(
        input  logic [11:0] address,
        output logic [31:0] data,
        output logic        error
    );
        begin
            @(negedge PCLK);
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = address;
            PWDATA  = '0;

            @(negedge PCLK);
            PENABLE = 1'b1;

            /*
             * PRDATA and PSLVERR are combinational zero-wait-state
             * responses, so sample them during the access phase.
             */
            #1;
            data  = PRDATA;
            error = PSLVERR;

            @(posedge PCLK);

            @(negedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PADDR   = '0;
        end
    endtask

    task automatic expect_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       test_name
    );
        begin
            if (actual !== expected) begin
                $error(
                    "FAIL: %s expected 0x%08h, received 0x%08h",
                    test_name,
                    expected,
                    actual
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: %s = 0x%08h",
                    test_name,
                    actual
                );
            end
        end
    endtask

    task automatic expect_error(
        input logic  actual,
        input logic  expected,
        input string test_name
    );
        begin
            if (actual !== expected) begin
                $error(
                    "FAIL: %s expected PSLVERR=%0b, received %0b",
                    test_name,
                    expected,
                    actual
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: %s PSLVERR=%0b",
                    test_name,
                    actual
                );
            end
        end
    endtask

    logic [31:0] read_data;
    logic        transfer_error;

    initial begin
        $dumpfile("waves/tinynpu_apb_smoke.vcd");
        $dumpvars(0, tinynpu_apb_smoke_tb);

        errors = 0;

        PRESETn = 1'b0;
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PADDR   = '0;
        PWDATA  = '0;

        /*
         * Hold reset active for several clock edges.
         */
        repeat (3) @(posedge PCLK);

        @(negedge PCLK);
        PRESETn = 1'b1;

        repeat (2) @(posedge PCLK);

        $display("Starting TinyNPU APB smoke tests...");

        /*
         * Reset status must be completely clear.
         */
        apb_read(ADDR_STATUS, read_data, transfer_error);
        expect_error(transfer_error, 1'b0, "STATUS read");
        expect_value(read_data, 32'h00000000, "reset STATUS");

        /*
         * CONFIG packs:
         *
         * [31:24] element count     = 16 = 0x10
         * [23:16] accumulator width = 32 = 0x20
         * [15:8]  input width       = 8  = 0x08
         * [7:0]   dimension         = 4  = 0x04
         */
        apb_read(ADDR_CONFIG, read_data, transfer_error);
        expect_error(transfer_error, 1'b0, "CONFIG read");
        expect_value(read_data, 32'h10200804, "CONFIG");

        /*
         * 0x00C is undefined.
         */
        apb_read(12'h00C, read_data, transfer_error);
        expect_error(
            transfer_error,
            1'b1,
            "undefined-address read"
        );

        /*
         * The invalid transaction must set ERROR_STICKY.
         */
        apb_read(ADDR_STATUS, read_data, transfer_error);
        expect_value(
            read_data & 32'h00000004,
            32'h00000004,
            "ERROR_STICKY after invalid address"
        );

        /*
         * CONTROL bit 2 clears ERROR_STICKY.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000004,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b0,
            "CLEAR_ERROR"
        );

        apb_read(ADDR_STATUS, read_data, transfer_error);
        expect_value(
            read_data & 32'h00000004,
            32'h00000000,
            "ERROR_STICKY cleared"
        );

        /*
         * 0x005 is not 32-bit aligned.
         */
        apb_read(12'h005, read_data, transfer_error);
        expect_error(
            transfer_error,
            1'b1,
            "unaligned read"
        );

        /*
         * Clear the second error.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000004,
            transfer_error
        );

        /*
         * Test matrix A index register.
         */
        apb_write(
            ADDR_A_INDEX,
            32'd3,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b0,
            "A_INDEX write"
        );

        apb_read(
            ADDR_A_INDEX,
            read_data,
            transfer_error
        );
        expect_value(
            read_data,
            32'd3,
            "A_INDEX readback"
        );

        /*
         * Write signed INT8 -3:
         *
         * -3 in eight-bit two's complement = 0xFD.
         */
        apb_write(
            ADDR_A_DATA,
            32'h000000FD,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b0,
            "A_DATA write"
        );

        apb_read(
            ADDR_A_DATA,
            read_data,
            transfer_error
        );
        expect_value(
            read_data,
            32'hFFFFFFFD,
            "signed A_DATA readback"
        );

        /*
         * Test matrix B using the INT8 minimum value -128.
         */
        apb_write(
            ADDR_B_INDEX,
            32'd7,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b0,
            "B_INDEX write"
        );

        apb_write(
            ADDR_B_DATA,
            32'h00000080,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b0,
            "B_DATA write"
        );

        apb_read(
            ADDR_B_DATA,
            read_data,
            transfer_error
        );
        expect_value(
            read_data,
            32'hFFFFFF80,
            "signed B_DATA readback"
        );

        /*
         * Only one A and one B entry are loaded, so operands cannot
         * yet be ready.
         */
        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );
        expect_value(
            read_data & 32'h00000008,
            32'h00000000,
            "OPERANDS_READY with incomplete matrices"
        );

        /*
         * START must fail because the matrices are incomplete.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000001,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b1,
            "premature START"
        );

        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );
        expect_value(
            read_data & 32'h00000004,
            32'h00000004,
            "ERROR_STICKY after premature START"
        );

        /*
         * C_INDEX itself is currently writable and readable even
         * before a computation has occurred.
         */
        apb_write(
            ADDR_C_INDEX,
            32'd15,
            transfer_error
        );
        expect_error(
            transfer_error,
            1'b0,
            "C_INDEX write"
        );

        apb_read(
            ADDR_C_INDEX,
            read_data,
            transfer_error
        );
        expect_value(
            read_data,
            32'd15,
            "C_INDEX readback"
        );

        u_apb_assertions.check_assertions(errors);
        u_apb_coverage.check_coverage(errors);

        if (errors == 0) begin
            $display(
                "All TinyNPU APB smoke tests passed with 0 errors."
            );
        end
        else begin
            $fatal(
                1,
                "TinyNPU APB smoke tests failed with %0d errors.",
                errors
            );
        end

        $finish;
    end

endmodule
