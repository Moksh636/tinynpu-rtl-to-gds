`timescale 1ns/1ps

module tinynpu_apb #(
    parameter int N              = 4,
    parameter int DATA_WIDTH     = 8,
    parameter int ACC_WIDTH      = 32,
    parameter int APB_ADDR_WIDTH = 12,
    parameter int CORE_ADDR_WIDTH =
        ((N * N) > 1) ? $clog2(N * N) : 1
)(
    input  logic                      PCLK,
    input  logic                      PRESETn,

    input  logic                      PSEL,
    input  logic                      PENABLE,
    input  logic                      PWRITE,
    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic [31:0]               PWDATA,

    output logic [31:0]               PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR
);

    localparam int ELEMENTS = N * N;

    /*
     * Software-visible APB register addresses.
     */
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_CONTROL = 12'h000;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_STATUS  = 12'h004;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_CONFIG  = 12'h008;

    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_A_INDEX = 12'h010;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_A_DATA  = 12'h014;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_B_INDEX = 12'h018;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_B_DATA  = 12'h01C;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_C_INDEX = 12'h020;
    localparam logic [APB_ADDR_WIDTH-1:0] ADDR_C_DATA  = 12'h024;

    /*
     * Eight-bit representations used by CONFIG.
     */
    localparam logic [7:0] CFG_N          = N[7:0];
    localparam logic [7:0] CFG_DATA_WIDTH = DATA_WIDTH[7:0];
    localparam logic [7:0] CFG_ACC_WIDTH  = ACC_WIDTH[7:0];
    localparam logic [7:0] CFG_ELEMENTS   = ELEMENTS[7:0];

    /*
     * APB transfer classification.
     *
     * APB has a setup phase followed by an access phase. A transfer
     * completes when PSEL, PENABLE, and PREADY are all asserted.
     */
    logic apb_access;
    logic apb_read;
    logic apb_write;
    logic address_aligned;
    logic transaction_error;

    assign PREADY          = 1'b1;
    assign apb_access      = PSEL && PENABLE && PREADY;
    assign apb_read        = apb_access && !PWRITE;
    assign apb_write       = apb_access && PWRITE;
    assign address_aligned = (PADDR[1:0] == 2'b00);

    /*
     * Software-selected matrix indexes.
     */
    logic [CORE_ADDR_WIDTH-1:0] a_index;
    logic [CORE_ADDR_WIDTH-1:0] b_index;
    logic [CORE_ADDR_WIDTH-1:0] c_index;

    /*
     * Software-readable shadow copies of the operand matrices.
     *
     * tinynpu_core does not expose its internal A and B memories for
     * reading, so the wrapper remembers every successful operand write.
     */
    logic signed [DATA_WIDTH-1:0] a_shadow [0:ELEMENTS-1];
    logic signed [DATA_WIDTH-1:0] b_shadow [0:ELEMENTS-1];

    integer reset_index;

    /*
     * Operand-loaded masks.
     *
     * These will be updated when A_DATA and B_DATA writes are added.
     */
    logic [ELEMENTS-1:0] a_loaded;
    logic [ELEMENTS-1:0] b_loaded;
    logic                operands_ready;

    assign operands_ready = (&a_loaded) && (&b_loaded);

    /*
     * Sticky software-visible status.
     */
    logic done_sticky;
    logic error_sticky;

    /*
     * Signals connecting the APB wrapper to tinynpu_core.
     */
    logic                         core_load_en;
    logic                         core_load_sel;
    logic [CORE_ADDR_WIDTH-1:0]   core_load_addr;
    logic signed [DATA_WIDTH-1:0] core_load_data;

    logic                         core_start;

    logic [CORE_ADDR_WIDTH-1:0]   core_result_addr;
    logic signed [ACC_WIDTH-1:0]  core_result_data;

    logic                         core_busy;
    logic                         core_done;

    /*
     * Register read path.
     */
    always_comb begin
        PRDATA = 32'b0;

        if (apb_read && address_aligned) begin
            case (PADDR)
                ADDR_STATUS: begin
                    PRDATA[0] = core_busy;
                    PRDATA[1] = done_sticky;
                    PRDATA[2] = error_sticky;
                    PRDATA[3] = operands_ready;
                end

                ADDR_CONFIG: begin
                    PRDATA = {
                        CFG_ELEMENTS,
                        CFG_ACC_WIDTH,
                        CFG_DATA_WIDTH,
                        CFG_N
                    };
                end

                ADDR_A_INDEX: begin
                    PRDATA[CORE_ADDR_WIDTH-1:0] = a_index;
                end

                ADDR_A_DATA: begin
                    PRDATA = {
                        {(32-DATA_WIDTH){
                            a_shadow[a_index][DATA_WIDTH-1]
                        }},
                        a_shadow[a_index]
                    };
                end

                ADDR_B_INDEX: begin
                    PRDATA[CORE_ADDR_WIDTH-1:0] = b_index;
                end

                ADDR_B_DATA: begin
                    PRDATA = {
                        {(32-DATA_WIDTH){
                            b_shadow[b_index][DATA_WIDTH-1]
                        }},
                        b_shadow[b_index]
                    };
                end

                ADDR_C_INDEX: begin
                    PRDATA[CORE_ADDR_WIDTH-1:0] = c_index;
                end

                ADDR_C_DATA: begin
                    PRDATA = core_result_data;
                end

                default: begin
                    PRDATA = 32'b0;
                end
            endcase
        end
    end

    /*
     * APB transaction validation.
     */
    always_comb begin
        transaction_error = 1'b0;

        if (apb_access) begin
            if (!address_aligned) begin
                transaction_error = 1'b1;
            end
            else if (apb_read) begin
                case (PADDR)
                    ADDR_STATUS,
                    ADDR_CONFIG,
                    ADDR_A_INDEX,
                    ADDR_A_DATA,
                    ADDR_B_INDEX,
                    ADDR_B_DATA,
                    ADDR_C_INDEX,
                    ADDR_C_DATA: transaction_error = 1'b0;

                    default: transaction_error = 1'b1;
                endcase
            end
            else if (apb_write) begin
                case (PADDR)
                    ADDR_CONTROL: begin
                        /*
                         * A START request requires complete operands
                         * and an idle compute core.
                         */
                        if (PWDATA[0] &&
                            (!operands_ready || core_busy)) begin
                            transaction_error = 1'b1;
                        end
                    end

                    ADDR_A_INDEX,
                    ADDR_B_INDEX,
                    ADDR_C_INDEX: begin
                        if (PWDATA >= ELEMENTS) begin
                            transaction_error = 1'b1;
                        end
                    end

                    ADDR_A_DATA,
                    ADDR_B_DATA: begin
                        /*
                         * Operand memories must not change during an
                         * active computation.
                         */
                        if (core_busy) begin
                            transaction_error = 1'b1;
                        end
                    end

                    default: transaction_error = 1'b1;
                endcase
            end
        end
    end

    assign PSLVERR = transaction_error;

    /*
     * Sequential software-register state.
     */
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            a_index      <= '0;
            b_index      <= '0;
            c_index      <= '0;

            a_loaded     <= '0;
            b_loaded     <= '0;

            for (reset_index = 0;
                 reset_index < ELEMENTS;
                 reset_index = reset_index + 1) begin
                a_shadow[reset_index] <= '0;
                b_shadow[reset_index] <= '0;
            end

            done_sticky  <= 1'b0;
            error_sticky <= 1'b0;
        end
        else begin
            /*
             * Valid index writes.
             */
            if (apb_write &&
                address_aligned &&
                !transaction_error) begin
                case (PADDR)
                    ADDR_A_INDEX:
                        a_index <= PWDATA[CORE_ADDR_WIDTH-1:0];

                    ADDR_A_DATA: begin
                        a_shadow[a_index] <=
                            $signed(PWDATA[DATA_WIDTH-1:0]);
                        a_loaded[a_index] <= 1'b1;
                    end

                    ADDR_B_INDEX:
                        b_index <= PWDATA[CORE_ADDR_WIDTH-1:0];

                    ADDR_B_DATA: begin
                        b_shadow[b_index] <=
                            $signed(PWDATA[DATA_WIDTH-1:0]);
                        b_loaded[b_index] <= 1'b1;
                    end

                    ADDR_C_INDEX:
                        c_index <= PWDATA[CORE_ADDR_WIDTH-1:0];

                    default: begin
                    end
                endcase
            end

            /*
             * CONTROL write-one-to-clear behavior.
             */
            if (apb_write &&
                address_aligned &&
                PADDR == ADDR_CONTROL) begin
                if (PWDATA[1]) begin
                    done_sticky <= 1'b0;
                end

                if (PWDATA[2]) begin
                    error_sticky <= 1'b0;
                end
            end

            /*
             * Hardware completion sets DONE after any software clear.
             */
            if (core_done) begin
                done_sticky <= 1'b1;
            end

            /*
             * Any rejected APB transaction sets ERROR after any clear.
             */
            if (transaction_error) begin
                error_sticky <= 1'b1;
            end
        end
    end

    /*
     * Translate valid APB writes into one-cycle core-control pulses.
     */
    assign core_load_en =
        apb_write &&
        !transaction_error &&
        ((PADDR == ADDR_A_DATA) ||
         (PADDR == ADDR_B_DATA));

    assign core_load_sel =
        (PADDR == ADDR_B_DATA);

    assign core_load_addr =
        core_load_sel ? b_index : a_index;

    assign core_load_data =
        PWDATA[DATA_WIDTH-1:0];

    assign core_start =
        apb_write &&
        !transaction_error &&
        (PADDR == ADDR_CONTROL) &&
        PWDATA[0];

    assign core_result_addr = c_index;

    tinynpu_core #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(CORE_ADDR_WIDTH)
    ) u_tinynpu_core (
        .clk(PCLK),
        .rst_n(PRESETn),

        .load_en(core_load_en),
        .load_sel(core_load_sel),
        .load_addr(core_load_addr),
        .load_data(core_load_data),

        .start(core_start),

        .result_addr(core_result_addr),
        .result_data(core_result_data),

        .busy(core_busy),
        .done(core_done)
    );

endmodule
