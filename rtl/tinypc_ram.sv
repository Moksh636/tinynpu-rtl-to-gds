`timescale 1ns/1ps

module tinypc_ram #(
    parameter int ADDR_WIDTH = 14
)(
    input  logic                  clk,
    input  logic                  write_en,
    input  logic [3:0]            wstrb,
    input  logic [ADDR_WIDTH-3:0] word_addr,
    input  logic [31:0]           wdata,
    output logic [31:0]           rdata
);

    localparam int WORDS = 1 << (ADDR_WIDTH - 2);

    logic [31:0] mem [0:WORDS-1];

    always_ff @(posedge clk) begin
        if (write_en) begin
            if (wstrb[0]) mem[word_addr][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[word_addr][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[word_addr][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[word_addr][31:24] <= wdata[31:24];
        end
    end

    assign rdata = mem[word_addr];

endmodule
