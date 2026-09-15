// =============================================================================
// tb_gpio.sv
// Standalone self-checking testbench for axi4lite_gpio.sv.
// Drives the AXI4-Lite slave ports directly (same style as tb_axi_path),
// isolating GPIO behavior from the rest of the AXI subsystem.
//
// Covers: DATA_OUT write+readback, DIR write+readback, DATA_IN reflecting
// external pins (through the 2-flop synchronizer), STATUS reading zero,
// and gpio_out/gpio_dir actually driving to the correct values.
// =============================================================================
module tb_gpio;
    import soc_pkg::*;

    localparam int GPIO_WIDTH = 8;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0]  wstrb;
    logic [1:0]  bresp, rresp;
    logic        awvalid, awready, wvalid, wready, bvalid, bready;
    logic        arvalid, arready, rvalid, rready;

    logic [GPIO_WIDTH-1:0] gpio_in;
    logic [GPIO_WIDTH-1:0] gpio_out;
    logic [GPIO_WIDTH-1:0] gpio_dir;

    int errors = 0;

    axi4lite_gpio #(.GPIO_WIDTH(GPIO_WIDTH)) dut (
        .clk (clk), .rst (rst),
        .awaddr (awaddr), .awvalid (awvalid), .awready (awready),
        .wdata  (wdata),  .wstrb   (wstrb),   .wvalid  (wvalid),  .wready (wready),
        .bresp  (bresp),  .bvalid  (bvalid),  .bready  (bready),
        .araddr (araddr), .arvalid (arvalid), .arready (arready),
        .rdata  (rdata),  .rresp   (rresp),   .rvalid  (rvalid),  .rready (rready),
        .gpio_in (gpio_in), .gpio_out (gpio_out), .gpio_dir (gpio_dir)
    );

    task automatic axi_write(input [31:0] addr, input [31:0] data);
        awaddr  = addr;
        wdata   = data;
        wstrb   = 4'b1111;
        awvalid = 1'b1;
        wvalid  = 1'b1;
        bready  = 1'b1;
        @(posedge clk);
        while (!bvalid) @(posedge clk);   // sample only on clock edges, no mid-cycle race
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        @(posedge clk);                   // guaranteed idle cycle -- DUT fully settles to IDLE
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data, output [1:0] resp);
        araddr  = addr;
        arvalid = 1'b1;
        rready  = 1'b1;
        @(posedge clk);
        while (!rvalid) @(posedge clk);
        data = rdata;
        resp = rresp;
        arvalid = 1'b0;
        rready  = 1'b0;
        @(posedge clk);                   // guaranteed idle cycle -- DUT fully settles to IDLE
    endtask

    initial begin
        rst = 1;
        awaddr = 0; wdata = 0; wstrb = 0; awvalid = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;
        gpio_in = '0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(negedge clk);

        // ---- Test 1: GPIO_DATA_OUT write + readback ----
        axi_write(GPIO_BASE + GPIO_DATA_OUT, 32'h0000_00A5);
        begin
            automatic logic [31:0] rd; automatic logic [1:0] rp;
            axi_read(GPIO_BASE + GPIO_DATA_OUT, rd, rp);
            if (rd !== 32'h0000_00A5 || rp !== AXI_RESP_OKAY) begin
                $error("FAIL GPIO_DATA_OUT readback: got 0x%08h resp=%b", rd, rp);
                errors++;
            end else $display("PASS GPIO_DATA_OUT readback = 0x%08h", rd);
        end

        // gpio_out should reflect the written value on the physical pins
        #1;
        if (gpio_out !== 8'hA5) begin
            $error("FAIL gpio_out: expected 0xA5 got 0x%02h", gpio_out);
            errors++;
        end else $display("PASS gpio_out = 0x%02h", gpio_out);

        // ---- Test 2: GPIO_DIR write + readback ----
        axi_write(GPIO_BASE + GPIO_DIR, 32'h0000_00FF);  // all pins as outputs
        begin
            automatic logic [31:0] rd; automatic logic [1:0] rp;
            axi_read(GPIO_BASE + GPIO_DIR, rd, rp);
            if (rd !== 32'h0000_00FF || rp !== AXI_RESP_OKAY) begin
                $error("FAIL GPIO_DIR readback: got 0x%08h resp=%b", rd, rp);
                errors++;
            end else $display("PASS GPIO_DIR readback = 0x%08h", rd);
        end

        #1;
        if (gpio_dir !== 8'hFF) begin
            $error("FAIL gpio_dir: expected 0xFF got 0x%02h", gpio_dir);
            errors++;
        end else $display("PASS gpio_dir = 0x%02h", gpio_dir);

        // ---- Test 3: GPIO_DATA_IN reflects external pins (through sync) ----
        gpio_in = 8'h3C;
        repeat (3) @(posedge clk);  // allow the 2-flop synchronizer to settle
        begin
            automatic logic [31:0] rd; automatic logic [1:0] rp;
            axi_read(GPIO_BASE + GPIO_DATA_IN, rd, rp);
            if (rd !== 32'h0000_003C || rp !== AXI_RESP_OKAY) begin
                $error("FAIL GPIO_DATA_IN: got 0x%08h resp=%b", rd, rp);
                errors++;
            end else $display("PASS GPIO_DATA_IN = 0x%08h", rd);
        end

        // ---- Test 4: GPIO_STATUS always reads zero ----
        begin
            automatic logic [31:0] rd; automatic logic [1:0] rp;
            axi_read(GPIO_BASE + GPIO_STATUS, rd, rp);
            if (rd !== 32'd0 || rp !== AXI_RESP_OKAY) begin
                $error("FAIL GPIO_STATUS: got 0x%08h resp=%b", rd, rp);
                errors++;
            end else $display("PASS GPIO_STATUS = 0");
        end

        if (errors == 0) begin
            $display("=== TB_GPIO: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_GPIO: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    initial begin
        #5000;
        $error("TIMEOUT: simulation did not finish in time -- likely a hang");
        $finish;
    end

endmodule : tb_gpio
