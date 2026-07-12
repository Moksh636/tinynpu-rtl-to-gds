`timescale 1ns/1ps

module tinynpu_assertions #(
    parameter integer MAX_BUSY_CYCLES = 200
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic load_en,
    input logic busy,
    input logic done
);

    integer busy_age;
    integer assertion_checks;
    logic   busy_previous;

    initial begin
        busy_age        = 0;
        assertion_checks = 0;
        busy_previous   = 1'b0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            busy_age         <= 0;
            assertion_checks <= 0;
            busy_previous    <= 1'b0;
        end else begin
            /*
             * Busy and done represent mutually exclusive controller states.
             */
            assertion_checks <= assertion_checks + 1;
            assert (!(busy && done))
                else $fatal(1, "ASSERTION FAILED: busy and done asserted together");

            /*
             * The test environment must not load operands while computation
             * or result completion is active.
             */
            if (load_en) begin
                assertion_checks <= assertion_checks + 1;

                assert (!busy && !done && !start)
                    else $fatal(
                        1,
                        "ASSERTION FAILED: load attempted outside idle state"
                    );
            end

            /*
             * Start is legal only while the accelerator is idle.
             */
            if (start) begin
                assertion_checks <= assertion_checks + 1;

                assert (!busy && !done)
                    else $fatal(
                        1,
                        "ASSERTION FAILED: start asserted while accelerator active"
                    );
            end

            /*
             * Leaving busy must transition through done.
             */
            if (busy_previous && !busy) begin
                assertion_checks <= assertion_checks + 1;

                assert (done)
                    else $fatal(
                        1,
                        "ASSERTION FAILED: busy deasserted without done"
                    );
            end

            /*
             * Done must follow an active computation.
             */
            if (done) begin
                assertion_checks <= assertion_checks + 1;

                assert (busy_previous)
                    else $fatal(
                        1,
                        "ASSERTION FAILED: done asserted without prior busy"
                    );
            end

            /*
             * Hardware timeout protection.
             */
            if (busy) begin
                busy_age <= busy_age + 1;

                assertion_checks <= assertion_checks + 1;
                assert (busy_age < MAX_BUSY_CYCLES)
                    else $fatal(
                        1,
                        "ASSERTION FAILED: computation exceeded %0d cycles",
                        MAX_BUSY_CYCLES
                    );
            end else begin
                busy_age <= 0;
            end

            busy_previous <= busy;
        end
    end

endmodule
