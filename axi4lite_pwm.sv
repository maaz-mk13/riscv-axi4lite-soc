// =============================================================================
// axi4lite_pwm.sv
// Memory-mapped PWM generator, AXI4-Lite slave.
//
// Register map (offsets from PWM_BASE, see soc_pkg.sv):
//   0x0  PWM_CTRL    RW   reset 0x0   bit0=enable
//   0x4  PWM_PERIOD  RW   reset 0x0   period in clock cycles
//   0x8  PWM_DUTY    RW   reset 0x0   high-time in clock cycles
//   0xC  PWM_STATUS  RO   --          bit0=current pwm_out level (readback)
//
// Behavior: a free-running counter increments 0..PERIOD-1 while enabled,
// wrapping back to 0. pwm_out is high whenever counter < DUTY.
//   - DUTY >= PERIOD naturally clamps to 100% (counter is always < DUTY).
//   - DUTY == 0 naturally gives 0% (counter is never < 0).
//   - PERIOD == 0 is a documented edge case: counter is held at 0 and
//     pwm_out forced low, rather than dividing by zero or locking up.
// =============================================================================
module axi4lite_pwm
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

    output logic pwm_out
);

    logic [31:0] ctrl_reg;
    logic [31:0] period_reg;
    logic [31:0] duty_reg;
    logic [31:0] counter;

    wire enable = ctrl_reg[0];

    // ---- Write path + free-running counter, combined into one process ----
    typedef enum logic [1:0] {W_IDLE, W_RESP} w_state_e;
    w_state_e w_state;

    logic [3:0] waddr_offset;
    assign waddr_offset = awaddr[3:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            w_state    <= W_IDLE;
            ctrl_reg   <= 32'd0;
            period_reg <= 32'd0;
            duty_reg   <= 32'd0;
            counter    <= 32'd0;
        end else begin
            unique case (w_state)
                W_IDLE: begin
                    if (awvalid && wvalid) begin
                        unique case (waddr_offset)
                            PWM_CTRL: begin
                                if (wstrb[0]) ctrl_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) ctrl_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) ctrl_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) ctrl_reg[31:24] <= wdata[31:24];
                            end
                            PWM_PERIOD: begin
                                if (wstrb[0]) period_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) period_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) period_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) period_reg[31:24] <= wdata[31:24];
                            end
                            PWM_DUTY: begin
                                if (wstrb[0]) duty_reg[7:0]   <= wdata[7:0];
                                if (wstrb[1]) duty_reg[15:8]  <= wdata[15:8];
                                if (wstrb[2]) duty_reg[23:16] <= wdata[23:16];
                                if (wstrb[3]) duty_reg[31:24] <= wdata[31:24];
                            end
                            default: ; // PWM_STATUS (RO) or unmapped -- no-op
                        endcase
                        w_state <= W_RESP;
                    end
                end
                W_RESP: if (bready) w_state <= W_IDLE;
                default: w_state <= W_IDLE;
            endcase

            // Free-running counter tick.
            if (!enable) begin
                counter <= 32'd0;
            end else if (period_reg == 32'd0) begin
                counter <= 32'd0;   // avoid undefined wrap when PERIOD=0
            end else if (counter >= period_reg - 32'd1) begin
                counter <= 32'd0;
            end else begin
                counter <= counter + 32'd1;
            end
        end
    end

    assign awready = (w_state == W_IDLE);
    assign wready  = (w_state == W_IDLE);
    assign bvalid  = (w_state == W_RESP);
    assign bresp   = AXI_RESP_OKAY;

    // ---- PWM output level ----
    logic pwm_level;
    always_comb begin
        if (!enable || period_reg == 32'd0) pwm_level = 1'b0;
        else                                 pwm_level = (counter < duty_reg);
    end
    assign pwm_out = pwm_level;

    // ---- Read path ----
    typedef enum logic [1:0] {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state;

    logic [3:0]  raddr_offset;
    logic [31:0] read_data;
    assign raddr_offset = araddr[3:0];

    always_comb begin
        unique case (raddr_offset)
            PWM_CTRL:   read_data = ctrl_reg;
            PWM_PERIOD: read_data = period_reg;
            PWM_DUTY:   read_data = duty_reg;
            PWM_STATUS: read_data = {31'd0, pwm_level};
            default:    read_data = 32'd0;
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

endmodule : axi4lite_pwm