// =============================================================================
// tb_axi_path.sv
// Self-checking testbench for core_to_axi_master_adapter + axi4lite_interconnect
// + axi4lite_dummy_slave (as slave index 0, at the GPIO address window).
//
// Drives the CPU-side bus directly (bypassing rv32i_core) to isolate and
// test the AXI logic on its own, per the architecture doc's recommendation
// to validate the AXI path against a dummy slave before real peripherals
// exist.
//
// Covers: write+readback through the AXI path, and an access to an
// unmapped address returning SLVERR without the bus ever hanging.
// =============================================================================
module tb_axi_path;
    import soc_pkg::*;

    localparam int NUM_SLAVES = 4;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    // ---- CPU-side bus (driven directly by this testbench) ----
    logic [31:0] cpu_addr;
    logic [31:0] cpu_wdata;
    logic [3:0]  cpu_wstrb;
    logic        cpu_valid;
    logic [31:0] cpu_rdata;
    logic        cpu_ready;

    // ---- AXI wires between adapter and interconnect ----
    logic [31:0] AWADDR, WDATA, ARADDR, RDATA;
    logic [3:0]  WSTRB;
    logic [1:0]  BRESP, RRESP;
    logic        AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY;
    logic        ARVALID, ARREADY, RVALID, RREADY;

    core_to_axi_master_adapter u_adapter (
        .clk       (clk),
        .rst       (rst),
        .cpu_addr  (cpu_addr),
        .cpu_wdata (cpu_wdata),
        .cpu_wstrb (cpu_wstrb),
        .cpu_valid (cpu_valid),
        .cpu_rdata (cpu_rdata),
        .cpu_ready (cpu_ready),
        .AWADDR    (AWADDR),  .AWVALID (AWVALID), .AWREADY (AWREADY),
        .WDATA     (WDATA),   .WSTRB   (WSTRB),   .WVALID  (WVALID),  .WREADY (WREADY),
        .BRESP     (BRESP),   .BVALID  (BVALID),  .BREADY  (BREADY),
        .ARADDR    (ARADDR),  .ARVALID (ARVALID), .ARREADY (ARREADY),
        .RDATA     (RDATA),   .RRESP   (RRESP),   .RVALID  (RVALID),  .RREADY (RREADY)
    );

    // ---- Slave-side arrays ----
    logic [31:0] s_awaddr  [NUM_SLAVES];
    logic        s_awvalid [NUM_SLAVES];
    logic        s_awready [NUM_SLAVES];
    logic [31:0] s_wdata   [NUM_SLAVES];
    logic [3:0]  s_wstrb   [NUM_SLAVES];
    logic        s_wvalid  [NUM_SLAVES];
    logic        s_wready  [NUM_SLAVES];
    logic [1:0]  s_bresp   [NUM_SLAVES];
    logic        s_bvalid  [NUM_SLAVES];
    logic        s_bready  [NUM_SLAVES];
    logic [31:0] s_araddr  [NUM_SLAVES];
    logic        s_arvalid [NUM_SLAVES];
    logic        s_arready [NUM_SLAVES];
    logic [31:0] s_rdata   [NUM_SLAVES];
    logic [1:0]  s_rresp   [NUM_SLAVES];
    logic        s_rvalid  [NUM_SLAVES];
    logic        s_rready  [NUM_SLAVES];

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

    // Slave index 0 (GPIO address window) = dummy slave under test.
    axi4lite_dummy_slave u_dummy (
        .clk (clk), .rst (rst),
        .awaddr (s_awaddr[0]), .awvalid (s_awvalid[0]), .awready (s_awready[0]),
        .wdata  (s_wdata[0]),  .wstrb   (s_wstrb[0]),   .wvalid  (s_wvalid[0]),  .wready (s_wready[0]),
        .bresp  (s_bresp[0]),  .bvalid  (s_bvalid[0]),  .bready  (s_bready[0]),
        .araddr (s_araddr[0]), .arvalid (s_arvalid[0]), .arready (s_arready[0]),
        .rdata  (s_rdata[0]),  .rresp   (s_rresp[0]),   .rvalid  (s_rvalid[0]),  .rready (s_rready[0])
    );

    // Slave indices 1-3 (Timer/PWM/UART) don't exist yet -- tie their
    // "outputs toward the interconnect" to safe defaults.
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
        cpu_addr  = addr;
        cpu_wdata = data;
        cpu_wstrb = 4'b1111;
        cpu_valid = 1'b1;
        wait (cpu_ready === 1'b1);
        @(negedge clk);
        cpu_valid = 1'b0;
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(negedge clk);
        cpu_addr  = addr;
        cpu_wstrb = 4'b0000;
        cpu_valid = 1'b1;
        wait (cpu_ready === 1'b1);
        data = cpu_rdata;
        @(negedge clk);
        cpu_valid = 1'b0;
    endtask

    initial begin
        rst = 1; cpu_addr = 0; cpu_wdata = 0; cpu_wstrb = 0; cpu_valid = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(negedge clk);

        // ---- Test 1: write + readback through the full AXI path ----
        axi_write(GPIO_BASE, 32'hCAFE_BABE);
        if (BRESP !== AXI_RESP_OKAY) begin
            $error("FAIL write resp: expected OKAY, got %b", BRESP);
            errors++;
        end else begin
            $display("PASS write to GPIO_BASE completed with OKAY");
        end

        begin
            logic [31:0] read_val;
            axi_read(GPIO_BASE, read_val);
            if (read_val !== 32'hCAFE_BABE || RRESP !== AXI_RESP_OKAY) begin
                $error("FAIL readback: expected 0xCAFEBABE/OKAY, got 0x%08h/%b", read_val, RRESP);
                errors++;
            end else begin
                $display("PASS readback = 0x%08h with OKAY", read_val);
            end
        end

        // ---- Test 2: unmapped address must return SLVERR, never hang ----
        axi_write(32'h2000_0000, 32'hDEAD_DEAD);   // well outside any peripheral window
        if (BRESP !== AXI_RESP_SLVERR) begin
            $error("FAIL unmapped write resp: expected SLVERR, got %b", BRESP);
            errors++;
        end else begin
            $display("PASS unmapped write correctly returned SLVERR (no hang)");
        end

        begin
            logic [31:0] dummy_val;
            axi_read(32'h2000_0000, dummy_val);
            if (RRESP !== AXI_RESP_SLVERR) begin
                $error("FAIL unmapped read resp: expected SLVERR, got %b", RRESP);
                errors++;
            end else begin
                $display("PASS unmapped read correctly returned SLVERR (no hang)");
            end
        end

        if (errors == 0) begin
            $display("=== TB_AXI_PATH: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_AXI_PATH: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    // Safety net: if any test's wait(cpu_ready) never resolves, this
    // catches a true hang instead of the simulation just running forever.
    initial begin
        #10000;
        $error("TIMEOUT: simulation did not finish in time -- likely a hang");
        $finish;
    end

endmodule : tb_axi_path
