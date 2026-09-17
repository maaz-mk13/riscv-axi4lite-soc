// =============================================================================
// soc_top.sv
// Full SoC top-level: rv32i_core + instr_sram + data_sram + data_bus_decoder
// + core_to_axi_master_adapter + axi4lite_interconnect + all 4 real
// peripherals (GPIO, Timer, PWM, UART). This is the first time every module
// built so far is wired together as one system rather than tested in
// isolation or against a dummy/partial harness.
//
// Slave index mapping (matches axi4lite_interconnect's decode):
//   0 = GPIO, 1 = Timer, 2 = PWM, 3 = UART
// =============================================================================
module soc_top
    import soc_pkg::*;
#(
    parameter string IMEM_INIT_FILE = "program.hex"  // override per-testbench as needed
) (
    input  logic       clk,
    input  logic       rst,

    // ---- GPIO physical pins ----
    input  logic [7:0] gpio_in,
    output logic [7:0] gpio_out,
    output logic [7:0] gpio_dir,

    // ---- PWM physical pin ----
    output logic       pwm_out,

    // ---- UART physical pins ----
    output logic       uart_tx,
    input  logic       uart_rx
);

    localparam int NUM_SLAVES  = 4;
    localparam int GPIO_WIDTH  = 8;

    // ================= Core <-> Instruction memory =================
    logic [31:0] imem_addr, imem_rdata;

    // ================= Core <-> Data bus decoder =================
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_valid, dmem_ready;

    rv32i_core u_core (
        .clk (clk), .rst (rst),
        .imem_addr (imem_addr), .imem_rdata (imem_rdata),
        .dmem_addr (dmem_addr), .dmem_wdata (dmem_wdata), .dmem_rdata (dmem_rdata),
        .dmem_wstrb (dmem_wstrb), .dmem_valid (dmem_valid), .dmem_ready (dmem_ready)
    );

    instr_sram #(.INIT_FILE(IMEM_INIT_FILE)) u_imem (
        .addr  (imem_addr),
        .rdata (imem_rdata)
    );

    // ================= Data bus decoder <-> data SRAM =================
    logic [31:0] sram_addr, sram_wdata, sram_rdata;
    logic [3:0]  sram_wstrb;
    logic        sram_valid, sram_ready;

    // ================= Data bus decoder <-> AXI adapter =================
    logic [31:0] axi_cpu_addr, axi_cpu_wdata, axi_cpu_rdata;
    logic [3:0]  axi_cpu_wstrb;
    logic        axi_cpu_valid, axi_cpu_ready;

    data_bus_decoder u_decoder (
        .clk (clk), .rst (rst),
        .core_addr (dmem_addr), .core_wdata (dmem_wdata), .core_wstrb (dmem_wstrb),
        .core_valid (dmem_valid), .core_rdata (dmem_rdata), .core_ready (dmem_ready),
        .sram_addr (sram_addr), .sram_wdata (sram_wdata), .sram_wstrb (sram_wstrb),
        .sram_valid (sram_valid), .sram_rdata (sram_rdata), .sram_ready (sram_ready),
        .axi_addr (axi_cpu_addr), .axi_wdata (axi_cpu_wdata), .axi_wstrb (axi_cpu_wstrb),
        .axi_valid (axi_cpu_valid), .axi_rdata (axi_cpu_rdata), .axi_ready (axi_cpu_ready)
    );

    data_sram u_dmem (
        .clk (clk),
        .addr (sram_addr), .wdata (sram_wdata), .wstrb (sram_wstrb),
        .valid (sram_valid), .rdata (sram_rdata), .ready (sram_ready)
    );

    // ================= AXI adapter <-> interconnect =================
    logic [31:0] AWADDR, WDATA, ARADDR, RDATA;
    logic [3:0]  WSTRB;
    logic [1:0]  BRESP, RRESP;
    logic        AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY;
    logic        ARVALID, ARREADY, RVALID, RREADY;

    core_to_axi_master_adapter u_adapter (
        .clk (clk), .rst (rst),
        .cpu_addr (axi_cpu_addr), .cpu_wdata (axi_cpu_wdata), .cpu_wstrb (axi_cpu_wstrb),
        .cpu_valid (axi_cpu_valid), .cpu_rdata (axi_cpu_rdata), .cpu_ready (axi_cpu_ready),
        .AWADDR (AWADDR), .AWVALID (AWVALID), .AWREADY (AWREADY),
        .WDATA  (WDATA),  .WSTRB   (WSTRB),   .WVALID  (WVALID),  .WREADY (WREADY),
        .BRESP  (BRESP),  .BVALID  (BVALID),  .BREADY  (BREADY),
        .ARADDR (ARADDR), .ARVALID (ARVALID), .ARREADY (ARREADY),
        .RDATA  (RDATA),  .RRESP   (RRESP),   .RVALID  (RVALID),  .RREADY (RREADY)
    );

    // ================= Interconnect <-> peripherals =================
    logic [31:0] s_awaddr [NUM_SLAVES], s_wdata [NUM_SLAVES], s_araddr [NUM_SLAVES], s_rdata [NUM_SLAVES];
    logic [3:0]  s_wstrb  [NUM_SLAVES];
    logic [1:0]  s_bresp  [NUM_SLAVES], s_rresp [NUM_SLAVES];
    logic        s_awvalid [NUM_SLAVES], s_awready [NUM_SLAVES];
    logic        s_wvalid  [NUM_SLAVES], s_wready  [NUM_SLAVES];
    logic        s_bvalid  [NUM_SLAVES], s_bready  [NUM_SLAVES];
    logic        s_arvalid [NUM_SLAVES], s_arready [NUM_SLAVES];
    logic        s_rvalid  [NUM_SLAVES], s_rready  [NUM_SLAVES];

    axi4lite_interconnect #(.NUM_SLAVES(NUM_SLAVES)) u_interconnect (
        .clk (clk), .rst (rst),
        .m_awaddr (AWADDR), .m_awvalid (AWVALID), .m_awready (AWREADY),
        .m_wdata  (WDATA),  .m_wstrb   (WSTRB),   .m_wvalid  (WVALID),  .m_wready (WREADY),
        .m_bresp  (BRESP),  .m_bvalid  (BVALID),  .m_bready  (BREADY),
        .m_araddr (ARADDR), .m_arvalid (ARVALID), .m_arready (ARREADY),
        .m_rdata  (RDATA),  .m_rresp   (RRESP),   .m_rvalid  (RVALID),  .m_rready (RREADY),
        .s_awaddr (s_awaddr), .s_awvalid (s_awvalid), .s_awready (s_awready),
        .s_wdata  (s_wdata),  .s_wstrb   (s_wstrb),   .s_wvalid  (s_wvalid),  .s_wready (s_wready),
        .s_bresp  (s_bresp),  .s_bvalid  (s_bvalid),  .s_bready  (s_bready),
        .s_araddr (s_araddr), .s_arvalid (s_arvalid), .s_arready (s_arready),
        .s_rdata  (s_rdata),  .s_rresp   (s_rresp),   .s_rvalid  (s_rvalid),  .s_rready (s_rready)
    );

    // ---- Slave 0: GPIO ----
    axi4lite_gpio #(.GPIO_WIDTH(GPIO_WIDTH)) u_gpio (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[0]), .awvalid (s_awvalid[0]), .awready (s_awready[0]),
        .wdata  (s_wdata[0]),  .wstrb   (s_wstrb[0]),   .wvalid  (s_wvalid[0]),  .wready (s_wready[0]),
        .bresp  (s_bresp[0]),  .bvalid  (s_bvalid[0]),  .bready  (s_bready[0]),
        .araddr (s_araddr[0]), .arvalid (s_arvalid[0]), .arready (s_arready[0]),
        .rdata  (s_rdata[0]),  .rresp   (s_rresp[0]),   .rvalid  (s_rvalid[0]),  .rready (s_rready[0]),
        .gpio_in (gpio_in), .gpio_out (gpio_out), .gpio_dir (gpio_dir)
    );

    // ---- Slave 1: Timer ----
    axi4lite_timer u_timer (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[1]), .awvalid (s_awvalid[1]), .awready (s_awready[1]),
        .wdata  (s_wdata[1]),  .wstrb   (s_wstrb[1]),   .wvalid  (s_wvalid[1]),  .wready (s_wready[1]),
        .bresp  (s_bresp[1]),  .bvalid  (s_bvalid[1]),  .bready  (s_bready[1]),
        .araddr (s_araddr[1]), .arvalid (s_arvalid[1]), .arready (s_arready[1]),
        .rdata  (s_rdata[1]),  .rresp   (s_rresp[1]),   .rvalid  (s_rvalid[1]),  .rready (s_rready[1])
    );

    // ---- Slave 2: PWM ----
    axi4lite_pwm u_pwm (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[2]), .awvalid (s_awvalid[2]), .awready (s_awready[2]),
        .wdata  (s_wdata[2]),  .wstrb   (s_wstrb[2]),   .wvalid  (s_wvalid[2]),  .wready (s_wready[2]),
        .bresp  (s_bresp[2]),  .bvalid  (s_bvalid[2]),  .bready  (s_bready[2]),
        .araddr (s_araddr[2]), .arvalid (s_arvalid[2]), .arready (s_arready[2]),
        .rdata  (s_rdata[2]),  .rresp   (s_rresp[2]),   .rvalid  (s_rvalid[2]),  .rready (s_rready[2]),
        .pwm_out (pwm_out)
    );

    // ---- Slave 3: UART ----
    axi4lite_uart u_uart (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[3]), .awvalid (s_awvalid[3]), .awready (s_awready[3]),
        .wdata  (s_wdata[3]),  .wstrb   (s_wstrb[3]),   .wvalid  (s_wvalid[3]),  .wready (s_wready[3]),
        .bresp  (s_bresp[3]),  .bvalid  (s_bvalid[3]),  .bready  (s_bready[3]),
        .araddr (s_araddr[3]), .arvalid (s_arvalid[3]), .arready (s_arready[3]),
        .rdata  (s_rdata[3]),  .rresp   (s_rresp[3]),   .rvalid  (s_rvalid[3]),  .rready (s_rready[3]),
        .uart_tx (uart_tx), .uart_rx (uart_rx)
    );

endmodule : soc_top
