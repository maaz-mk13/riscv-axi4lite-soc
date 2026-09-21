// =============================================================================
// tb_uvm_top.sv
// Top-level UVM testbench. DUT = core_to_axi_master_adapter +
// axi4lite_interconnect + all 4 REAL peripherals (GPIO, Timer, PWM, UART).
// UVM drives cpu_bus_if, acting as a virtual CPU -- the same interface
// rv32i_core itself drives in the full soc_top.
// =============================================================================
`include "uvm_macros.svh"
import uvm_pkg::*;
import soc_pkg::*;
import axi_test_pkg::*;

module tb_uvm_top;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    cpu_bus_if bus_if (.clk(clk), .rst(rst));

    // ================= DUT: adapter =================
    logic [31:0] AWADDR, WDATA, ARADDR, RDATA;
    logic [3:0]  WSTRB;
    logic [1:0]  BRESP, RRESP;
    logic        AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY;
    logic        ARVALID, ARREADY, RVALID, RREADY;

    core_to_axi_master_adapter u_adapter (
        .clk (clk), .rst (rst),
        .cpu_addr (bus_if.addr), .cpu_wdata (bus_if.wdata), .cpu_wstrb (bus_if.wstrb),
        .cpu_valid (bus_if.valid), .cpu_rdata (bus_if.rdata), .cpu_ready (bus_if.ready),
        .AWADDR (AWADDR), .AWVALID (AWVALID), .AWREADY (AWREADY),
        .WDATA  (WDATA),  .WSTRB   (WSTRB),   .WVALID  (WVALID),  .WREADY (WREADY),
        .BRESP  (BRESP),  .BVALID  (BVALID),  .BREADY  (BREADY),
        .ARADDR (ARADDR), .ARVALID (ARVALID), .ARREADY (ARREADY),
        .RDATA  (RDATA),  .RRESP   (RRESP),   .RVALID  (RVALID),  .RREADY (RREADY)
    );

    // ================= DUT: interconnect =================
    localparam int NUM_SLAVES = 4;

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

    // ================= DUT: all 4 real peripherals =================
    logic [7:0] gpio_in, gpio_out, gpio_dir;
    logic       pwm_out;
    logic       uart_tx, uart_rx;

    axi4lite_gpio #(.GPIO_WIDTH(8)) u_gpio (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[0]), .awvalid (s_awvalid[0]), .awready (s_awready[0]),
        .wdata  (s_wdata[0]),  .wstrb   (s_wstrb[0]),   .wvalid  (s_wvalid[0]),  .wready (s_wready[0]),
        .bresp  (s_bresp[0]),  .bvalid  (s_bvalid[0]),  .bready  (s_bready[0]),
        .araddr (s_araddr[0]), .arvalid (s_arvalid[0]), .arready (s_arready[0]),
        .rdata  (s_rdata[0]),  .rresp   (s_rresp[0]),   .rvalid  (s_rvalid[0]),  .rready (s_rready[0]),
        .gpio_in (gpio_in), .gpio_out (gpio_out), .gpio_dir (gpio_dir)
    );

    axi4lite_timer u_timer (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[1]), .awvalid (s_awvalid[1]), .awready (s_awready[1]),
        .wdata  (s_wdata[1]),  .wstrb   (s_wstrb[1]),   .wvalid  (s_wvalid[1]),  .wready (s_wready[1]),
        .bresp  (s_bresp[1]),  .bvalid  (s_bvalid[1]),  .bready  (s_bready[1]),
        .araddr (s_araddr[1]), .arvalid (s_arvalid[1]), .arready (s_arready[1]),
        .rdata  (s_rdata[1]),  .rresp   (s_rresp[1]),   .rvalid  (s_rvalid[1]),  .rready (s_rready[1])
    );

    axi4lite_pwm u_pwm (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[2]), .awvalid (s_awvalid[2]), .awready (s_awready[2]),
        .wdata  (s_wdata[2]),  .wstrb   (s_wstrb[2]),   .wvalid  (s_wvalid[2]),  .wready (s_wready[2]),
        .bresp  (s_bresp[2]),  .bvalid  (s_bvalid[2]),  .bready  (s_bready[2]),
        .araddr (s_araddr[2]), .arvalid (s_arvalid[2]), .arready (s_arready[2]),
        .rdata  (s_rdata[2]),  .rresp   (s_rresp[2]),   .rvalid  (s_rvalid[2]),  .rready (s_rready[2]),
        .pwm_out (pwm_out)
    );

    axi4lite_uart u_uart (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[3]), .awvalid (s_awvalid[3]), .awready (s_awready[3]),
        .wdata  (s_wdata[3]),  .wstrb   (s_wstrb[3]),   .wvalid  (s_wvalid[3]),  .wready (s_wready[3]),
        .bresp  (s_bresp[3]),  .bvalid  (s_bvalid[3]),  .bready  (s_bready[3]),
        .araddr (s_araddr[3]), .arvalid (s_arvalid[3]), .arready (s_arready[3]),
        .rdata  (s_rdata[3]),  .rresp   (s_rresp[3]),   .rvalid  (s_rvalid[3]),  .rready (s_rready[3]),
        .uart_tx (uart_tx), .uart_rx (uart_rx)
    );

    // ================= Clock / reset / UVM launch =================
    initial begin
        rst = 1'b1;
        gpio_in = '0;
        uart_rx = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
    end

    initial begin
        uvm_config_db#(virtual cpu_bus_if.driver)::set(null, "uvm_test_top.env.agent.driver", "vif", bus_if);
        uvm_config_db#(virtual cpu_bus_if.monitor)::set(null, "uvm_test_top.env.agent.monitor", "vif", bus_if);
        run_test("base_test");
    end

endmodule : tb_uvm_top
