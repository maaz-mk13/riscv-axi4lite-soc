
// =============================================================================
// tb_control.sv
// Self-checking testbench for control_unit.sv.
// One directed case per instruction category, checking every control output.
// =============================================================================
module tb_control;
    import soc_pkg::*;

    logic [6:0] opcode, funct7;
    logic [2:0] funct3;

    logic       reg_write, alu_src, mem_read, mem_write;
    logic [1:0] result_src;
    logic       branch, jump, jalr, auipc;
    alu_op_e    alu_op;

    int errors = 0;

    control_unit dut (.*);

    task automatic check(
        input logic       exp_reg_write,
        input logic       exp_alu_src,
        input logic       exp_mem_read,
        input logic       exp_mem_write,
        input logic [1:0] exp_result_src,
        input logic       exp_branch,
        input logic       exp_jump,
        input logic       exp_jalr,
        input logic       exp_auipc,
        input alu_op_e    exp_alu_op,
        input string      name
    );
        #1;
        if (reg_write !== exp_reg_write || alu_src !== exp_alu_src ||
            mem_read !== exp_mem_read || mem_write !== exp_mem_write ||
            result_src !== exp_result_src || branch !== exp_branch ||
            jump !== exp_jump || jalr !== exp_jalr || auipc !== exp_auipc ||
            alu_op !== exp_alu_op) begin
            $error("FAIL %s: reg_write=%b alu_src=%b mem_read=%b mem_write=%b result_src=%b branch=%b jump=%b jalr=%b auipc=%b alu_op=%s",
                    name, reg_write, alu_src, mem_read, mem_write, result_src,
                    branch, jump, jalr, auipc, alu_op.name());
            errors++;
        end else begin
            $display("PASS %s", name);
        end
    endtask

    initial begin
        // R-type ADD (funct7=0000000, funct3=000)
        opcode = OPCODE_RTYPE; funct3 = 3'b000; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_ADD, "R-type ADD");

        // R-type SUB (funct7=0100000, funct3=000)
        opcode = OPCODE_RTYPE; funct3 = 3'b000; funct7 = 7'b0100000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SUB, "R-type SUB");
        // R-type AND
        opcode = OPCODE_RTYPE; funct3 = 3'b111; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_AND, "R-type AND");

        // R-type OR
        opcode = OPCODE_RTYPE; funct3 = 3'b110; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_OR, "R-type OR");

        // R-type XOR
        opcode = OPCODE_RTYPE; funct3 = 3'b100; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_XOR, "R-type XOR");

        // R-type SLL
        opcode = OPCODE_RTYPE; funct3 = 3'b001; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SLL, "R-type SLL");

        // R-type SRL
        opcode = OPCODE_RTYPE; funct3 = 3'b101; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SRL, "R-type SRL");

        // R-type SRA
        opcode = OPCODE_RTYPE; funct3 = 3'b101; funct7 = 7'b0100000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SRA, "R-type SRA");

        // R-type SLT
        opcode = OPCODE_RTYPE; funct3 = 3'b010; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SLT, "R-type SLT");

        // R-type SLTU
        opcode = OPCODE_RTYPE; funct3 = 3'b011; funct7 = 7'b0000000;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SLTU, "R-type SLTU");

        // I-type ADDI
        opcode = OPCODE_ITYPE; funct3 = 3'b000; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_ADD, "I-type ADDI");
        // I-type SLTI
        opcode = OPCODE_ITYPE; funct3 = 3'b010; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SLT, "I-type SLTI");

        // I-type SLTIU
        opcode = OPCODE_ITYPE; funct3 = 3'b011; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SLTU, "I-type SLTIU");

        // I-type XORI
        opcode = OPCODE_ITYPE; funct3 = 3'b100; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_XOR, "I-type XORI");

        // I-type ORI
        opcode = OPCODE_ITYPE; funct3 = 3'b110; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_OR, "I-type ORI");

        // I-type ANDI
        opcode = OPCODE_ITYPE; funct3 = 3'b111; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_AND, "I-type ANDI");

        // I-type SLLI
        opcode = OPCODE_ITYPE; funct3 = 3'b001; funct7 = 7'b0000000;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SLL, "I-type SLLI");

        // I-type SRLI
        opcode = OPCODE_ITYPE; funct3 = 3'b101; funct7 = 7'b0000000;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SRL, "I-type SRLI");

        // I-type SRAI
        opcode = OPCODE_ITYPE; funct3 = 3'b101; funct7 = 7'b0100000;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 0, ALU_SRA, "I-type SRAI");

        // LOAD (LW)
        opcode = OPCODE_LOAD; funct3 = 3'b010; funct7 = 7'd0;
        check(1, 1, 1, 0, RESULT_MEM, 0, 0, 0, 0, ALU_ADD, "LOAD LW");

        // STORE (SW)
        opcode = OPCODE_STORE; funct3 = 3'b010; funct7 = 7'd0;
        check(0, 1, 0, 1, RESULT_ALU, 0, 0, 0, 0, ALU_ADD, "STORE SW");

        // BRANCH BEQ
        opcode = OPCODE_BRANCH; funct3 = 3'b000; funct7 = 7'd0;
        check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0, ALU_SUB, "BRANCH BEQ");

        // BRANCH BLT
        opcode = OPCODE_BRANCH; funct3 = 3'b100; funct7 = 7'd0;
        check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0, ALU_SLT, "BRANCH BLT");

        // JAL
        opcode = OPCODE_JAL; funct3 = 3'd0; funct7 = 7'd0;
        check(1, 0, 0, 0, RESULT_PC4, 0, 1, 0, 0, ALU_ADD, "JAL");

        // JALR
        opcode = OPCODE_JALR; funct3 = 3'b000; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_PC4, 0, 0, 1, 0, ALU_ADD, "JALR");

        // LUI
        opcode = OPCODE_LUI; funct3 = 3'd0; funct7 = 7'd0;
        check(1, 0, 0, 0, RESULT_IMM, 0, 0, 0, 0, ALU_ADD, "LUI");

        // AUIPC
        opcode = OPCODE_AUIPC; funct3 = 3'd0; funct7 = 7'd0;
        check(1, 1, 0, 0, RESULT_ALU, 0, 0, 0, 1, ALU_ADD, "AUIPC");

      

        // Invalid R-type encoding -> default ALU_ADD
        opcode = OPCODE_RTYPE;
        funct3 = 3'b000;
        funct7 = 7'b1111111;
        check(1, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0,
              ALU_ADD, "R-type invalid encoding");

        // Invalid opcode -> default NOP
        opcode = 7'b1111111;
        funct3 = 3'b000;
        funct7 = 7'b0000000;
        check(0, 0, 0, 0, RESULT_ALU, 0, 0, 0, 0,
              ALU_ADD, "Invalid opcode");

        // Branch BLT
        opcode = OPCODE_BRANCH;
        funct3 = 3'b100;
        funct7 = 7'd0;
        check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0,
              ALU_SLT, "Branch BLT");

        // Branch BGE
        opcode = OPCODE_BRANCH;
        funct3 = 3'b101;
        funct7 = 7'd0;
        check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0,
              ALU_SLT, "Branch BGE");
// Branch BLTU
opcode = OPCODE_BRANCH;
funct3 = 3'b110;
funct7 = 7'd0;
check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0,
      ALU_SLTU, "Branch BLTU");

// Branch BGEU
opcode = OPCODE_BRANCH;
funct3 = 3'b111;
funct7 = 7'd0;
check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0,
      ALU_SLTU, "Branch BGEU");
// Invalid branch funct3 -> default ALU_SUB
opcode = OPCODE_BRANCH;
funct3 = 3'b010;
funct7 = 7'd0;
check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0,
      ALU_SUB, "Invalid branch funct3");
// Branch BNE - explicitly exercise second value of first branch group
opcode = OPCODE_BRANCH;
funct3 = 3'b001;
funct7 = 7'd0;
check(0, 0, 0, 0, RESULT_ALU, 1, 0, 0, 0,
      ALU_SUB, "Branch BNE");

        if (errors == 0) begin
            $display("=== TB_CONTROL: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_CONTROL: %0d ERROR(S) ===", errors);
        end

        $finish;
    end
endmodule : tb_control