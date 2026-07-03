`timescale 1ns/1ps

module tinynpu_core #(
    parameter int N         = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
)(
    input  logic clk,
    input  logic rst_n,

    input  logic load_en,
    input  logic load_sel,       // 0 = matrix A, 1 = matrix B
    input  logic [3:0] load_addr,
    input  logic signed [DATA_WIDTH-1:0] load_data,

    input  logic start,

    input  logic [3:0] result_addr,
    output logic signed [ACC_WIDTH-1:0] result_data,

    output logic busy,
    output logic done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_COMPUTE,
        S_DONE
    } state_t;

    state_t state;

    logic signed [DATA_WIDTH-1:0] a_mem [0:N*N-1];
    logic signed [DATA_WIDTH-1:0] b_mem [0:N*N-1];
    logic signed [ACC_WIDTH-1:0]  c_mem [0:N*N-1];

    logic [$clog2(N)-1:0] i;
    logic [$clog2(N)-1:0] j;
    logic [$clog2(N)-1:0] k;

    logic signed [ACC_WIDTH-1:0] acc;
    logic signed [ACC_WIDTH-1:0] mac_out;

    int unsigned a_index;
    int unsigned b_index;
    int unsigned c_index;

    integer idx;

    always_comb begin
        a_index = (i * N) + k;
        b_index = (k * N) + j;
        c_index = (i * N) + j;
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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            i <= '0;
            j <= '0;
            k <= '0;
            acc <= '0;

            for (idx = 0; idx < N*N; idx = idx + 1) begin
                a_mem[idx] <= '0;
                b_mem[idx] <= '0;
                c_mem[idx] <= '0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    acc <= '0;
                    i <= '0;
                    j <= '0;
                    k <= '0;

                    if (load_en) begin
                        if (load_sel == 1'b0) begin
                            a_mem[load_addr] <= load_data;
                        end else begin
                            b_mem[load_addr] <= load_data;
                        end
                    end

                    if (start) begin
                        state <= S_COMPUTE;
                    end
                end

                S_COMPUTE: begin
                    if (k == N-1) begin
                        c_mem[c_index] <= mac_out;
                        acc <= '0;
                        k <= '0;

                        if ((i == N-1) && (j == N-1)) begin
                            state <= S_DONE;
                        end else if (j == N-1) begin
                            j <= '0;
                            i <= i + 1'b1;
                        end else begin
                            j <= j + 1'b1;
                        end
                    end else begin
                        acc <= mac_out;
                        k <= k + 1'b1;
                    end
                end

                S_DONE: begin
                    if (!start) begin
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
