`timescale 1ns/1ps

module tinynpu_core #(
    parameter int N          = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ADDR_WIDTH = ((N*N) > 1) ? $clog2(N*N) : 1
)(
    input  logic clk,
    input  logic rst_n,

    input  logic load_en,
    input  logic load_sel,
    input  logic [ADDR_WIDTH-1:0] load_addr,
    input  logic signed [DATA_WIDTH-1:0] load_data,

    input  logic start,

    input  logic [ADDR_WIDTH-1:0] result_addr,
    output logic signed [ACC_WIDTH-1:0] result_data,

    output logic busy,
    output logic done
);

    localparam int MEM_DEPTH   = N * N;
    localparam int COUNT_WIDTH = (N > 1) ? $clog2(N) : 1;

    localparam logic [COUNT_WIDTH-1:0] LAST_INDEX =
        COUNT_WIDTH'(N - 1);

    typedef enum logic [1:0] {
        S_IDLE,
        S_COMPUTE,
        S_DONE
    } state_t;

    state_t state;

    logic signed [DATA_WIDTH-1:0] a_mem [0:MEM_DEPTH-1];
    logic signed [DATA_WIDTH-1:0] b_mem [0:MEM_DEPTH-1];
    logic signed [ACC_WIDTH-1:0]  c_mem [0:MEM_DEPTH-1];

    logic [COUNT_WIDTH-1:0] i;
    logic [COUNT_WIDTH-1:0] j;
    logic [COUNT_WIDTH-1:0] k;

    logic signed [ACC_WIDTH-1:0] acc;
    logic signed [ACC_WIDTH-1:0] mac_out;

    logic [ADDR_WIDTH-1:0] i_extended;
    logic [ADDR_WIDTH-1:0] j_extended;
    logic [ADDR_WIDTH-1:0] k_extended;

    logic [ADDR_WIDTH-1:0] a_index;
    logic [ADDR_WIDTH-1:0] b_index;
    logic [ADDR_WIDTH-1:0] c_index;

    always_comb begin
        i_extended = {{(ADDR_WIDTH-COUNT_WIDTH){1'b0}}, i};
        j_extended = {{(ADDR_WIDTH-COUNT_WIDTH){1'b0}}, j};
        k_extended = {{(ADDR_WIDTH-COUNT_WIDTH){1'b0}}, k};

        a_index = (i_extended * ADDR_WIDTH'(N)) + k_extended;
        b_index = (k_extended * ADDR_WIDTH'(N)) + j_extended;
        c_index = (i_extended * ADDR_WIDTH'(N)) + j_extended;
    end

    mac_unit #(
        .A_WIDTH(DATA_WIDTH),
        .B_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_mac (
        .a(a_mem[a_index]),
        .b(b_mem[b_index]),
        .acc_in(acc),
        .acc_out(mac_out)
    );

    assign result_data = c_mem[result_addr];
    assign busy = (state == S_COMPUTE);
    assign done = (state == S_DONE);

    /*
     * Matrix memories intentionally have no reset.
     *
     * Software or the testbench loads every A and B element before starting
     * computation. Every C element is written before its result is consumed.
     * Avoiding memory reset also improves FPGA memory inference.
     */
    always_ff @(posedge clk) begin
        if ((state == S_IDLE) && load_en) begin
            if (load_sel == 1'b0) begin
                a_mem[load_addr] <= load_data;
            end else begin
                b_mem[load_addr] <= load_data;
            end
        end

        if ((state == S_COMPUTE) && (k == LAST_INDEX)) begin
            c_mem[c_index] <= mac_out;
        end
    end

    /*
     * Controller state and accumulation registers retain asynchronous reset.
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            i     <= '0;
            j     <= '0;
            k     <= '0;
            acc   <= '0;
        end else begin
            case (state)
                S_IDLE: begin
                    acc <= '0;
                    i   <= '0;
                    j   <= '0;
                    k   <= '0;

                    if (start) begin
                        state <= S_COMPUTE;
                    end
                end

                S_COMPUTE: begin
                    if (k == LAST_INDEX) begin
                        acc <= '0;
                        k   <= '0;

                        if ((i == LAST_INDEX) &&
                            (j == LAST_INDEX)) begin
                            state <= S_DONE;
                        end else if (j == LAST_INDEX) begin
                            j <= '0;
                            i <= i + 1'b1;
                        end else begin
                            j <= j + 1'b1;
                        end
                    end else begin
                        acc <= mac_out;
                        k   <= k + 1'b1;
                    end
                end

                S_DONE: begin
                    if (!start) begin
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    i     <= '0;
                    j     <= '0;
                    k     <= '0;
                    acc   <= '0;
                end
            endcase
        end
    end

endmodule
