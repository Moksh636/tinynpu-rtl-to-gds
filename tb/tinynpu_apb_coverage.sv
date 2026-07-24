`timescale 1ns/1ps

module tinynpu_apb_coverage #(
    /*
     * PROFILE 0: smoke-test goals
     * PROFILE 1: computation-test goals
     */
    parameter int PROFILE = 0
)(
    input logic        PCLK,
    input logic        PRESETn,

    input logic        PSEL,
    input logic        PENABLE,
    input logic        PWRITE,
    input logic [11:0] PADDR,
    input logic [31:0] PWDATA,

    input logic        PSLVERR,

    input logic        core_busy,
    input logic        core_done
);

    localparam logic [11:0] ADDR_CONTROL = 12'h000;
    localparam logic [11:0] ADDR_STATUS  = 12'h004;
    localparam logic [11:0] ADDR_CONFIG  = 12'h008;
    localparam logic [11:0] ADDR_A_DATA  = 12'h014;
    localparam logic [11:0] ADDR_B_DATA  = 12'h01C;
    localparam logic [11:0] ADDR_C_DATA  = 12'h024;

    integer apb_reads;
    integer apb_writes;
    integer valid_transfers;
    integer error_transfers;
    integer unaligned_transfers;

    integer status_reads;
    integer config_reads;
    integer a_data_writes;
    integer b_data_writes;
    integer c_data_reads;

    integer accepted_starts;
    integer rejected_starts;
    integer busy_cycles;
    integer done_events;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            apb_reads          = 0;
            apb_writes         = 0;
            valid_transfers    = 0;
            error_transfers    = 0;
            unaligned_transfers = 0;

            status_reads       = 0;
            config_reads       = 0;
            a_data_writes      = 0;
            b_data_writes      = 0;
            c_data_reads       = 0;

            accepted_starts    = 0;
            rejected_starts    = 0;
            busy_cycles        = 0;
            done_events        = 0;
        end
        else begin
            if (core_busy) begin
                busy_cycles = busy_cycles + 1;
            end

            if (core_done) begin
                done_events = done_events + 1;
            end

            if (PSEL && PENABLE) begin
                if (PWRITE) begin
                    apb_writes = apb_writes + 1;
                end
                else begin
                    apb_reads = apb_reads + 1;
                end

                if (PSLVERR) begin
                    error_transfers =
                        error_transfers + 1;
                end
                else begin
                    valid_transfers =
                        valid_transfers + 1;
                end

                if (PADDR[1:0] != 2'b00) begin
                    unaligned_transfers =
                        unaligned_transfers + 1;
                end

                if (!PWRITE &&
                    (PADDR == ADDR_STATUS)) begin
                    status_reads = status_reads + 1;
                end

                if (!PWRITE &&
                    (PADDR == ADDR_CONFIG)) begin
                    config_reads = config_reads + 1;
                end

                if (PWRITE &&
                    (PADDR == ADDR_A_DATA) &&
                    !PSLVERR) begin
                    a_data_writes = a_data_writes + 1;
                end

                if (PWRITE &&
                    (PADDR == ADDR_B_DATA) &&
                    !PSLVERR) begin
                    b_data_writes = b_data_writes + 1;
                end

                if (!PWRITE &&
                    (PADDR == ADDR_C_DATA) &&
                    !PSLVERR) begin
                    c_data_reads = c_data_reads + 1;
                end

                if (PWRITE &&
                    (PADDR == ADDR_CONTROL) &&
                    PWDATA[0]) begin

                    if (PSLVERR) begin
                        rejected_starts =
                            rejected_starts + 1;
                    end
                    else begin
                        accepted_starts =
                            accepted_starts + 1;
                    end
                end
            end
        end
    end

    task automatic coverage_failure(
        input string coverage_name,
        inout integer missing_goals
    );
        begin
            $error(
                "APB COVERAGE GOAL MISSED: %s",
                coverage_name
            );

            missing_goals = missing_goals + 1;
        end
    endtask

    task automatic check_coverage(
        inout integer test_errors
    );
        integer missing_goals;

        begin
            missing_goals = 0;

            $display("===== APB FUNCTIONAL COVERAGE =====");
            $display("APB reads:            %0d", apb_reads);
            $display("APB writes:           %0d", apb_writes);
            $display("Valid transfers:      %0d", valid_transfers);
            $display("Error transfers:      %0d", error_transfers);
            $display("Unaligned transfers:  %0d", unaligned_transfers);
            $display("STATUS reads:         %0d", status_reads);
            $display("CONFIG reads:         %0d", config_reads);
            $display("A_DATA writes:        %0d", a_data_writes);
            $display("B_DATA writes:        %0d", b_data_writes);
            $display("C_DATA reads:         %0d", c_data_reads);
            $display("Accepted STARTs:      %0d", accepted_starts);
            $display("Rejected STARTs:      %0d", rejected_starts);
            $display("BUSY cycles:          %0d", busy_cycles);
            $display("DONE events:          %0d", done_events);

            if (apb_reads == 0) begin
                coverage_failure(
                    "at least one APB read",
                    missing_goals
                );
            end

            if (apb_writes == 0) begin
                coverage_failure(
                    "at least one APB write",
                    missing_goals
                );
            end

            if (valid_transfers == 0) begin
                coverage_failure(
                    "at least one valid transfer",
                    missing_goals
                );
            end

            if (PROFILE == 0) begin
                /*
                 * Smoke-test coverage goals.
                 */
                if (error_transfers < 3) begin
                    coverage_failure(
                        "multiple rejected transfers",
                        missing_goals
                    );
                end

                if (unaligned_transfers < 1) begin
                    coverage_failure(
                        "unaligned transfer",
                        missing_goals
                    );
                end

                if (status_reads < 1) begin
                    coverage_failure(
                        "STATUS read",
                        missing_goals
                    );
                end

                if (config_reads < 1) begin
                    coverage_failure(
                        "CONFIG read",
                        missing_goals
                    );
                end

                if (a_data_writes < 1) begin
                    coverage_failure(
                        "A_DATA write",
                        missing_goals
                    );
                end

                if (b_data_writes < 1) begin
                    coverage_failure(
                        "B_DATA write",
                        missing_goals
                    );
                end

                if (rejected_starts < 1) begin
                    coverage_failure(
                        "rejected premature START",
                        missing_goals
                    );
                end
            end
            else begin
                /*
                 * Full-computation coverage goals.
                 */
                if (a_data_writes < 16) begin
                    coverage_failure(
                        "all 16 A elements written",
                        missing_goals
                    );
                end

                if (b_data_writes < 16) begin
                    coverage_failure(
                        "all 16 B elements written",
                        missing_goals
                    );
                end

                if (accepted_starts < 2) begin
                    coverage_failure(
                        "two accepted START commands",
                        missing_goals
                    );
                end

                if (error_transfers < 1) begin
                    coverage_failure(
                        "rejected transaction while BUSY",
                        missing_goals
                    );
                end

                if (busy_cycles < 1) begin
                    coverage_failure(
                        "BUSY state observed",
                        missing_goals
                    );
                end

                if (done_events < 2) begin
                    coverage_failure(
                        "two core completion events",
                        missing_goals
                    );
                end

                if (c_data_reads < 32) begin
                    coverage_failure(
                        "32 result reads across two runs",
                        missing_goals
                    );
                end
            end

            if (missing_goals == 0) begin
                $display(
                    "All APB functional coverage goals were reached."
                );
            end
            else begin
                test_errors =
                    test_errors + missing_goals;
            end
        end
    endtask

endmodule
