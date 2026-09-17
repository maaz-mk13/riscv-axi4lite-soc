// =============================================================================
// tb_soc_top.sv
// First full-system test: rv32i_core running real instructions that reach
// all the way out to a physical GPIO pin, through every module built so
// far -- core -> data_bus_decoder -> AXI adapter -> interconnect -> GPIO.
//
// Program (program_soc_top.hex):
//   0x00 : LUI  x4, 0x40000  : x4 = 0x40000000 (GPIO_BASE)
//   0x04 : ADDI x1, x0, 0x55 : x1 = 0x55
//   0x08 : SW   x1, 0(x4)    : GPIO_DATA_OUT = 0x55   (write through the FULL chain)
//   0x0C : LW   x5, 0(x4)    : x5 = GPIO_DATA_OUT      (readback through the FULL chain)
//   0x10 : JAL  x0, 0        : infinite self-loop (halt)
//
// This is intentionally a small, focused proof -- deep GPIO register
// behavior is already covered by tb_gpio.sv. This test proves the whole
// system moves data correctly end-to-end via real CPU instructions, which
// none of the earlier per-module or per-peripheral tests could prove alone.
// =============================================================================
module tb_soc_top;
    import soc_pkg::*;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    logic [7:0] gpio_in, gpio_out, gpio_dir;
    logic       pwm_out;
    logic       uart_tx, uart_rx;

    int errors = 0;

    soc_top #(.IMEM_INIT_FILE("program_soc_top.hex")) dut (
        .clk (clk), .rst (rst),
        .gpio_in (gpio_in), .gpio_out (gpio_out), .gpio_dir (gpio_dir),
        .pwm_out (pwm_out),
        .uart_tx (uart_tx), .uart_rx (uart_rx)
    );

    task automatic check_reg(input [4:0] idx, input [31:0] expected, input string name);
        logic [31:0] actual;
        actual = dut.u_core.u_regfile.regs[idx];  // hierarchical peek, TB-only
        if (actual !== expected) begin
            $error("FAIL %s: expected 0x%08h got 0x%08h", name, expected, actual);
            errors++;
        end else begin
            $display("PASS %s (0x%08h)", name, actual);
        end
    endtask

    initial begin
        rst = 1;
        gpio_in = '0;
        uart_rx = 1'b1;  // idle
        repeat (2) @(posedge clk);
        rst = 0;

        // Generous margin: 4 real instructions, 2 of which are full AXI
        // round-trips through adapter+interconnect+GPIO (each taking
        // several cycles), plus the FSM setup latency on each side.
        repeat (100) @(posedge clk);

        check_reg(4, 32'h4000_0000, "x4 = GPIO_BASE (LUI)");
        check_reg(1, 32'h0000_0055, "x1 = 0x55 (ADDI)");
        check_reg(5, 32'h0000_0055, "x5 = GPIO readback (LW, full AXI chain)");

        if (gpio_out !== 8'h55) begin
            $error("FAIL gpio_out physical pin: expected 0x55 got 0x%02h", gpio_out);
            errors++;
        end else begin
            $display("PASS gpio_out physical pin = 0x%02h (CPU instruction reached the real pin)", gpio_out);
        end

        if (errors == 0) begin
            $display("=== TB_SOC_TOP: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_SOC_TOP: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    initial begin
        #20000;
        $error("TIMEOUT: simulation did not finish in time -- likely a hang");
        $finish;
    end

endmodule : tb_soc_top
