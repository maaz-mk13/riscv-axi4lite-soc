// =============================================================================
// tb_decode.sv  (fixed)
// Self-checking testbench for decode_unit.sv.
// Builds one instruction per format (R/I/S/B/U/J) via bit concatenation
// (never hand-computed hex) and checks every decoded field.
//
// IMPORTANT: decode_unit always slices rs2=instr[24:20] and funct7=instr[31:25]
// regardless of opcode -- that's correct RISC-V decoder behavior. For non
// R-type instructions those bit positions are actually part of the immediate
// field, NOT a meaningful rs2/funct7, so this testbench checks them against
// the real raw slice of instr rather than assuming they read as zero.
// (control_unit is the module that decides which fields matter per opcode --
// it never looks at rs2/funct7 for non R-type/shift instructions.)
// =============================================================================
module tb_decode;
    import soc_pkg::*;

    logic [31:0] instr;
    logic [6:0]  opcode, funct7;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [31:0] imm;

    int errors = 0;

    decode_unit dut (.*);

    task automatic check(
        input [6:0]  exp_opcode,
        input [4:0]  exp_rd,
        input [4:0]  exp_rs1,
        input [4:0]  exp_rs2,
        input [2:0]  exp_funct3,
        input [6:0]  exp_funct7,
        input [31:0] exp_imm,
        input string name
    );
        #1;
        if (opcode !== exp_opcode || rd !== exp_rd || rs1 !== exp_rs1 ||
            rs2 !== exp_rs2 || funct3 !== exp_funct3 || funct7 !== exp_funct7 ||
            imm !== exp_imm) begin
            $error("FAIL %s: got opcode=%b rd=%0d rs1=%0d rs2=%0d funct3=%b funct7=%b imm=0x%08h",
                    name, opcode, rd, rs1, rs2, funct3, funct7, imm);
            errors++;
        end else begin
            $display("PASS %s", name);
        end
    endtask

    initial begin
        // ---- R-type: ADD x1, x2, x3 ----
        // rs2/funct7 are genuinely meaningful here.
        instr = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, OPCODE_RTYPE};
        check(OPCODE_RTYPE, 5'd1, 5'd2, 5'd3, 3'b000, 7'b0000000, 32'd0, "R-type ADD");

        // ---- I-type: ADDI x5, x6, -4 ----
        // rs2/funct7 are NOT meaningful (they're part of imm) -- check against
        // the actual raw slice, instr[24:20] / instr[31:25].
        instr = {12'hFFC, 5'd6, 3'b000, 5'd5, OPCODE_ITYPE};
        check(OPCODE_ITYPE, 5'd5, 5'd6, instr[24:20], 3'b000, instr[31:25],
              32'hFFFF_FFFC, "I-type ADDI (-4)");

        // ---- S-type: SW x2, 8(x1) ----
        // rs2 IS meaningful for stores (it's the data source) -- funct7
        // position is not used by S-type, check raw slice.
        instr = {7'b0000000, 5'd2, 5'd1, 3'b010, 5'b01000, OPCODE_STORE};
        check(OPCODE_STORE, instr[11:7], 5'd1, 5'd2, 3'b010, instr[31:25], 32'd8, "S-type SW");

        // ---- B-type: BEQ x3, x4, +16 ----
        // rs2 IS meaningful for branches (second compare operand).
        begin
            automatic logic [31:0] beq_imm = 32'd16;
            instr = {beq_imm[12], beq_imm[10:5], 5'd4, 5'd3, 3'b000,
                     beq_imm[4:1], beq_imm[11], OPCODE_BRANCH};
            check(OPCODE_BRANCH, instr[11:7], 5'd3, 5'd4, 3'b000, instr[31:25], beq_imm,
                  "B-type BEQ (+16)");
        end

        // ---- U-type: LUI x7, 0x12345 ----
        // rs1/rs2/funct3/funct7 positions are all part of the imm[31:12] field.
        instr = {20'h12345, 5'd7, OPCODE_LUI};
        check(OPCODE_LUI, 5'd7, instr[19:15], instr[24:20], instr[14:12],
              instr[31:25], 32'h1234_5000, "U-type LUI");

        // ---- J-type: JAL x1, +32 ----
        // Same story -- rs1/rs2/funct3/funct7 positions are part of imm.
        begin
            automatic logic [31:0] jal_imm = 32'd32;
            instr = {jal_imm[20], jal_imm[10:1], jal_imm[11], jal_imm[19:12],
                     5'd1, OPCODE_JAL};
            check(OPCODE_JAL, 5'd1, instr[19:15], instr[24:20], instr[14:12],
                  instr[31:25], jal_imm, "J-type JAL (+32)");
        end

        if (errors == 0) begin
            $display("=== TB_DECODE: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_DECODE: %0d ERROR(S) ===", errors);
        end

        $finish;
    end

endmodule : tb_decode