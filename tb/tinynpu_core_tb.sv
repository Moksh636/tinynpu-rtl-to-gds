`timescale 1ns/1ps

module tinynpu_core_tb;

    logic clk;
    logic rst_n;

    logic load_en;
    logic load_sel;
    logic [3:0] load_addr;
    logic signed [7:0] load_data;

    logic start;

    logic [3:0] result_addr;
    logic signed [31:0] result_data;

    logic busy;
    logic done;

    logic signed [7:0]  A [0:15];
    logic signed [7:0]  B [0:15];
    logic signed [31:0] expected [0:15];

    int errors;
    integer ii;
    integer jj;
    integer kk;
    integer idx;

    tinynpu_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_en),
        .load_sel(load_sel),
        .load_addr(load_addr),
        .load_data(load_data),
        .start(start),
        .result_addr(result_addr),
        .result_data(result_data),
        .busy(busy),
        .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic load_value(
        input logic sel,
        input logic [3:0] addr,
        input logic signed [7:0] data
    );
        begin
            @(negedge clk);
            load_en   = 1'b1;
            load_sel  = sel;
            load_addr = addr;
            load_data = data;

            @(negedge clk);
            load_en   = 1'b0;
            load_sel  = 1'b0;
            load_addr = 4'd0;
            load_data = 8'sd0;
        end
    endtask

    task automatic compute_expected;
        begin
            for (ii = 0; ii < 4; ii = ii + 1) begin
                for (jj = 0; jj < 4; jj = jj + 1) begin
                    expected[(ii * 4) + jj] = 32'sd0;

                    for (kk = 0; kk < 4; kk = kk + 1) begin
                        expected[(ii * 4) + jj] =
                            expected[(ii * 4) + jj] +
                            ($signed(A[(ii * 4) + kk]) * $signed(B[(kk * 4) + jj]));
                    end
                end
            end
        end
    endtask

    task automatic check_results;
        begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                result_addr = idx[3:0];
                #1;

                if (result_data !== expected[idx]) begin
                    $display("FAIL: C[%0d] expected=%0d got=%0d",
                             idx, expected[idx], result_data);
                    errors++;
                end else begin
                    $display("PASS: C[%0d] = %0d", idx, result_data);
                end
            end
        end
    endtask

    initial begin
        $dumpfile("waves/tinynpu_core.vcd");
        $dumpvars(0, tinynpu_core_tb);

        errors = 0;

        load_en = 1'b0;
        load_sel = 1'b0;
        load_addr = 4'd0;
        load_data = 8'sd0;
        start = 1'b0;
        result_addr = 4'd0;

        A[0]  = 8'sd1;    A[1]  = 8'sd2;    A[2]  = 8'sd3;    A[3]  = 8'sd4;
        A[4]  = 8'sd5;    A[5]  = 8'sd6;    A[6]  = 8'sd7;    A[7]  = 8'sd8;
        A[8]  = -8'sd1;   A[9]  = -8'sd2;   A[10] = -8'sd3;   A[11] = -8'sd4;
        A[12] = 8'sd10;   A[13] = 8'sd0;    A[14] = -8'sd10;  A[15] = 8'sd2;

        B[0]  = 8'sd1;    B[1]  = 8'sd0;    B[2]  = 8'sd2;    B[3]  = -8'sd1;
        B[4]  = 8'sd0;    B[5]  = 8'sd1;    B[6]  = 8'sd3;    B[7]  = 8'sd2;
        B[8]  = 8'sd4;    B[9]  = -8'sd2;   B[10] = 8'sd0;    B[11] = 8'sd1;
        B[12] = -8'sd3;   B[13] = 8'sd5;    B[14] = 8'sd1;    B[15] = 8'sd0;

        compute_expected();

        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        $display("Loading matrix A...");
        for (idx = 0; idx < 16; idx = idx + 1) begin
            load_value(1'b0, idx[3:0], A[idx]);
        end

        $display("Loading matrix B...");
        for (idx = 0; idx < 16; idx = idx + 1) begin
            load_value(1'b1, idx[3:0], B[idx]);
        end

        $display("Starting TinyNPU core computation...");
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        wait(done == 1'b1);
        $display("TinyNPU core computation done.");

        check_results();

        if (errors == 0) begin
            $display("All TinyNPU core tests passed.");
        end else begin
            $display("TinyNPU core tests failed with %0d error(s).", errors);
        end

        $finish;
    end

endmodule
