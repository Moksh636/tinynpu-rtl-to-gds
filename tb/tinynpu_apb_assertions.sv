`timescale 1ns/1ps

module tinynpu_apb_assertions (
    input logic        PCLK,
    input logic        PRESETn,

    input logic        PSEL,
    input logic        PENABLE,
    input logic        PWRITE,
    input logic [11:0] PADDR,
    input logic [31:0] PWDATA,

    input logic        PREADY,
    input logic        PSLVERR,

    input logic        core_busy,
    input logic        core_done,
    input logic        core_start,
    input logic        core_load_en,

    input logic        operands_ready,
    input logic        done_sticky,
    input logic        error_sticky
);

    localparam logic [11:0] ADDR_CONTROL = 12'h000;
    localparam logic [11:0] ADDR_STATUS  = 12'h004;
    localparam logic [11:0] ADDR_CONFIG  = 12'h008;
    localparam logic [11:0] ADDR_A_DATA  = 12'h014;
    localparam logic [11:0] ADDR_B_DATA  = 12'h01C;
    localparam logic [11:0] ADDR_C_DATA  = 12'h024;

    integer assertion_failures;

    logic previous_core_done;
    logic previous_error_transfer;

    /*
     * Record one assertion failure without stopping immediately.
     *
     * This lets the full test continue and report every problem.
     */
    task automatic record_failure(
        input string message
    );
        begin
            $error("APB ASSERTION FAILURE: %s", message);
            assertion_failures = assertion_failures + 1;
        end
    endtask

    /*
     * Clocked protocol and behavioral checks.
     *
     * These are written as procedural assertions because this keeps
     * the checks compatible with Icarus Verilog as well as Verilator.
     */
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            assertion_failures    = 0;
            previous_core_done    <= 1'b0;
            previous_error_transfer <= 1'b0;
        end
        else begin
            /*
             * This wrapper promises zero wait states.
             */
            if (PREADY !== 1'b1) begin
                record_failure(
                    "PREADY must remain asserted"
                );
            end

            if (PSEL && PENABLE) begin
                /*
                 * Every unaligned APB transfer must be rejected.
                 */
                if ((PADDR[1:0] != 2'b00) &&
                    (PSLVERR !== 1'b1)) begin
                    record_failure(
                        "unaligned transfer did not assert PSLVERR"
                    );
                end

                /*
                 * Writes to read-only registers must fail.
                 */
                if (PWRITE &&
                    (
                        (PADDR == ADDR_STATUS) ||
                        (PADDR == ADDR_CONFIG) ||
                        (PADDR == ADDR_C_DATA)
                    ) &&
                    (PSLVERR !== 1'b1)) begin
                    record_failure(
                        "write to read-only register was accepted"
                    );
                end

                /*
                 * Operand memories must not change while computing.
                 */
                if (PWRITE &&
                    core_busy &&
                    (
                        (PADDR == ADDR_A_DATA) ||
                        (PADDR == ADDR_B_DATA)
                    ) &&
                    (PSLVERR !== 1'b1)) begin
                    record_failure(
                        "operand write while BUSY was accepted"
                    );
                end

                /*
                 * START is legal only with complete operands and an
                 * idle compute core.
                 */
                if (PWRITE &&
                    (PADDR == ADDR_CONTROL) &&
                    PWDATA[0] &&
                    (!operands_ready || core_busy) &&
                    (PSLVERR !== 1'b1)) begin
                    record_failure(
                        "illegal START did not assert PSLVERR"
                    );
                end
            end

            /*
             * Every generated core START pulse must come from a valid
             * APB CONTROL.START transaction.
             */
            if (core_start &&
                !(
                    PSEL &&
                    PENABLE &&
                    PWRITE &&
                    (PADDR == ADDR_CONTROL) &&
                    PWDATA[0] &&
                    !PSLVERR
                )) begin
                record_failure(
                    "core_start was not caused by a valid APB START"
                );
            end

            /*
             * Every core operand-load pulse must come from a valid
             * A_DATA or B_DATA write.
             */
            if (core_load_en &&
                !(
                    PSEL &&
                    PENABLE &&
                    PWRITE &&
                    (
                        (PADDR == ADDR_A_DATA) ||
                        (PADDR == ADDR_B_DATA)
                    ) &&
                    !PSLVERR
                )) begin
                record_failure(
                    "core_load_en was not caused by a valid operand write"
                );
            end

            /*
             * A core completion must become visible through the
             * sticky DONE status by the following clock.
             */
            if (previous_core_done &&
                (done_sticky !== 1'b1)) begin
                record_failure(
                    "core_done did not set DONE_STICKY"
                );
            end

            /*
             * A rejected APB transfer must set sticky ERROR by the
             * following clock.
             */
            if (previous_error_transfer &&
                (error_sticky !== 1'b1)) begin
                record_failure(
                    "PSLVERR did not set ERROR_STICKY"
                );
            end

            previous_core_done <= core_done;

            previous_error_transfer <=
                PSEL &&
                PENABLE &&
                PSLVERR;
        end
    end

    task automatic check_assertions(
        inout integer test_errors
    );
        begin
            if (assertion_failures == 0) begin
                $display(
                    "All TinyNPU APB assertions passed."
                );
            end
            else begin
                $error(
                    "%0d TinyNPU APB assertions failed.",
                    assertion_failures
                );

                test_errors =
                    test_errors + assertion_failures;
            end
        end
    endtask

endmodule
