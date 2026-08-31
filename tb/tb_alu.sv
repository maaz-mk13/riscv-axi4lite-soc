
// =============================================================================
// tb_alu.sv
// Self-checking testbench for alu.sv ? one directed vector per operation,
// plus signed/unsigned edge cases for SLT/SLTU.
// =============================================================================
module tb_alu;
    import soc_pkg::*;

    logic [31:0] a, b, result;
    alu_op_e     op;
    logic        zero;
    int          errors = 0;

    alu dut (.*);

    task automatic check(
        input [31:0]  av,
        input [31:0]  bv,
        input alu_op_e opv,
        input [31:0]  expected,
        input string  name
    );
        a = av; b = bv; op = opv;
        #1;
        if (result !== expected) begin
            $error("FAIL %s: a=0x%08h b=0x%08h expected=0x%08h got=0x%08h",
                    name, av, bv, expected, result);
            errors++;
        end else begin
            $display("PASS %s", name);
        end
    endtask

    initial begin
        check(32'd10,        32'd5,        ALU_ADD,  32'd15,       "ADD");
        check(32'd10,        32'd5,        ALU_SUB,  32'd5,        "SUB");
        check(32'hFF00_FF00, 32'h0F0F_0F0F, ALU_AND,  32'h0F00_0F00, "AND");
        check(32'hF000_0000, 32'h0000_000F, ALU_OR,   32'hF000_000F, "OR");
        check(32'hFFFF_FFFF, 32'h0000_FFFF, ALU_XOR,  32'hFFFF_0000, "XOR");
        check(32'h0000_0001, 32'd4,         ALU_SLL,  32'h0000_0010, "SLL");
        check(32'h8000_0000, 32'd4,         ALU_SRL,  32'h0800_0000, "SRL");
        check(32'h8000_0000, 32'd4,         ALU_SRA,  32'hF800_0000, "SRA (sign-extend)");
        check(32'hFFFF_FFFB, 32'd3,         ALU_SLT,  32'd1,        "SLT (-5 < 3)");
        check(32'd3,         32'd5,         ALU_SLT,  32'd1,        "SLT (3 < 5)");
        check(32'd5,         32'd3,         ALU_SLT,  32'd0,        "SLT (5 < 3 false)");
        check(32'hFFFF_FFFF, 32'd1,         ALU_SLTU, 32'd0,        "SLTU (0xFFFFFFFF < 1 unsigned = false)");
        check(32'd1,         32'hFFFF_FFFF, ALU_SLTU, 32'd1,        "SLTU (1 < 0xFFFFFFFF unsigned = true)");

        if (errors == 0) begin
            $display("=== TB_ALU: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_ALU: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

endmodule : tb_alu