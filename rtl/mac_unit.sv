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
    logic signed [ACC_WIDTH-1:0]  product_extended;

    assign product = a * b;

    assign product_extended = {
        {(ACC_WIDTH-PROD_WIDTH){product[PROD_WIDTH-1]}},
        product
    };

    assign acc_out = acc_in + product_extended;

endmodule
