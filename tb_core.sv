
// =============================================================================
// tb_core.sv
// First end-to-end test: rv32i_core + instr_sram + data_sram, running the
// hand-assembled program in program.hex.
//
// Program (byte address : assembly : hex) -- matches program.hex exactly:
//   0x00 : LUI  x4, 0x10000       : 10000237   x4 = 0x10000000 (data SRAM base)
//   0x04 : ADDI x1, x0, 5         : 00500093   x1 = 5
//   0x08 : ADDI x2, x0, 10        : 00A00113   x2 = 10
//   0x0C : ADD  x3, x1, x2        : 002081B3   x3 = x1 + x2 = 15
//   0x10 : SW   x3, 0(x4)         : 00322023   mem[x4+0] = x3 = 15
//   0x14 : LW   x5, 0(x4)         : 00022283   x5 = mem[x4+0] = 15
//   0x18 : BEQ  x3, x5, +8        : 00518463   x3==x5==15 -> taken, skip next
//   0x1C : ADDI x6, x0, 99        : 06300313   SKIPPED -- x6 must stay 0
//   0x20 : ADDI x7, x0, 42        : 02A00393   branch target -- x7 = 42
//   0x24 : JAL  x0, 0             : 0000006F   infinite self-loop (halt)
//
// This exercises: LUI, I-type ADDI, R-type ADD, S-type SW, I-type LW,
// B-type BEQ (taken-branch skip behavior), and JAL -- one instruction from
// every RV32I format except JALR.
// =============================================================================
module tb_core;

    logic clk = 0;
    logic rst;

    logic [31:0] imem_addr, imem_rdata;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_valid, dmem_ready;

    int errors = 0;

    always #5 clk = ~clk;

    rv32i_core dut (
        .clk        (clk),
        .rst        (rst),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_wstrb (dmem_wstrb),
        .dmem_valid (dmem_valid),
        .dmem_ready (dmem_ready)
    );

    instr_sram u_imem (
        .addr  (imem_addr),
        .rdata (imem_rdata)
    );

    data_sram u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .wstrb (dmem_wstrb),
        .valid (dmem_valid),
        .rdata (dmem_rdata),
        .ready (dmem_ready)
    );

    task automatic check_reg(input [4:0] idx, input [31:0] expected, input string name);
        logic [31:0] actual;
        actual = dut.u_regfile.regs[idx];   // hierarchical peek -- TB-only, not synthesizable
        if (actual !== expected) begin
            $error("FAIL %s: expected 0x%08h got 0x%08h", name, expected, actual);
            errors++;
        end else begin
            $display("PASS %s (0x%08h)", name, actual);
        end
    endtask

    initial begin
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;

        // 9 real instructions + the self-loop -- 20 cycles is comfortable margin
        repeat (20) @(posedge clk);

        check_reg(4, 32'h1000_0000, "x4 = data SRAM base (LUI)");
        check_reg(1, 32'd5,          "x1 = 5 (ADDI)");
        check_reg(2, 32'd10,         "x2 = 10 (ADDI)");
        check_reg(3, 32'd15,         "x3 = x1+x2 (ADD)");
        check_reg(5, 32'd15,         "x5 = loaded value (LW)");
        check_reg(6, 32'd0,          "x6 = 0 (instruction skipped by taken branch)");
        check_reg(7, 32'd42,         "x7 = 42 (branch target reached)");

        if (u_dmem.mem[0] !== 32'd15) begin
            $error("FAIL data_sram[0]: expected 15 got %0d", u_dmem.mem[0]);
            errors++;
        end else begin
            $display("PASS data_sram[0] = 15 (SW committed correctly)");
        end

        if (errors == 0) begin
            $display("=== TB_CORE: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_CORE: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

endmodule : tb_core