`timescale 1ns/1ps

module tinynpu_apb_compute_tb;

    localparam logic [11:0] ADDR_CONTROL = 12'h000;
    localparam logic [11:0] ADDR_STATUS  = 12'h004;

    localparam logic [11:0] ADDR_A_INDEX = 12'h010;
    localparam logic [11:0] ADDR_A_DATA  = 12'h014;
    localparam logic [11:0] ADDR_B_INDEX = 12'h018;
    localparam logic [11:0] ADDR_B_DATA  = 12'h01C;
    localparam logic [11:0] ADDR_C_INDEX = 12'h020;
    localparam logic [11:0] ADDR_C_DATA  = 12'h024;

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

    logic signed [7:0]  matrix_a [0:15];
    logic signed [7:0]  matrix_b [0:15];
    logic signed [31:0] expected [0:15];

    logic [31:0] read_data;
    logic        transfer_error;

    integer errors;
    integer row;
    integer column;
    integer inner;
    integer index;
    integer poll_count;
    integer busy_seen;

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
        .PROFILE(1)
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
     * 100 MHz clock.
     */
    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    task automatic apb_write(
        input  logic [11:0] address,
        input  logic [31:0] data,
        output logic        error
    );
        begin
            /*
             * Setup phase.
             */
            @(negedge PCLK);
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b1;
            PADDR   = address;
            PWDATA  = data;

            /*
             * Access phase.
             */
            @(negedge PCLK);
            PENABLE = 1'b1;

            /*
             * Sample the APB response before sequential DUT state
             * changes at the accepting rising edge.
             */
            #1;
            error = PSLVERR;

            @(posedge PCLK);

            /*
             * Return bus to idle.
             */
            @(negedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = '0;
            PWDATA  = '0;
        end
    endtask

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

    task automatic check_error(
        input logic  actual,
        input logic  expected_error,
        input string test_name
    );
        begin
            if (actual !== expected_error) begin
                $error(
                    "FAIL: %s expected PSLVERR=%0b, got %0b",
                    test_name,
                    expected_error,
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

    task automatic check_value(
        input logic [31:0] actual,
        input logic [31:0] expected_value,
        input string       test_name
    );
        begin
            if (actual !== expected_value) begin
                $error(
                    "FAIL: %s expected 0x%08h (%0d), got 0x%08h (%0d)",
                    test_name,
                    expected_value,
                    $signed(expected_value),
                    actual,
                    $signed(actual)
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: %s = %0d",
                    test_name,
                    $signed(actual)
                );
            end
        end
    endtask

    /*
     * Calculate the expected matrix in the testbench.
     *
     * C[row][column] =
     *     sum(A[row][inner] * B[inner][column])
     */
    task automatic calculate_expected;
        begin
            for (row = 0; row < 4; row = row + 1) begin
                for (column = 0;
                     column < 4;
                     column = column + 1) begin

                    expected[(row * 4) + column] = 32'sd0;

                    for (inner = 0;
                         inner < 4;
                         inner = inner + 1) begin

                        expected[(row * 4) + column] =
                            expected[(row * 4) + column] +
                            (
                                $signed(
                                    matrix_a[(row * 4) + inner]
                                )
                                *
                                $signed(
                                    matrix_b[(inner * 4) + column]
                                )
                            );
                    end
                end
            end
        end
    endtask

    task automatic load_matrix_a;
        begin
            $display("Loading matrix A through APB...");

            for (index = 0; index < 16; index = index + 1) begin
                apb_write(
                    ADDR_A_INDEX,
                    index,
                    transfer_error
                );

                if (transfer_error) begin
                    $error(
                        "FAIL: A_INDEX write failed at index %0d",
                        index
                    );
                    errors = errors + 1;
                end

                apb_write(
                    ADDR_A_DATA,
                    {
                        {24{matrix_a[index][7]}},
                        matrix_a[index]
                    },
                    transfer_error
                );

                if (transfer_error) begin
                    $error(
                        "FAIL: A_DATA write failed at index %0d",
                        index
                    );
                    errors = errors + 1;
                end
            end
        end
    endtask

    task automatic load_matrix_b;
        begin
            $display("Loading matrix B through APB...");

            for (index = 0; index < 16; index = index + 1) begin
                apb_write(
                    ADDR_B_INDEX,
                    index,
                    transfer_error
                );

                if (transfer_error) begin
                    $error(
                        "FAIL: B_INDEX write failed at index %0d",
                        index
                    );
                    errors = errors + 1;
                end

                apb_write(
                    ADDR_B_DATA,
                    {
                        {24{matrix_b[index][7]}},
                        matrix_b[index]
                    },
                    transfer_error
                );

                if (transfer_error) begin
                    $error(
                        "FAIL: B_DATA write failed at index %0d",
                        index
                    );
                    errors = errors + 1;
                end
            end
        end
    endtask

    task automatic check_all_results;
        string result_name;

        begin
            $display("Reading result matrix C through APB...");

            for (index = 0; index < 16; index = index + 1) begin
                apb_write(
                    ADDR_C_INDEX,
                    index,
                    transfer_error
                );

                if (transfer_error) begin
                    $error(
                        "FAIL: C_INDEX write failed at index %0d",
                        index
                    );
                    errors = errors + 1;
                end

                apb_read(
                    ADDR_C_DATA,
                    read_data,
                    transfer_error
                );

                if (transfer_error) begin
                    $error(
                        "FAIL: C_DATA read failed at index %0d",
                        index
                    );
                    errors = errors + 1;
                end

                result_name = $sformatf("C[%0d]", index);

                check_value(
                    read_data,
                    expected[index],
                    result_name
                );
            end
        end
    endtask

    initial begin
        $dumpfile("waves/tinynpu_apb_compute.vcd");
        $dumpvars(0, tinynpu_apb_compute_tb);

        errors    = 0;
        busy_seen = 0;

        PRESETn = 1'b0;
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PADDR   = '0;
        PWDATA  = '0;

        /*
         * Same directed matrices used by the direct core test.
         */
        matrix_a[0]  = 8'sd1;
        matrix_a[1]  = 8'sd2;
        matrix_a[2]  = 8'sd3;
        matrix_a[3]  = 8'sd4;

        matrix_a[4]  = 8'sd5;
        matrix_a[5]  = 8'sd6;
        matrix_a[6]  = 8'sd7;
        matrix_a[7]  = 8'sd8;

        matrix_a[8]  = -8'sd1;
        matrix_a[9]  = -8'sd2;
        matrix_a[10] = -8'sd3;
        matrix_a[11] = -8'sd4;

        matrix_a[12] = 8'sd10;
        matrix_a[13] = 8'sd0;
        matrix_a[14] = -8'sd10;
        matrix_a[15] = 8'sd2;

        matrix_b[0]  = 8'sd1;
        matrix_b[1]  = 8'sd0;
        matrix_b[2]  = 8'sd2;
        matrix_b[3]  = -8'sd1;

        matrix_b[4]  = 8'sd0;
        matrix_b[5]  = 8'sd1;
        matrix_b[6]  = 8'sd3;
        matrix_b[7]  = 8'sd2;

        matrix_b[8]  = 8'sd4;
        matrix_b[9]  = -8'sd2;
        matrix_b[10] = 8'sd0;
        matrix_b[11] = 8'sd1;

        matrix_b[12] = -8'sd3;
        matrix_b[13] = 8'sd5;
        matrix_b[14] = 8'sd1;
        matrix_b[15] = 8'sd0;

        calculate_expected();

        /*
         * Reset the APB wrapper and compute core.
         */
        repeat (3) @(posedge PCLK);

        @(negedge PCLK);
        PRESETn = 1'b1;

        repeat (2) @(posedge PCLK);

        $display(
            "Starting full TinyNPU APB computation test..."
        );

        load_matrix_a();
        load_matrix_b();

        /*
         * All 32 operand elements have now been written.
         */
        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b0,
            "STATUS after operand loading"
        );

        check_value(
            read_data & 32'h00000008,
            32'h00000008,
            "OPERANDS_READY"
        );

        /*
         * Start the matrix multiplication.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000001,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b0,
            "valid START"
        );

        /*
         * BUSY should be visible while the core computes.
         */
        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        if (read_data[0]) begin
            busy_seen = 1;
            $display("PASS: BUSY observed during computation");
        end
        else begin
            $error("FAIL: BUSY was not observed after START");
            errors = errors + 1;
        end

        /*
         * Attempting to alter A while computing must fail.
         */
        apb_write(
            ADDR_A_DATA,
            32'h00000055,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b1,
            "A_DATA write while BUSY"
        );

        /*
         * The rejected write must set ERROR_STICKY.
         */
        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_value(
            read_data & 32'h00000004,
            32'h00000004,
            "ERROR_STICKY after BUSY write"
        );

        /*
         * Clear the test-generated error without stopping the core.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000004,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b0,
            "CLEAR_ERROR while computing"
        );

        /*
         * Poll until DONE_STICKY is visible.
         */
        poll_count = 0;

        while ((poll_count < 100) && !read_data[1]) begin
            apb_read(
                ADDR_STATUS,
                read_data,
                transfer_error
            );

            if (read_data[0]) begin
                busy_seen = 1;
            end

            poll_count = poll_count + 1;
        end

        if (!read_data[1]) begin
            $error(
                "FAIL: computation timeout after %0d polls",
                poll_count
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: DONE_STICKY observed after %0d polls",
                poll_count
            );
        end

        if (!busy_seen) begin
            $error("FAIL: BUSY was never observed");
            errors = errors + 1;
        end

        /*
         * Final status:
         *
         * BUSY           = 0
         * DONE_STICKY    = 1
         * ERROR_STICKY   = 0
         * OPERANDS_READY = 1
         */
        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_value(
            read_data & 32'h0000000F,
            32'h0000000A,
            "final STATUS"
        );

        check_all_results();

        /*
         * Clear sticky completion.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000002,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b0,
            "CLEAR_DONE"
        );

        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_value(
            read_data & 32'h00000002,
            32'h00000000,
            "DONE_STICKY cleared"
        );

        /*
         * Start a second computation without rewriting either operand
         * matrix. The loaded masks and core operand memories must remain
         * valid after the first computation.
         */
        $display(
            "Starting second computation without reloading operands..."
        );

        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_value(
            read_data & 32'h00000008,
            32'h00000008,
            "OPERANDS_READY before second computation"
        );

        apb_write(
            ADDR_CONTROL,
            32'h00000001,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b0,
            "second START without operand reload"
        );

        /*
         * Confirm BUSY becomes visible again.
         */
        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_value(
            read_data & 32'h00000001,
            32'h00000001,
            "BUSY during second computation"
        );

        /*
         * Poll for the second sticky completion event.
         */
        poll_count = 0;
        read_data  = 32'b0;

        while ((poll_count < 100) && !read_data[1]) begin
            apb_read(
                ADDR_STATUS,
                read_data,
                transfer_error
            );

            if (transfer_error) begin
                $error(
                    "FAIL: STATUS read failed during second computation"
                );
                errors = errors + 1;
            end

            poll_count = poll_count + 1;
        end

        if (!read_data[1]) begin
            $error(
                "FAIL: second computation timeout after %0d polls",
                poll_count
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: second DONE_STICKY observed after %0d polls",
                poll_count
            );
        end

        /*
         * The same inputs must produce the same 16 outputs.
         */
        check_all_results();

        /*
         * Clear second completion event and confirm that operand
         * readiness remains asserted.
         */
        apb_write(
            ADDR_CONTROL,
            32'h00000002,
            transfer_error
        );

        check_error(
            transfer_error,
            1'b0,
            "second CLEAR_DONE"
        );

        apb_read(
            ADDR_STATUS,
            read_data,
            transfer_error
        );

        check_value(
            read_data & 32'h0000000A,
            32'h00000008,
            "final reusable-operand STATUS"
        );

        u_apb_assertions.check_assertions(errors);
        u_apb_coverage.check_coverage(errors);

        if (errors == 0) begin
            $display(
                "All TinyNPU APB computation tests passed with 0 errors."
            );
        end
        else begin
            $fatal(
                1,
                "TinyNPU APB computation test failed with %0d errors.",
                errors
            );
        end

        $finish;
    end

endmodule
