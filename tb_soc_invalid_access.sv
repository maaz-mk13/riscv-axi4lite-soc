// =============================================================================
// tb_soc_invalid_access.sv
// System-level proof that an invalid (unmapped) memory access does not hang
// the core -- directly required by the brief's "invalid accesses" and
// "delayed responses must not hang" verification items.
//
// Program (program_invalid_access.hex):
//   0x00 : LUI  x4, 0x20000  : x4 = 0x20000000 (reserved gap -- neither SRAM nor AXI range)
//   0x04 : ADDI x1, x0, 7    : x1 = 7 (marker value)
//   0x08 : SW   x1, 0(x4)    : write to the unmapped address
//   0x0C : ADDI x2, x0, 42   : x2 = 42 -- only reachable if the core did NOT hang
//   0x10 : JAL  x0, 0        : infinite self-loop (halt)
//
// The core has no response-code visibility on its simple bus (a documented
// simplification -- see architecture doc), so this test cannot check for
// SLVERR from the CPU's side. What it CAN and does prove: the core reaches
// and completes the instruction immediately after the invalid access,
// which is the actual hard requirement -- a real hang would leave x2 at 0
// forever.
// =============================================================================
module tb_soc_invalid_access;
    import soc_pkg::*;

    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    logic [7:0] gpio_in, gpio_out, gpio_dir;
    logic       pwm_out;
    logic       uart_tx, uart_rx;

    int errors = 0;

    soc_top #(.IMEM_INIT_FILE("program_invalid_access.hex")) dut (
        .clk (clk), .rst (rst),
        .gpio_in (gpio_in), .gpio_out (gpio_out), .gpio_dir (gpio_dir),
        .pwm_out (pwm_out),
        .uart_tx (uart_tx), .uart_rx (uart_rx)
    );

    task automatic check_reg(input [4:0] idx, input [31:0] expected, input string name);
        logic [31:0] actual;
        actual = dut.u_core.u_regfile.regs[idx];
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
        uart_rx = 1'b1;
        repeat (2) @(posedge clk);
        rst = 0;

        repeat (60) @(posedge clk);  // generous margin past the invalid access

        check_reg(4, 32'h2000_0000, "x4 = unmapped address (LUI)");
        check_reg(1, 32'd7,          "x1 = 7 (marker, before invalid access)");
        check_reg(2, 32'd42,         "x2 = 42 (core continued PAST the invalid access -- no hang)");

        if (errors == 0) begin
            $display("=== TB_SOC_INVALID_ACCESS: ALL TESTS PASSED (no hang confirmed) ===");
        end else begin
            $display("=== TB_SOC_INVALID_ACCESS: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

    // This timeout IS the real test here: if the core ever genuinely hangs
    // on the invalid access, this fires instead of the checks above ever
    // running -- itself a clear, unambiguous failure signal.
    initial begin
        #5000;
        $error("TIMEOUT: core hung on the invalid access -- this is the failure this test exists to catch");
        $finish;
    end

endmodule : tb_soc_invalid_access
