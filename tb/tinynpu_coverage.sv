`timescale 1ns/1ps

module tinynpu_coverage #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 32
)(
    input logic clk,
    input logic rst_n,

    input logic load_en,
    input logic signed [DATA_WIDTH-1:0] load_data,

    input logic busy,
    input logic done,

    input logic result_sample,
    input logic signed [ACC_WIDTH-1:0] result_data
);

    localparam integer INT_MIN = -(1 << (DATA_WIDTH - 1));
    localparam integer INT_MAX =  (1 << (DATA_WIDTH - 1)) - 1;

    integer load_count;
    integer input_zero_count;
    integer input_positive_count;
    integer input_negative_count;
    integer input_min_count;
    integer input_max_count;

    integer busy_cycle_count;
    integer done_count;

    integer result_sample_count;
    integer output_zero_count;
    integer output_positive_count;
    integer output_negative_count;

    initial begin
        load_count            = 0;
        input_zero_count      = 0;
        input_positive_count  = 0;
        input_negative_count  = 0;
        input_min_count       = 0;
        input_max_count       = 0;

        busy_cycle_count      = 0;
        done_count            = 0;

        result_sample_count   = 0;
        output_zero_count     = 0;
        output_positive_count = 0;
        output_negative_count = 0;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            if (load_en) begin
                load_count = load_count + 1;

                if ($signed(load_data) == 0) begin
                    input_zero_count = input_zero_count + 1;
                end else if ($signed(load_data) < 0) begin
                    input_negative_count = input_negative_count + 1;
                end else begin
                    input_positive_count = input_positive_count + 1;
                end

                if ($signed(load_data) == INT_MIN) begin
                    input_min_count = input_min_count + 1;
                end

                if ($signed(load_data) == INT_MAX) begin
                    input_max_count = input_max_count + 1;
                end
            end

            if (busy) begin
                busy_cycle_count = busy_cycle_count + 1;
            end

            if (done) begin
                done_count = done_count + 1;
            end
        end
    end

    always @(posedge result_sample) begin
        if (rst_n) begin
            result_sample_count = result_sample_count + 1;

            if ($signed(result_data) == 0) begin
                output_zero_count = output_zero_count + 1;
            end else if ($signed(result_data) < 0) begin
                output_negative_count = output_negative_count + 1;
            end else begin
                output_positive_count = output_positive_count + 1;
            end
        end
    end

    task automatic report_and_check(input integer expected_cases);
        integer expected_loads;
        integer expected_results;

        begin
            expected_loads   = expected_cases * 32;
            expected_results = expected_cases * 16;

            $display("");
            $display("========== FUNCTIONAL COVERAGE ==========");
            $display("Matrix cases:             %0d", expected_cases);
            $display("Operand loads:            %0d", load_count);
            $display("Positive input values:    %0d", input_positive_count);
            $display("Negative input values:    %0d", input_negative_count);
            $display("Zero input values:        %0d", input_zero_count);
            $display("INT8 minimum values:      %0d", input_min_count);
            $display("INT8 maximum values:      %0d", input_max_count);
            $display("Busy cycles:              %0d", busy_cycle_count);
            $display("Done events:              %0d", done_count);
            $display("Results sampled:          %0d", result_sample_count);
            $display("Positive output values:   %0d", output_positive_count);
            $display("Negative output values:   %0d", output_negative_count);
            $display("Zero output values:       %0d", output_zero_count);
            $display("=========================================");

            if (load_count != expected_loads) begin
                $fatal(
                    1,
                    "COVERAGE FAILURE: expected %0d loads, observed %0d",
                    expected_loads,
                    load_count
                );
            end

            if (done_count != expected_cases) begin
                $fatal(
                    1,
                    "COVERAGE FAILURE: expected %0d done events, observed %0d",
                    expected_cases,
                    done_count
                );
            end

            if (result_sample_count != expected_results) begin
                $fatal(
                    1,
                    "COVERAGE FAILURE: expected %0d result samples, observed %0d",
                    expected_results,
                    result_sample_count
                );
            end

            if (
                input_positive_count == 0 ||
                input_negative_count == 0 ||
                input_zero_count == 0 ||
                input_min_count == 0 ||
                input_max_count == 0
            ) begin
                $fatal(1, "COVERAGE FAILURE: an input-value coverage goal was missed");
            end

            if (
                output_positive_count == 0 ||
                output_negative_count == 0 ||
                output_zero_count == 0
            ) begin
                $fatal(1, "COVERAGE FAILURE: an output-sign coverage goal was missed");
            end

            $display("All functional coverage goals were reached.");
        end
    endtask

endmodule
