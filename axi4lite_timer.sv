// =============================================================================
// axi4lite_timer.sv
// Memory-mapped down-counting timer, AXI4-Lite slave.
//
// Register map (offsets from TIMER_BASE, see soc_pkg.sv):
//   0x0  TIMER_CTRL    RW    reset 0x0   bit0=enable, bit1=mode (0=one-shot,1=periodic)
//   0x4  TIMER_COUNT   RO    --          live down-counter value
//   0x8  TIMER_LOAD    RW    reset 0x0   reload value
//   0xC  TIMER_STATUS  RW1C  reset 0x0   bit0=expired flag (write 1 to clear)
//
// Behavior:
//   - On the rising edge of `enable` (0->1), the counter loads from LOAD
//     (or, if LOAD is already 0, expires immediately).
//   - While enabled, the counter decrements by 1 every clock cycle.
//   - The expired flag is set exactly ONCE, on the cycle the countdown
//     actually crosses to zero -- not held as a level while sitting at
//     zero. In periodic mode, the counter reloads from LOAD on that same
//     cycle and keeps counting. In one-shot mode, the counter holds at 0
//     afterward without re-touching the flag, so a software RW1C clear
//     works correctly even while still enabled.
// =============================================================================
module axi4lite_timer
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

    logic [31:0] ctrl_reg;
    logic [31:0] load_reg;
    logic [31:0] count_reg;
    logic        expired_flag;

    wire enable   = ctrl_reg[0];
    wire periodic = ctrl_reg[1];

    // Edge-detect enable separately -- single driver, no conflict with the
    // combined write/counter process below.
    logic enable_prev;
    always_ff @(posedge clk) begin
        if (rst) enable_prev <= 1'b0;
        else     enable_prev <= enable;
    end
    wire enable_rising = enable && !enable_prev;

    // ---- Write path + counter tick, combined into one process ----
    typedef enum logic [1:0] {W_IDLE, W_RESP} w_state_e;
    w_state_e w_state;

    logic [3:0] waddr_offset;
    assign waddr_offset = awaddr[3:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            w_state      <= W_IDLE;
            ctrl_reg     <= 32'd0;
            load_reg     <= 32'd0;
            count_reg    <= 32'd0;
            expired_flag <= 1'b0;
        end else begin
            unique case (w_state)
                W_IDLE: begin
                    if (awvalid && wvalid) begin
                        unique case (waddr_offset)
                            TIMER_CTRL: begin
                                if (wstrb[0]) ctrl_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) ctrl_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) ctrl_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) ctrl_reg[31:24] <= wdata[31:24];
                            end
                            TIMER_LOAD: begin
                                if (wstrb[0]) load_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) load_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) load_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) load_reg[31:24] <= wdata[31:24];
                            end
                            TIMER_STATUS: begin
                                if (wstrb[0] && wdata[0]) expired_flag <= 1'b0;  // RW1C
                            end
                            default: ; // TIMER_COUNT (RO) or unmapped offset -- no-op
                        endcase
                        w_state <= W_RESP;
                    end
                end
                W_RESP: if (bready) w_state <= W_IDLE;
                default: w_state <= W_IDLE;
            endcase

            // Counter tick -- runs every cycle regardless of AXI activity.
            // IMPORTANT: expired_flag is set exactly once, on the cycle the
            // countdown actually crosses to zero (or on enable_rising with
            // LOAD=0) -- NOT as a held level while sitting at zero. A level
            // condition here would re-assert expired_flag every cycle while
            // one-shot mode sits at 0, fighting any software RW1C clear
            // attempted while still enabled.
            if (enable_rising) begin
                count_reg <= load_reg;
                if (load_reg == 32'd0) expired_flag <= 1'b1;
            end else if (enable) begin
                if (count_reg == 32'd0) begin
                    // One-shot, already expired: hold at 0, don't touch
                    // expired_flag -- lets a software RW1C clear stick.
                end else if (count_reg == 32'd1) begin
                    // The actual zero-crossing event, fires exactly once.
                    count_reg    <= periodic ? load_reg : 32'd0;
                    expired_flag <= 1'b1;
                end else begin
                    count_reg <= count_reg - 32'd1;
                end
            end
        end
    end

    assign awready = (w_state == W_IDLE);
    assign wready  = (w_state == W_IDLE);
    assign bvalid  = (w_state == W_RESP);
    assign bresp   = AXI_RESP_OKAY;

    // ---- Read path ----
    typedef enum logic [1:0] {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state;

    logic [3:0]  raddr_offset;
    logic [31:0] read_data;
    assign raddr_offset = araddr[3:0];

    always_comb begin
        unique case (raddr_offset)
            TIMER_CTRL:   read_data = ctrl_reg;
            TIMER_COUNT:  read_data = count_reg;
            TIMER_LOAD:   read_data = load_reg;
            TIMER_STATUS: read_data = {31'd0, expired_flag};
            default:      read_data = 32'd0;
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

endmodule : axi4lite_timer