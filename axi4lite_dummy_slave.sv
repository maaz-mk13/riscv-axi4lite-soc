
// =============================================================================
// axi4lite_dummy_slave.sv
// TEMPORARY / TEST-ONLY. A minimal AXI4-Lite slave with a single 32-bit
// read/write scratch register, used purely to validate the adapter +
// interconnect path end-to-end before real peripherals exist.
//
// This file gets replaced by axi4lite_gpio.sv -- do not wire this into
// soc_top permanently.
// =============================================================================
module axi4lite_dummy_slave
    import soc_pkg::*;
(
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,

    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready
);

    logic [31:0] scratch_reg;

    // ---- Write path ----
    typedef enum logic [1:0] {W_IDLE, W_RESP} w_state_e;
    w_state_e w_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            w_state     <= W_IDLE;
            scratch_reg <= 32'd0;
        end else begin
            unique case (w_state)
                W_IDLE: if (awvalid && wvalid) begin
                    scratch_reg <= wdata;
                    w_state     <= W_RESP;
                end
                W_RESP: if (bready) w_state <= W_IDLE;
                default: w_state <= W_IDLE;
            endcase
        end
    end

    assign awready = (w_state == W_IDLE);
    assign wready  = (w_state == W_IDLE);
    assign bvalid  = (w_state == W_RESP);
    assign bresp   = AXI_RESP_OKAY;

    // ---- Read path ----
    typedef enum logic [1:0] {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            r_state <= R_IDLE;
        end else begin
            unique case (r_state)
                R_IDLE: if (arvalid) r_state <= R_RESP;
                R_RESP: if (rready)  r_state <= R_IDLE;
                default: r_state <= R_IDLE;
            endcase
        end
    end

    assign arready = (r_state == R_IDLE);
    assign rvalid  = (r_state == R_RESP);
    assign rresp   = AXI_RESP_OKAY;
    assign rdata   = scratch_reg;

endmodule : axi4lite_dummy_slave