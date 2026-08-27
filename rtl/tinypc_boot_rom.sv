`timescale 1ns/1ps

module tinypc_boot_rom #(
    parameter int ADDR_WIDTH = 12,
    parameter INIT_FILE = "",
    parameter int INIT_WORDS = 0
)(
    input  logic [ADDR_WIDTH-3:0] word_addr,
    output logic [31:0]           rdata
);

    localparam int WORDS = 1 << (ADDR_WIDTH - 2);

    logic [31:0] mem [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            mem[i] = 32'h00000000;
        end

        if (INIT_FILE != "") begin
            if (INIT_WORDS > 0) begin
                $readmemh(INIT_FILE, mem, 0, INIT_WORDS - 1);
            end
            else begin
                $readmemh(INIT_FILE, mem);
            end
        end
    end

    assign rdata = mem[word_addr];

endmodule
