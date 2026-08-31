
// =============================================================================
// alu.sv
// RV32I ALU: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU.
// Purely combinational ? result and zero flag both update within the same
// cycle as inputs change. Shift amount is taken from b[4:0] per RV32I.
// =============================================================================
module alu
    import soc_pkg::*;
(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  alu_op_e     op,
    output logic [31:0] result,
    output logic        zero
);

    always_comb begin
        unique case (op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            default:  result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule : alu