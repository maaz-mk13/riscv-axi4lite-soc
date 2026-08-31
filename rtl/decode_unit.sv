
// =============================================================================
// decode_unit.sv
// Pure combinational RV32I instruction decoder. Splits the 32-bit instruction
// into its fields and generates the correctly sign-extended immediate for
// whichever instruction format the opcode implies (I/S/B/U/J). For R-type
// instructions (no immediate), imm reads back as zero.
// =============================================================================
module decode_unit
    import soc_pkg::*;
(
    input  logic [31:0] instr,
    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7,
    output logic [31:0] imm
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always_comb begin
        unique case (opcode)
            OPCODE_ITYPE, OPCODE_LOAD, OPCODE_JALR: imm = imm_i;
            OPCODE_STORE:                           imm = imm_s;
            OPCODE_BRANCH:                          imm = imm_b;
            OPCODE_LUI, OPCODE_AUIPC:                imm = imm_u;
            OPCODE_JAL:                              imm = imm_j;
            default:                                 imm = 32'd0;  // R-type, SYSTEM, unrecognized
        endcase
    end

endmodule : decode_unit