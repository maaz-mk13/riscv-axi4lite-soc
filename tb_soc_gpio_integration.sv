
// =============================================================================
// tb_soc_gpio_integration.sv
// Lightweight integration check: core_to_axi_master_adapter + interconnect +
// REAL axi4lite_gpio (replacing the dummy slave from tb_axi_path). Drives the
// CPU-side bus directly, same as tb_axi_path did.
//
// This intentionally does NOT re-test every GPIO register in depth -- that's
// already covered by tb_gpio.sv. This only proves the full AXI chain routes
// correctly to a real peripheral end-to-end, which is the one thing tb_gpio
// (standalone) and tb_axi_path (dummy slave) couldn't prove on their own.
// =============================================================================
module tb_soc_gpio_integration;
    import soc_pkg::*;

    localparam int NUM_SLAVES = 4;
    localparam int GPIO_WIDTH = 8;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    logic [31:0] cpu_addr, cpu_wdata, cpu_rdata;
    logic [3:0]  cpu_wstrb;
    logic        cpu_valid, cpu_ready;

    logic [31:0] AWADDR, WDATA, ARADDR, RDATA;
    logic [3:0]  WSTRB;
    logic [1:0]  BRESP, RRESP;
    logic        AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY;
    logic        ARVALID, ARREADY, RVALID, RREADY;

    core_to_axi_master_adapter u_adapter (
        .clk (clk), .rst (rst),
        .cpu_addr (cpu_addr), .cpu_wdata (cpu_wdata), .cpu_wstrb (cpu_wstrb),
        .cpu_valid (cpu_valid), .cpu_rdata (cpu_rdata), .cpu_ready (cpu_ready),
        .AWADDR (AWADDR), .AWVALID (AWVALID), .AWREADY (AWREADY),
        .WDATA  (WDATA),  .WSTRB   (WSTRB),   .WVALID  (WVALID),  .WREADY (WREADY),
        .BRESP  (BRESP),  .BVALID  (BVALID),  .BREADY  (BREADY),
        .ARADDR (ARADDR), .ARVALID (ARVALID), .ARREADY (ARREADY),
        .RDATA  (RDATA),  .RRESP   (RRESP),   .RVALID  (RVALID),  .RREADY (RREADY)
    );

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

    logic [GPIO_WIDTH-1:0] gpio_in, gpio_out, gpio_dir;

    // Slave index 0 = REAL GPIO now (was axi4lite_dummy_slave in tb_axi_path).
    axi4lite_gpio #(.GPIO_WIDTH(GPIO_WIDTH)) u_gpio (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[0]), .awvalid (s_awvalid[0]), .awready (s_awready[0]),
        .wdata  (s_wdata[0]),  .wstrb   (s_wstrb[0]),   .wvalid  (s_wvalid[0]),  .wready (s_wready[0]),
        .bresp  (s_bresp[0]),  .bvalid  (s_bvalid[0]),  .bready  (s_bready[0]),
        .araddr (s_araddr[0]), .arvalid (s_arvalid[0]), .arready (s_arready[0]),
        .rdata  (s_rdata[0]),  .rresp   (s_rresp[0]),   .rvalid  (s_rvalid[0]),  .rready (s_rready[0]),
        .gpio_in (gpio_in), .gpio_out (gpio_out), .gpio_dir (gpio_dir)
    );

    genvar gi;
    generate
        for (gi = 1; gi < NUM_SLAVES; gi++) begin : gen_tie_unused
            assign s_awready[gi] = 1'b0;
            assign s_wready[gi]  = 1'b0;
            assign s_bvalid[gi]  = 1'b0;
            assign s_bresp[gi]   = 2'b00;
            assign s_arready[gi] = 1'b0;
            assign s_rvalid[gi]  = 1'b0;
            assign s_rresp[gi]   = 2'b00;
            assign s_rdata[gi]   = 32'd0;
        end
    endgenerate

    int errors = 0;

    task automatic axi_write(input [31:0] addr, input [31:0] data);
        @(negedge clk);
        cpu_addr = addr; cpu_wdata = data; cpu_wstrb = 4'b1111; cpu_valid = 1'b1;
        wait (cpu_ready === 1'b1);
        @(negedge clk);
        cpu_valid = 1'b0;
        @(negedge clk);
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(negedge clk);
        cpu_addr = addr; cpu_wstrb = 4'b0000; cpu_valid = 1'b1;
        wait (cpu_ready === 1'b1);
        data = cpu_rdata;
        @(negedge clk);
        cpu_valid = 1'b0;
        @(negedge clk);
    endtask

    initial begin
        rst = 1; cpu_addr = 0; cpu_wdata = 0; cpu_wstrb = 0; cpu_valid = 0;
        gpio_in = '0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(negedge clk);

        // Write GPIO_DATA_OUT through the FULL chain: adapter -> interconnect -> gpio
        axi_write(GPIO_BASE + GPIO_DATA_OUT, 32'h0000_005A);
        #1;
        if (gpio_out !== 8'h5A) begin
            $error("FAIL integration gpio_out: expected 0x5A got 0x%02h", gpio_out);
            errors++;
        end else begin
            $display("PASS full-chain write drove gpio_out = 0x%02h", gpio_out);
        end

        // Readback through the FULL chain
        begin
            automatic logic [31:0] rd;
            axi_read(GPIO_BASE + GPIO_DATA_OUT, rd);
            if (rd !== 32'h0000_005A) begin
                $error("FAIL integration readback: expected 0x5A got 0x%08h", rd);
                errors++;
            end else begin
                $display("PASS full-chain readback = 0x%08h", rd);
            end
        end

        if (errors == 0) begin
            $display("=== TB_SOC_GPIO_INTEGRATION: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_SOC_GPIO_INTEGRATION: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    initial begin
        #5000;
        $error("TIMEOUT: simulation did not finish in time -- likely a hang");
        $finish;
    end

endmodule : tb_soc_gpio_integration