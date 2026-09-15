// =============================================================================
// tb_timer.sv
// Self-checking testbench for axi4lite_timer.sv.
//
// Strategy note: rather than asserting the counter's exact value at exact
// cycle counts (fragile -- depends on precise AXI transaction latency),
// this test waits a generous number of cycles then checks settled/final
// state, and separately proves the counter is genuinely running (not
// frozen) by sampling it twice and checking the value actually changed.
// This is deterministic and robust without over-fitting to AXI timing.
// =============================================================================
module tb_timer;
    import soc_pkg::*;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0]  wstrb;
    logic [1:0]  bresp, rresp;
    logic        awvalid, awready, wvalid, wready, bvalid, bready;
    logic        arvalid, arready, rvalid, rready;

    int errors = 0;

    axi4lite_timer dut (
        .clk (clk), .rst (rst),
        .awaddr (awaddr), .awvalid (awvalid), .awready (awready),
        .wdata  (wdata),  .wstrb   (wstrb),   .wvalid  (wvalid),  .wready (wready),
        .bresp  (bresp),  .bvalid  (bvalid),  .bready  (bready),
        .araddr (araddr), .arvalid (arvalid), .arready (arready),
        .rdata  (rdata),  .rresp   (rresp),   .rvalid  (rvalid),  .rready (rready)
    );

    task automatic axi_write(input [31:0] addr, input [31:0] data);
        awaddr = addr; wdata = data; wstrb = 4'b1111;
        awvalid = 1'b1; wvalid = 1'b1; bready = 1'b1;
        @(posedge clk);
        while (!bvalid) @(posedge clk);
        awvalid = 1'b0; wvalid = 1'b0; bready = 1'b0;
        @(posedge clk);
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        araddr = addr; arvalid = 1'b1; rready = 1'b1;
        @(posedge clk);
        while (!rvalid) @(posedge clk);
        data = rdata;
        arvalid = 1'b0; rready = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        rst = 1;
        awaddr = 0; wdata = 0; wstrb = 0; awvalid = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ---- Test 1: reset state ----
        begin
            automatic logic [31:0] rd;
            axi_read(TIMER_BASE + TIMER_COUNT, rd);
            if (rd !== 32'd0) begin
                $error("FAIL reset COUNT: expected 0 got %0d", rd);
                errors++;
            end else $display("PASS reset COUNT = 0");
        end

        // ---- Test 2: one-shot mode counts down and expires ----
        axi_write(TIMER_BASE + TIMER_LOAD, 32'd10);
        axi_write(TIMER_BASE + TIMER_CTRL, 32'h0000_0001);  // enable=1, mode=0 (one-shot)

        repeat (20) @(posedge clk);  // generous margin past the 10-cycle countdown

        begin
            automatic logic [31:0] rd;
            axi_read(TIMER_BASE + TIMER_COUNT, rd);
            if (rd !== 32'd0) begin
                $error("FAIL one-shot settled COUNT: expected 0 got %0d", rd);
                errors++;
            end else $display("PASS one-shot COUNT settled at 0");
        end

        begin
            automatic logic [31:0] rd;
            axi_read(TIMER_BASE + TIMER_STATUS, rd);
            if (rd[0] !== 1'b1) begin
                $error("FAIL one-shot STATUS: expected expired=1 got %0d", rd[0]);
                errors++;
            end else $display("PASS one-shot STATUS expired=1");
        end

        // ---- Test 3: RW1C clear ----
        axi_write(TIMER_BASE + TIMER_STATUS, 32'h0000_0001);  // write 1 to clear
        begin
            automatic logic [31:0] rd;
            axi_read(TIMER_BASE + TIMER_STATUS, rd);
            if (rd[0] !== 1'b0) begin
                $error("FAIL STATUS clear: expected expired=0 got %0d", rd[0]);
                errors++;
            end else $display("PASS STATUS cleared to 0");
        end

        // ---- Test 4: periodic mode -- counter genuinely runs and wraps ----
        axi_write(TIMER_BASE + TIMER_CTRL, 32'h0000_0000);   // disable first
        axi_write(TIMER_BASE + TIMER_LOAD, 32'd4);
        axi_write(TIMER_BASE + TIMER_CTRL, 32'h0000_0003);   // enable=1, mode=1 (periodic)

        repeat (10) @(posedge clk);  // let it settle into steady periodic operation

        begin
            automatic logic [31:0] rd1, rd2;
            axi_read(TIMER_BASE + TIMER_COUNT, rd1);
            axi_read(TIMER_BASE + TIMER_COUNT, rd2);  // second read -- several cycles later

            if (rd1 > 32'd4 || rd2 > 32'd4) begin
                $error("FAIL periodic COUNT out of range: rd1=%0d rd2=%0d (LOAD=4)", rd1, rd2);
                errors++;
            end else if (rd1 == rd2) begin
                $error("FAIL periodic COUNT frozen: both reads returned %0d -- counter not running?", rd1);
                errors++;
            end else begin
                $display("PASS periodic COUNT changed between reads (%0d -> %0d), counter is running", rd1, rd2);
            end
        end

        repeat (10) @(posedge clk);  // ensure at least one full period elapsed
        begin
            automatic logic [31:0] rd;
            axi_read(TIMER_BASE + TIMER_STATUS, rd);
            if (rd[0] !== 1'b1) begin
                $error("FAIL periodic STATUS: expected expired=1 after a full period, got %0d", rd[0]);
                errors++;
            end else $display("PASS periodic STATUS expired=1 after wraparound");
        end

        if (errors == 0) begin
            $display("=== TB_TIMER: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_TIMER: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    initial begin
        #10000;
        $error("TIMEOUT: simulation did not finish in time -- likely a hang");
        $finish;
    end

endmodule : tb_timer
