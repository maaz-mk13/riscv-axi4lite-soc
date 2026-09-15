// =============================================================================
// axi4lite_gpio.sv
// Memory-mapped GPIO peripheral, AXI4-Lite slave.
//
// Register map (offsets from GPIO_BASE, see soc_pkg.sv):
//   0x0  GPIO_DATA_OUT  RW   reset 0x0   output pin values
//   0x4  GPIO_DATA_IN   RO   --          sampled input pin values (async, 2FF-synced)
//   0x8  GPIO_DIR       RW   reset 0x0   0=input, 1=output, per bit
//   0xC  GPIO_STATUS    RO   reads 0     reserved for future use
//
// Any other offset within the 4KB window reads as 0 / write is a no-op --
// still returns OKAY (only a fully unmapped *address*, handled upstream by
// the interconnect, returns SLVERR).
// =============================================================================
module axi4lite_gpio
    import soc_pkg::*;
#(
    parameter int GPIO_WIDTH = 8   // number of physical GPIO pins modeled
) (
    input  logic        clk,
    input  logic        rst,

    // ---- AXI4-Lite slave ----
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

    // ---- Physical GPIO pins ----
    input  logic [GPIO_WIDTH-1:0] gpio_in,    // external input pin values (async)
    output logic [GPIO_WIDTH-1:0] gpio_out,   // driven output pin values
    output logic [GPIO_WIDTH-1:0] gpio_dir    // 0=input, 1=output, per pin
);

    // ---- Registers ----
    logic [31:0] data_out_reg;
    logic [31:0] dir_reg;

    // 2-flop synchronizer for the asynchronous input pins.
    logic [GPIO_WIDTH-1:0] gpio_in_sync0, gpio_in_sync1;
    always_ff @(posedge clk) begin
        if (rst) begin
            gpio_in_sync0 <= '0;
            gpio_in_sync1 <= '0;
        end else begin
            gpio_in_sync0 <= gpio_in;
            gpio_in_sync1 <= gpio_in_sync0;
        end
    end

    assign gpio_out = data_out_reg[GPIO_WIDTH-1:0];
    assign gpio_dir = dir_reg[GPIO_WIDTH-1:0];

    // ---- Write path ----
    typedef enum logic [1:0] {W_IDLE, W_RESP} w_state_e;
    w_state_e w_state;

    logic [3:0] waddr_offset;
    assign waddr_offset = awaddr[3:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            w_state      <= W_IDLE;
            data_out_reg <= 32'd0;
            dir_reg      <= 32'd0;
        end else begin
            unique case (w_state)
                W_IDLE: begin
                    if (awvalid && wvalid) begin
                        unique case (waddr_offset)
                            GPIO_DATA_OUT: begin
                                if (wstrb[0]) data_out_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) data_out_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) data_out_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) data_out_reg[31:24] <= wdata[31:24];
                            end
                            GPIO_DIR: begin
                                if (wstrb[0]) dir_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) dir_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) dir_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) dir_reg[31:24] <= wdata[31:24];
                            end
                            default: begin
                                // GPIO_DATA_IN (RO) or GPIO_STATUS (RO) or any
                                // other offset: write is a no-op, still OKAY.
                            end
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

    // ---- Read path ----
    typedef enum logic [1:0] {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state;

    logic [3:0]  raddr_offset;
    logic [31:0] read_data;

    assign raddr_offset = araddr[3:0];

    always_comb begin
        unique case (raddr_offset)
            GPIO_DATA_OUT: read_data = data_out_reg;
            GPIO_DATA_IN:  read_data = {{(32-GPIO_WIDTH){1'b0}}, gpio_in_sync1};
            GPIO_DIR:      read_data = dir_reg;
            GPIO_STATUS:   read_data = 32'd0;
            default:       read_data = 32'd0;
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

endmodule : axi4lite_gpio
