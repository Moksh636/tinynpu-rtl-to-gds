`timescale 1ns/1ps

module tinypc_interconnect #(
    parameter logic [31:0] ROM_BASE       = 32'h0000_0000,
    parameter int          ROM_ADDR_WIDTH = 12,
    parameter              ROM_INIT_FILE  = "",
    parameter int          ROM_INIT_WORDS = 0,

    parameter logic [31:0] RAM_BASE       = 32'h1000_0000,
    parameter int          RAM_ADDR_WIDTH = 14,

    parameter logic [31:0] NPU_BASE       = 32'h4000_0000,
    parameter int          NPU_ADDR_WIDTH = 12
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        req_valid,
    output logic        req_ready,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,

    output logic        rsp_valid,
    output logic [31:0] rsp_rdata,
    output logic        rsp_err
);

    localparam logic [31:0] ROM_BYTES = 32'h0000_0001 << ROM_ADDR_WIDTH;
    localparam logic [31:0] RAM_BYTES = 32'h0000_0001 << RAM_ADDR_WIDTH;
    localparam logic [31:0] NPU_BYTES = 32'h0000_0001 << NPU_ADDR_WIDTH;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_RESP,
        ST_APB_SETUP,
        ST_APB_ACCESS
    } state_t;

    state_t state;

    logic [31:0] pending_rdata;
    logic        pending_err;

    logic        address_aligned;
    logic        hit_rom;
    logic        hit_ram;
    logic        hit_npu;
    logic        accept_req;

    logic [ROM_ADDR_WIDTH-3:0] rom_word_addr;
    logic [31:0]               rom_rdata;

    logic                      ram_write_en;
    logic [RAM_ADDR_WIDTH-3:0] ram_word_addr;
    logic [31:0]               ram_rdata;

    logic                      npu_psel;
    logic                      npu_penable;
    logic                      npu_pwrite;
    logic [NPU_ADDR_WIDTH-1:0] npu_paddr;
    logic [31:0]               npu_pwdata;
    logic [31:0]               npu_prdata;
    logic                      npu_pready;
    logic                      npu_pslverr;

    logic                      apb_write_reg;
    logic [NPU_ADDR_WIDTH-1:0] apb_addr_reg;
    logic [31:0]               apb_wdata_reg;

    assign address_aligned = (req_addr[1:0] == 2'b00);

    assign hit_rom = (req_addr - ROM_BASE) < ROM_BYTES;
    assign hit_ram = (req_addr - RAM_BASE) < RAM_BYTES;
    assign hit_npu = (req_addr - NPU_BASE) < NPU_BYTES;

    assign req_ready  = (state == ST_IDLE);
    assign accept_req = req_valid && req_ready;

    assign rsp_valid = (state == ST_RESP);
    assign rsp_rdata = pending_rdata;
    assign rsp_err   = pending_err;

    assign rom_word_addr = req_addr[ROM_ADDR_WIDTH-1:2];
    assign ram_word_addr = req_addr[RAM_ADDR_WIDTH-1:2];

    assign ram_write_en =
        accept_req &&
        address_aligned &&
        hit_ram &&
        req_write;

    assign npu_psel    = (state == ST_APB_SETUP) || (state == ST_APB_ACCESS);
    assign npu_penable = (state == ST_APB_ACCESS);
    assign npu_pwrite  = apb_write_reg;
    assign npu_paddr   = apb_addr_reg;
    assign npu_pwdata  = apb_wdata_reg;

    tinypc_boot_rom #(
        .ADDR_WIDTH(ROM_ADDR_WIDTH),
        .INIT_FILE(ROM_INIT_FILE),
        .INIT_WORDS(ROM_INIT_WORDS)
    ) u_boot_rom (
        .word_addr(rom_word_addr),
        .rdata(rom_rdata)
    );

    tinypc_ram #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_ram (
        .clk(clk),
        .write_en(ram_write_en),
        .wstrb(req_wstrb),
        .word_addr(ram_word_addr),
        .wdata(req_wdata),
        .rdata(ram_rdata)
    );

    tinynpu_apb #(
        .APB_ADDR_WIDTH(NPU_ADDR_WIDTH)
    ) u_tinynpu_apb (
        .PCLK(clk),
        .PRESETn(rst_n),
        .PSEL(npu_psel),
        .PENABLE(npu_penable),
        .PWRITE(npu_pwrite),
        .PADDR(npu_paddr),
        .PWDATA(npu_pwdata),
        .PRDATA(npu_prdata),
        .PREADY(npu_pready),
        .PSLVERR(npu_pslverr)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            pending_rdata <= 32'b0;
            pending_err   <= 1'b0;
            apb_write_reg <= 1'b0;
            apb_addr_reg  <= '0;
            apb_wdata_reg <= 32'b0;
        end
        else begin
            case (state)
                ST_IDLE: begin
                    if (accept_req) begin
                        pending_rdata <= 32'b0;
                        pending_err   <= 1'b0;

                        if (!address_aligned) begin
                            pending_err <= 1'b1;
                            state       <= ST_RESP;
                        end
                        else if (hit_rom) begin
                            pending_rdata <= rom_rdata;
                            pending_err   <= req_write;
                            state         <= ST_RESP;
                        end
                        else if (hit_ram) begin
                            pending_rdata <= ram_rdata;
                            pending_err   <= 1'b0;
                            state         <= ST_RESP;
                        end
                        else if (hit_npu) begin
                            if (req_write && (req_wstrb != 4'b1111)) begin
                                pending_err <= 1'b1;
                                state       <= ST_RESP;
                            end
                            else begin
                                apb_write_reg <= req_write;
                                apb_addr_reg  <= req_addr[NPU_ADDR_WIDTH-1:0];
                                apb_wdata_reg <= req_wdata;
                                state         <= ST_APB_SETUP;
                            end
                        end
                        else begin
                            pending_err <= 1'b1;
                            state       <= ST_RESP;
                        end
                    end
                end

                ST_RESP: begin
                    state <= ST_IDLE;
                end

                ST_APB_SETUP: begin
                    state <= ST_APB_ACCESS;
                end

                ST_APB_ACCESS: begin
                    if (npu_pready) begin
                        pending_rdata <= npu_prdata;
                        pending_err   <= npu_pslverr;
                        state         <= ST_RESP;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
