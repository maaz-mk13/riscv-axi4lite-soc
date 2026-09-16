// =============================================================================
// axi4lite_uart.sv
// Memory-mapped UART, AXI4-Lite slave. Fixed 8N1 framing (8 data bits, no
// parity, 1 stop bit) -- only the baud divisor is software-configurable,
// per the documented scope simplification.
//
// Register map (offsets from UART_BASE, see soc_pkg.sv):
//   0x0  UART_TXDATA  WO    --          write triggers TX of one byte (bits 7:0)
//   0x4  UART_RXDATA  RO    --          last received byte; reading CLEARS rx_valid
//   0x8  UART_STATUS  RO    reset 0x1   bit0=tx_ready, bit1=rx_valid
//   0xC  UART_CTRL    RW    reset 0x0   baud divisor (clock cycles per bit)
//
// Documented simplifications:
//   - Writing TXDATA while busy (tx_ready=0) is silently ignored -- the
//     byte is dropped. Standard UART programming model expects software to
//     poll tx_ready first; this avoids corrupting an in-flight frame or
//     needing a TX FIFO, which is out of scope here.
//   - baud divisor = 0 is treated as "not configured": TX refuses new
//     bytes (tx_ready stays 0) and RX ignores line activity, rather than
//     locking up waiting for bit timing that can never occur.
//   - RX start-bit detection is level-based (any low sample while idle),
//     not edge-based with oversampling -- adequate for a directed
//     testbench driving discrete bit periods, not a substitute for a
//     production-grade noise-tolerant UART receiver.
// =============================================================================
module axi4lite_uart
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
    input  logic        rready,

    output logic uart_tx,
    input  logic uart_rx
);

    logic [31:0] ctrl_reg;   // baud divisor
    wire  [31:0] baud_div = ctrl_reg;

    logic [7:0] rx_data_reg;
    logic       rx_valid;
    logic       tx_ready;

    // ================= Write path (TXDATA / CTRL) =================
    typedef enum logic [1:0] {W_IDLE, W_RESP} w_state_e;
    w_state_e w_state;

    logic [3:0] waddr_offset;
    assign waddr_offset = awaddr[3:0];

    logic       tx_start_req;   // one-cycle pulse: "start transmitting tx_shift"
    logic [7:0] tx_shift;

    always_ff @(posedge clk) begin
        if (rst) begin
            w_state      <= W_IDLE;
            ctrl_reg     <= 32'd0;
            tx_shift     <= 8'd0;
            tx_start_req <= 1'b0;
        end else begin
            tx_start_req <= 1'b0;  // pulse: clear every cycle unless re-asserted below

            unique case (w_state)
                W_IDLE: begin
                    if (awvalid && wvalid) begin
                        unique case (waddr_offset)
                            UART_TXDATA: begin
                                if (tx_ready) begin
                                    tx_shift     <= wdata[7:0];
                                    tx_start_req <= 1'b1;
                                end
                                // else: busy or unconfigured -- byte dropped (documented)
                            end
                            UART_CTRL: begin
                                if (wstrb[0]) ctrl_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) ctrl_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) ctrl_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) ctrl_reg[31:24] <= wdata[31:24];
                            end
                            default: ; // RXDATA/STATUS (RO) or unmapped -- no-op
                        endcase
                        w_state <= W_RESP;
                    end
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

    // ================= TX shift FSM =================
    typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_e;
    tx_state_e tx_state;
    logic [2:0] tx_bit_idx;
    logic       uart_tx_r;
    logic [31:0] tx_baud_counter;

    always_ff @(posedge clk) begin
        if (rst) begin
            tx_state        <= TX_IDLE;
            uart_tx_r       <= 1'b1;   // idle line is high
            tx_bit_idx      <= 3'd0;
            tx_baud_counter <= 32'd0;
        end else begin
            unique case (tx_state)
                TX_IDLE: begin
                    uart_tx_r <= 1'b1;
                    tx_baud_counter <= 32'd0;
                    if (tx_start_req) tx_state <= TX_START;
                end
                TX_START: begin
                    uart_tx_r <= 1'b0;  // start bit
                    if (tx_baud_counter >= baud_div - 32'd1) begin
                        tx_baud_counter <= 32'd0;
                        tx_bit_idx      <= 3'd0;
                        tx_state        <= TX_DATA;
                    end else begin
                        tx_baud_counter <= tx_baud_counter + 32'd1;
                    end
                end
                TX_DATA: begin
                    uart_tx_r <= tx_shift[tx_bit_idx];
                    if (tx_baud_counter >= baud_div - 32'd1) begin
                        tx_baud_counter <= 32'd0;
                        if (tx_bit_idx == 3'd7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 3'd1;
                        end
                    end else begin
                        tx_baud_counter <= tx_baud_counter + 32'd1;
                    end
                end
                TX_STOP: begin
                    uart_tx_r <= 1'b1;  // stop bit
                    if (tx_baud_counter >= baud_div - 32'd1) begin
                        tx_baud_counter <= 32'd0;
                        tx_state        <= TX_IDLE;
                    end else begin
                        tx_baud_counter <= tx_baud_counter + 32'd1;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    assign tx_ready = (tx_state == TX_IDLE) && (baud_div != 32'd0);
    assign uart_tx  = uart_tx_r;

    // ================= RX shift FSM =================
    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_e;
    rx_state_e rx_state;
    logic [2:0]  rx_bit_idx;
    logic [7:0]  rx_shift;
    logic [31:0] rx_baud_counter;

    logic rx_read_clear;  // pulses when software's AXI read of RXDATA is accepted

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_state        <= RX_IDLE;
            rx_baud_counter  <= 32'd0;
            rx_bit_idx       <= 3'd0;
            rx_data_reg      <= 8'd0;
            rx_valid         <= 1'b0;
        end else begin
            unique case (rx_state)
                RX_IDLE: begin
                    rx_baud_counter <= 32'd0;
                    if (!uart_rx && (baud_div != 32'd0)) begin
                        rx_state <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_baud_counter >= baud_div - 32'd1) begin
                        rx_baud_counter <= 32'd0;
                        rx_bit_idx      <= 3'd0;
                        rx_state        <= RX_DATA;
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 32'd1;
                    end
                end
                RX_DATA: begin
                    // Sample mid-bit (not at the window's last cycle) --
                    // standard UART receiver practice, gives maximum margin
                    // against any small timing skew between transmitter
                    // and receiver instead of sampling right at a boundary.
                    if (rx_baud_counter == (baud_div >> 1)) begin
                        rx_shift[rx_bit_idx] <= uart_rx;
                    end
                    if (rx_baud_counter >= baud_div - 32'd1) begin
                        rx_baud_counter <= 32'd0;
                        if (rx_bit_idx == 3'd7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 3'd1;
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 32'd1;
                    end
                end
                RX_STOP: begin
                    if (rx_baud_counter >= baud_div - 32'd1) begin
                        rx_data_reg     <= rx_shift;
                        rx_valid        <= 1'b1;  // one-time pulse-into-latch on frame complete
                        rx_baud_counter <= 32'd0;
                        rx_state        <= RX_IDLE;
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 32'd1;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase

            // Clear-on-read: listed after the case above, so if a byte
            // finishes arriving on the exact same cycle a read completes,
            // the clear wins -- correct, since that read already captured
            // the fresh byte via rx_data_reg this same cycle.
            if (rx_read_clear) rx_valid <= 1'b0;
        end
    end

    // ================= Read path (RXDATA / STATUS / CTRL) =================
    typedef enum logic [1:0] {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state;

    logic [3:0]  raddr_offset;
    logic [31:0] read_data;
    assign raddr_offset = araddr[3:0];

    assign rx_read_clear = (r_state == R_IDLE) && arvalid && (raddr_offset == UART_RXDATA);

    always_comb begin
        unique case (raddr_offset)
            UART_RXDATA: read_data = {24'd0, rx_data_reg};
            UART_STATUS: read_data = {30'd0, rx_valid, tx_ready};
            UART_CTRL:   read_data = ctrl_reg;
            default:     read_data = 32'd0;  // UART_TXDATA (WO) or unmapped
        endcase
    end

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
    assign rdata   = read_data;

endmodule : axi4lite_uart