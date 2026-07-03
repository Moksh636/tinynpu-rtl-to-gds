`timescale 1ns/1ps

module mac_unit_tb;

    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic signed [31:0] acc_in;
    logic signed [31:0] acc_out;

    int errors;

    mac_unit dut (
        .a(a),
        .b(b),
        .acc_in(acc_in),
        .acc_out(acc_out)
    );

    task automatic run_test(
        input logic signed [7:0]  test_a,
        input logic signed [7:0]  test_b,
        input logic signed [31:0] test_acc
    );
        logic signed [31:0] expected;
        begin
            a = test_a;
            b = test_b;
            acc_in = test_acc;
            expected = test_acc + (test_a * test_b);

            #1;

            if (acc_out !== expected) begin
                $display("FAIL: a=%0d b=%0d acc_in=%0d expected=%0d got=%0d",
                         test_a, test_b, test_acc, expected, acc_out);
                errors++;
            end else begin
                $display("PASS: a=%0d b=%0d acc_in=%0d acc_out=%0d",
                         test_a, test_b, test_acc, acc_out);
            end
        end
    endtask

    initial begin
        $dumpfile("waves/mac_unit.vcd");
        $dumpvars(0, mac_unit_tb);

        errors = 0;

        $display("Starting MAC unit tests...");

        run_test(8'sd3,    8'sd4,    32'sd0);
        run_test(-8'sd3,   8'sd4,    32'sd0);
        run_test(8'sd3,   -8'sd4,    32'sd0);
        run_test(-8'sd3,  -8'sd4,    32'sd0);
        run_test(8'sd127,  8'sd2,    32'sd0);
        run_test(-8'sd128, 8'sd1,    32'sd0);
        run_test(8'sd10,   8'sd10,   32'sd50);
        run_test(-8'sd10,  8'sd10,   32'sd50);
        run_test(8'sd0,    8'sd100,  32'sd1234);
        run_test(-8'sd8,  -8'sd7,    -32'sd20);

        if (errors == 0) begin
            $display("All MAC unit tests passed.");
        end else begin
            $display("MAC unit tests failed with %0d error(s).", errors);
        end

        $finish;
    end

endmodule
