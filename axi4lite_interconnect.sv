
// =============================================================================
// axi4lite_interconnect.sv
// Single AXI4-Lite master -> up to NUM_SLAVES=4 slaves. Pure combinational
// address decode (safe because the core/adapter hold the address stable for
// the whole multi-cycle transaction -- no registration needed).
//
// For unmapped addresses, the interconnect itself completes the AXI
// handshake and returns SLVERR -- it never silently drops a transaction,
// so the core can never hang waiting on an address that doesn't exist.
//
// Slave index mapping (matches soc_pkg base addresses):
//   0 = GPIO, 1 = Timer, 2 = PWM, 3 = UART
// =============================================================================
module axi4lite_interconnect
    import soc_pkg::*;
#(
    parameter int NUM_SLAVES = 4
) (
    input  logic clk,
    input  logic rst,

    // ---- Master-side (from core_to_axi_master_adapter) ----
    input  logic [31:0] m_awaddr,
    input  logic        m_awvalid,
    output logic        m_awready,
    input  logic [31:0] m_wdata,
    input  logic [3:0]  m_wstrb,
    input  logic        m_wvalid,
    output logic        m_wready,
    output logic [1:0]  m_bresp,
    output logic        m_bvalid,
    input  logic        m_bready,
    input  logic [31:0] m_araddr,
    input  logic        m_arvalid,
    output logic        m_arready,
    output logic [31:0] m_rdata,
    output logic [1:0]  m_rresp,
    output logic        m_rvalid,
    input  logic        m_rready,

    // ---- Slave-side (to GPIO/Timer/PWM/UART), index 0..NUM_SLAVES-1 ----
    output logic [31:0] s_awaddr  [NUM_SLAVES],
    output logic        s_awvalid [NUM_SLAVES],
    input  logic        s_awready [NUM_SLAVES],
    output logic [31:0] s_wdata   [NUM_SLAVES],
    output logic [3:0]  s_wstrb   [NUM_SLAVES],
    output logic        s_wvalid  [NUM_SLAVES],
    input  logic        s_wready  [NUM_SLAVES],
    input  logic [1:0]  s_bresp   [NUM_SLAVES],
    input  logic        s_bvalid  [NUM_SLAVES],
    output logic        s_bready  [NUM_SLAVES],
    output logic [31:0] s_araddr  [NUM_SLAVES],
    output logic        s_arvalid [NUM_SLAVES],
    input  logic        s_arready [NUM_SLAVES],
    input  logic [31:0] s_rdata   [NUM_SLAVES],
    input  logic [1:0]  s_rresp   [NUM_SLAVES],
    input  logic        s_rvalid  [NUM_SLAVES],
    output logic        s_rready  [NUM_SLAVES]
);

    localparam logic [2:0] SEL_INVALID = 3'd4;

    function automatic logic [2:0] decode_addr(input logic [31:0] addr);
        if      (addr >= GPIO_BASE  && addr < GPIO_BASE  + PERIPH_SIZE) decode_addr = 3'd0;
        else if (addr >= TIMER_BASE && addr < TIMER_BASE + PERIPH_SIZE) decode_addr = 3'd1;
        else if (addr >= PWM_BASE   && addr < PWM_BASE   + PERIPH_SIZE) decode_addr = 3'd2;
        else if (addr >= UART_BASE  && addr < UART_BASE  + PERIPH_SIZE) decode_addr = 3'd3;
        else decode_addr = SEL_INVALID;
    endfunction

    logic [2:0] wr_sel, rd_sel;
    assign wr_sel = decode_addr(m_awaddr);
    assign rd_sel = decode_addr(m_araddr);

    // Safe 2-bit array indices -- always in [0,3] even when wr_sel/rd_sel
    // is SEL_INVALID (3'd4 -> lower 2 bits = 0), avoiding any out-of-range
    // array access; the *_err_active flags below decide which value is
    // actually used, this just keeps indexing well-defined.
    logic [1:0] wr_sel_idx, rd_sel_idx;
    assign wr_sel_idx = wr_sel[1:0];
    assign rd_sel_idx = rd_sel[1:0];

    logic wr_err_active, rd_err_active;
    assign wr_err_active = (wr_sel == SEL_INVALID);
    assign rd_err_active = (rd_sel == SEL_INVALID);

    // ---------------- Write channel routing ----------------
    genvar gi;
    generate
        for (gi = 0; gi < NUM_SLAVES; gi++) begin : gen_wr_route
            assign s_awaddr[gi]  = m_awaddr;
            assign s_awvalid[gi] = (wr_sel == gi) ? m_awvalid : 1'b0;
            assign s_wdata[gi]   = m_wdata;
            assign s_wstrb[gi]   = m_wstrb;
            assign s_wvalid[gi]  = (wr_sel == gi) ? m_wvalid : 1'b0;
            assign s_bready[gi]  = (wr_sel == gi) ? m_bready : 1'b0;
        end
    endgenerate

    // ---------------- Read channel routing ----------------
    generate
        for (gi = 0; gi < NUM_SLAVES; gi++) begin : gen_rd_route
            assign s_araddr[gi]  = m_araddr;
            assign s_arvalid[gi] = (rd_sel == gi) ? m_arvalid : 1'b0;
            assign s_rready[gi]  = (rd_sel == gi) ? m_rready  : 1'b0;
        end
    endgenerate

    // ---------------- Unmapped-address fake responder (write) ----------------
    typedef enum logic [1:0] {WR_IDLE, WR_RESP} wr_err_state_e;
    wr_err_state_e wr_err_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_err_state <= WR_IDLE;
        end else begin
            unique case (wr_err_state)
                WR_IDLE: if (wr_err_active && m_awvalid && m_wvalid) wr_err_state <= WR_RESP;
                WR_RESP: if (m_bready) wr_err_state <= WR_IDLE;
                default: wr_err_state <= WR_IDLE;
            endcase
        end
    end

    // ---------------- Unmapped-address fake responder (read) ----------------
    typedef enum logic [1:0] {RD_IDLE, RD_RESP} rd_err_state_e;
    rd_err_state_e rd_err_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_err_state <= RD_IDLE;
        end else begin
            unique case (rd_err_state)
                RD_IDLE: if (rd_err_active && m_arvalid) rd_err_state <= RD_RESP;
                RD_RESP: if (m_rready) rd_err_state <= RD_IDLE;
                default: rd_err_state <= RD_IDLE;
            endcase
        end
    end

    // ---------------- Master-side response mux ----------------
    assign m_awready = wr_err_active ? (wr_err_state == WR_IDLE) : s_awready[wr_sel_idx];
    assign m_wready   = wr_err_active ? (wr_err_state == WR_IDLE) : s_wready[wr_sel_idx];
    assign m_bvalid   = wr_err_active ? (wr_err_state == WR_RESP) : s_bvalid[wr_sel_idx];
    assign m_bresp    = wr_err_active ? AXI_RESP_SLVERR : s_bresp[wr_sel_idx];

    assign m_arready = rd_err_active ? (rd_err_state == RD_IDLE) : s_arready[rd_sel_idx];
    assign m_rvalid   = rd_err_active ? (rd_err_state == RD_RESP) : s_rvalid[rd_sel_idx];
    assign m_rresp    = rd_err_active ? AXI_RESP_SLVERR : s_rresp[rd_sel_idx];
    assign m_rdata    = rd_err_active ? 32'd0 : s_rdata[rd_sel_idx];

endmodule : axi4lite_interconnect