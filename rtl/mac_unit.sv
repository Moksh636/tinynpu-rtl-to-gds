`timescale 1ns/1ps

module mac_unit #(
    parameter int A_WIDTH   = 8,
    parameter int B_WIDTH   = 8,
    parameter int ACC_WIDTH = 32
)(
    input  logic signed [A_WIDTH-1:0]   a,
    input  logic signed [B_WIDTH-1:0]   b,
    input  logic signed [ACC_WIDTH-1:0] acc_in,
    output logic signed [ACC_WIDTH-1:0] acc_out
);

    localparam int PROD_WIDTH = A_WIDTH + B_WIDTH;

    logic signed [PROD_WIDTH-1:0] product;

    always_comb begin
        product = a * b;
        acc_out = acc_in + product;
    end

endmodule
