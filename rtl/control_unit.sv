
// =============================================================================
// control_unit.sv
// Pure combinational control unit. Generates all datapath control signals
// from opcode/funct3/funct7. Covers the full RV32I base ISA except
// ECALL/EBREAK/FENCE (OPCODE_SYSTEM), which are explicitly treated as NOP ?
// this is a documented scope simplification, not an omission.
// =============================================================================
module control_unit
    import soc_pkg::*;
(
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic [6:0]  funct7,

    output logic        reg_write,
    output logic        alu_src,     // 0 = rs2_data, 1 = imm
    output logic        mem_read,
    output logic        mem_write,
    output logic [1:0]  result_src,  // writeback mux select (see soc_pkg RESULT_*)
    output logic        branch,
    output logic        jump,        // JAL
    output logic        jalr,
    output logic        auipc,       // ALU input A = pc instead of rs1_data
    output alu_op_e      alu_op
);

    always_comb begin
        // Safe default (NOP) state for any unrecognized/unsupported opcode.
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        result_src = RESULT_ALU;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        auipc      = 1'b0;
        alu_op     = ALU_ADD;

        unique case (opcode)

            OPCODE_RTYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                unique case ({funct7, funct3})
                    10'b0000000_000: alu_op = ALU_ADD;   // ADD
                    10'b0100000_000: alu_op = ALU_SUB;   // SUB
                    10'b0000000_001: alu_op = ALU_SLL;   // SLL
                    10'b0000000_010: alu_op = ALU_SLT;   // SLT
                    10'b0000000_011: alu_op = ALU_SLTU;  // SLTU
                    10'b0000000_100: alu_op = ALU_XOR;   // XOR
                    10'b0000000_101: alu_op = ALU_SRL;   // SRL
                    10'b0100000_101: alu_op = ALU_SRA;   // SRA
                    10'b0000000_110: alu_op = ALU_OR;    // OR
                    10'b0000000_111: alu_op = ALU_AND;   // AND
                    default:          alu_op = ALU_ADD;
                endcase
            end

            OPCODE_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                unique case (funct3)
                    3'b000: alu_op = ALU_ADD;                       // ADDI
                    3'b010: alu_op = ALU_SLT;                       // SLTI
                    3'b011: alu_op = ALU_SLTU;                      // SLTIU
                    3'b100: alu_op = ALU_XOR;                       // XORI
                    3'b110: alu_op = ALU_OR;                        // ORI
                    3'b111: alu_op = ALU_AND;                       // ANDI
                    3'b001: alu_op = ALU_SLL;                       // SLLI
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL; // SRAI/SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPCODE_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                result_src = RESULT_MEM;
                alu_op     = ALU_ADD;   // address = rs1 + imm
            end

            OPCODE_STORE: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = ALU_ADD;    // address = rs1 + imm
            end

            OPCODE_BRANCH: begin
                branch  = 1'b1;
                alu_src = 1'b0;
                unique case (funct3)
                    3'b000, 3'b001: alu_op = ALU_SUB;   // BEQ/BNE  -> need zero flag
                    3'b100, 3'b101: alu_op = ALU_SLT;   // BLT/BGE  -> signed compare
                    3'b110, 3'b111: alu_op = ALU_SLTU;  // BLTU/BGEU-> unsigned compare
                    default:        alu_op = ALU_SUB;
                endcase
            end

            OPCODE_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                result_src = RESULT_PC4;
            end

            OPCODE_JALR: begin
                reg_write  = 1'b1;
                jalr       = 1'b1;
                alu_src    = 1'b1;
                result_src = RESULT_PC4;
                alu_op     = ALU_ADD;   // target = rs1 + imm
            end

            OPCODE_LUI: begin
                reg_write  = 1'b1;
                result_src = RESULT_IMM;
            end

            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                auipc     = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;    // result = pc + imm
            end

            OPCODE_SYSTEM: begin
                // ECALL/EBREAK: explicitly out of scope, treated as NOP.
            end

            default: begin
                // Unrecognized opcode: safe NOP (defaults above already apply).
            end

        endcase
    end

endmodule : control_unit