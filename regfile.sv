
// =============================================================================
// regfile.sv
// RV32I register file: 32 x 32-bit registers, x0 hardwired to zero.
// Two combinational read ports, one synchronous write port.
//
// Timing:
//   - Reads are combinational (same-cycle) off rs1_addr/rs2_addr.
//   - Writes commit on the rising edge of clk when rd_we=1 and rd_addr != 0.
//   - Synchronous reset clears all registers to 0.
//
// Note: within a single-cycle core, a given instruction's operand reads and
// its own writeback do not need same-cycle forwarding, since read happens
// at the start of the cycle and write commits at the following clock edge
// for the *next* instruction to see. No internal write-then-read hazard
// exists across instruction boundaries in this architecture.
// =============================================================================
module regfile (
    input  logic        clk,
    input  logic        rst,        // synchronous, active-high

    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,

    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data,
    input  logic        rd_we
);

    logic [31:0] regs [31:0];

    // Combinational reads, x0 always reads as zero regardless of stored value.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'd0;
            end
        end else if (rd_we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule : regfile