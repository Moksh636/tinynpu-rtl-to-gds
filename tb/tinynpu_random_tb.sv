`timescale 1ns/1ps

module tinynpu_random_tb;

    localparam int N            = 4;
    localparam int ELEMENTS     = N * N;
    localparam int DATA_WIDTH   = 8;
    localparam int ACC_WIDTH    = 32;
    localparam int ADDR_WIDTH   = 4;
    localparam int MAX_CYCLES   = 200;

    logic clk;
    logic rst_n;

    logic load_en;
    logic load_sel;
    logic [ADDR_WIDTH-1:0] load_addr;
    logic signed [DATA_WIDTH-1:0] load_data;

    logic start;

    logic [ADDR_WIDTH-1:0] result_addr;
    logic signed [ACC_WIDTH-1:0] result_data;

    logic busy;
    logic done;

    integer vector_file;
    integer scan_status;
    integer num_cases;
    integer case_idx;
    integer elem_idx;
    integer cycles;
    integer busy_seen;
    integer case_errors;
    integer total_errors;
    integer actual_value;

    integer matrix_a [0:ELEMENTS-1];
    integer matrix_b [0:ELEMENTS-1];
    integer expected [0:ELEMENTS-1];

    tinynpu_core #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
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

    task automatic load_operand(input logic select_b);
        integer index;
        begin
            for (index = 0; index < ELEMENTS; index = index + 1) begin
                @(negedge clk);

                load_en   = 1'b1;
                load_sel  = select_b;
                load_addr = index;

                if (select_b) begin
                    load_data = matrix_b[index];
                end else begin
                    load_data = matrix_a[index];
                end
            end

            @(negedge clk);
            load_en = 1'b0;
        end
    endtask

    task automatic start_computation;
        begin
            @(negedge clk);
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;
        end
    endtask

    task automatic wait_for_completion(input integer current_case);
        begin
            cycles    = 0;
            busy_seen = 0;

            while ((done !== 1'b1) && (cycles < MAX_CYCLES)) begin
                @(posedge clk);
                #1;

                cycles = cycles + 1;

                if (busy === 1'b1) begin
                    busy_seen = 1;
                end
            end

            if (done !== 1'b1) begin
                $fatal(
                    1,
                    "TIMEOUT: case %0d did not finish within %0d cycles",
                    current_case,
                    MAX_CYCLES
                );
            end

            if (busy_seen == 0) begin
                $fatal(
                    1,
                    "PROTOCOL ERROR: busy was never asserted in case %0d",
                    current_case
                );
            end
        end
    endtask

    task automatic check_results(input integer current_case);
        integer index;
        begin
            case_errors = 0;

            for (index = 0; index < ELEMENTS; index = index + 1) begin
                result_addr = index;
                #1;

                actual_value = $signed(result_data);

                if (actual_value !== expected[index]) begin
                    case_errors = case_errors + 1;
                    total_errors = total_errors + 1;

                    $display(
                        "FAIL: case=%0d C[%0d] expected=%0d actual=%0d",
                        current_case,
                        index,
                        expected[index],
                        actual_value
                    );
                end
            end

            if (case_errors == 0) begin
                $display(
                    "PASS: randomized vector case %0d completed in %0d cycles",
                    current_case,
                    cycles
                );
            end
        end
    endtask

    initial begin
        $dumpfile("waves/tinynpu_random.vcd");
        $dumpvars(0, tinynpu_random_tb);

        rst_n       = 1'b0;
        load_en     = 1'b0;
        load_sel    = 1'b0;
        load_addr   = '0;
        load_data   = '0;
        start       = 1'b0;
        result_addr = '0;
        total_errors = 0;

        repeat (3) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        vector_file = $fopen("sim/random_vectors.txt", "r");

        if (vector_file == 0) begin
            $fatal(1, "Could not open sim/random_vectors.txt");
        end

        scan_status = $fscanf(vector_file, "%d", num_cases);

        if (scan_status != 1 || num_cases <= 0) begin
            $fatal(1, "Invalid vector-file header");
        end

        $display("Starting %0d TinyNPU vector cases...", num_cases);

        for (case_idx = 0; case_idx < num_cases; case_idx = case_idx + 1) begin
            for (elem_idx = 0; elem_idx < ELEMENTS; elem_idx = elem_idx + 1) begin
                scan_status = $fscanf(
                    vector_file,
                    "%d",
                    matrix_a[elem_idx]
                );

                if (scan_status != 1) begin
                    $fatal(
                        1,
                        "Failed reading matrix A for case %0d",
                        case_idx
                    );
                end
            end

            for (elem_idx = 0; elem_idx < ELEMENTS; elem_idx = elem_idx + 1) begin
                scan_status = $fscanf(
                    vector_file,
                    "%d",
                    matrix_b[elem_idx]
                );

                if (scan_status != 1) begin
                    $fatal(
                        1,
                        "Failed reading matrix B for case %0d",
                        case_idx
                    );
                end
            end

            for (elem_idx = 0; elem_idx < ELEMENTS; elem_idx = elem_idx + 1) begin
                scan_status = $fscanf(
                    vector_file,
                    "%d",
                    expected[elem_idx]
                );

                if (scan_status != 1) begin
                    $fatal(
                        1,
                        "Failed reading expected matrix for case %0d",
                        case_idx
                    );
                end
            end

            load_operand(1'b0);
            load_operand(1'b1);

            start_computation();
            wait_for_completion(case_idx);
            check_results(case_idx);
        end

        $fclose(vector_file);

        if (total_errors != 0) begin
            $fatal(
                1,
                "Randomized verification failed with %0d mismatches",
                total_errors
            );
        end

        $display(
            "All %0d TinyNPU vector cases passed with 0 mismatches.",
            num_cases
        );

        $finish;
    end

endmodule
