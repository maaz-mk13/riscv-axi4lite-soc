// =============================================================================
// tb_pwm.sv
// Self-checking testbench for axi4lite_pwm.sv.
//
// Strategy: pwm_out is a real physical pin (not behind AXI), so once the
// PWM is settled into steady operation, we can sample it directly at every
// clock edge over one full known PERIOD and count high cycles -- a fully
// cycle-accurate, non-fragile check (a settled periodic square wave gives
// the exact same duty count over any complete period window).
// =============================================================================
module tb_pwm;
    import soc_pkg::*;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [3:0]  wstrb;
    logic [1:0]  bresp, rresp;
    logic        awvalid, awready, wvalid, wready, bvalid, bready;
    logic        arvalid, arready, rvalid, rready;
    logic        pwm_out;

    int errors = 0;

    axi4lite_pwm dut (
        .clk (clk), .rst (rst),
        .awaddr (awaddr), .awvalid (awvalid), .awready (awready),
        .wdata  (wdata),  .wstrb   (wstrb),   .wvalid  (wvalid),  .wready (wready),
        .bresp  (bresp),  .bvalid  (bvalid),  .bready  (bready),
        .araddr (araddr), .arvalid (arvalid), .arready (arready),
        .rdata  (rdata),  .rresp   (rresp),   .rvalid  (rvalid),  .rready (rready),
        .pwm_out (pwm_out)
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

    // Counts high cycles of pwm_out over `num_cycles` consecutive clock
    // periods, starting from the next posedge.
    task automatic count_high_cycles(input int num_cycles, output int high_count);
        high_count = 0;
        for (int i = 0; i < num_cycles; i++) begin
            @(posedge clk);
            #1;  // let pwm_out settle after the edge before sampling
            if (pwm_out) high_count++;
        end
    endtask

    initial begin
        rst = 1;
        awaddr = 0; wdata = 0; wstrb = 0; awvalid = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ---- Test 1: reset state ----
        if (pwm_out !== 1'b0) begin
            $error("FAIL reset pwm_out: expected 0 got %b", pwm_out);
            errors++;
        end else $display("PASS reset pwm_out = 0");

        // ---- Test 2: 30%% duty cycle (PERIOD=10, DUTY=3) ----
        axi_write(PWM_BASE + PWM_PERIOD, 32'd10);
        axi_write(PWM_BASE + PWM_DUTY, 32'd3);
        axi_write(PWM_BASE + PWM_CTRL, 32'h0000_0001);  // enable

        repeat (5) @(posedge clk);  // let it settle past AXI write latency

        begin
            automatic int high_count;
            count_high_cycles(10, high_count);  // exactly one full period
            if (high_count !== 3) begin
                $error("FAIL PWM duty: expected 3/10 high cycles, got %0d/10", high_count);
                errors++;
            end else begin
                $display("PASS PWM duty = %0d/10 cycles high (30%%)", high_count);
            end
        end

        // ---- Test 3: DUTY=0 clamps to always-low ----
        axi_write(PWM_BASE + PWM_DUTY, 32'd0);
        repeat (5) @(posedge clk);
        begin
            automatic int high_count;
            count_high_cycles(10, high_count);
            if (high_count !== 0) begin
                $error("FAIL PWM DUTY=0: expected 0/10 high cycles, got %0d/10", high_count);
                errors++;
            end else $display("PASS PWM DUTY=0 -> always low");
        end

        // ---- Test 4: DUTY >= PERIOD clamps to always-high ----
        axi_write(PWM_BASE + PWM_DUTY, 32'd15);  // DUTY > PERIOD(10)
        repeat (5) @(posedge clk);
        begin
            automatic int high_count;
            count_high_cycles(10, high_count);
            if (high_count !== 10) begin
                $error("FAIL PWM DUTY>=PERIOD: expected 10/10 high cycles, got %0d/10", high_count);
                errors++;
            end else $display("PASS PWM DUTY>=PERIOD -> always high (100%%)");
        end

        // ---- Test 5: PERIOD=0 edge case -- must not hang, output forced low ----
        axi_write(PWM_BASE + PWM_PERIOD, 32'd0);
        repeat (5) @(posedge clk);
        begin
            automatic int high_count;
            count_high_cycles(10, high_count);
            if (high_count !== 0) begin
                $error("FAIL PWM PERIOD=0: expected 0/10 high cycles, got %0d/10", high_count);
                errors++;
            end else $display("PASS PWM PERIOD=0 -> forced low, no hang");
        end

        // ---- Test 6: PWM_STATUS readback matches pwm_out ----
        axi_write(PWM_BASE + PWM_PERIOD, 32'd10);
        axi_write(PWM_BASE + PWM_DUTY, 32'd8);
        repeat (5) @(posedge clk);
        begin
            automatic logic [31:0] rd;
            axi_read(PWM_BASE + PWM_STATUS, rd);
            if (rd[0] !== pwm_out) begin
                $error("FAIL PWM_STATUS mismatch: reg=%b pin=%b", rd[0], pwm_out);
                errors++;
            end else $display("PASS PWM_STATUS matches pwm_out (%b)", rd[0]);
        end

        if (errors == 0) begin
            $display("=== TB_PWM: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_PWM: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    initial begin
        #10000;
        $error("TIMEOUT: simulation did not finish in time -- likely a hang");
        $finish;
    end

endmodule : tb_pwm