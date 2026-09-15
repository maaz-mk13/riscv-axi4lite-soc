
// =============================================================================
// load_store_unit.sv
// Handles byte-lane alignment for stores and sign/zero-extension for loads,
// based on funct3 (SB/SH/SW and LB/LH/LW/LBU/LHU) and the low 2 address bits.
// Purely combinational. Kept as its own module so rv32i_core stays readable
// and this logic is independently testable.
// =============================================================================
module load_store_unit (
    input  logic [2:0]  funct3,
    input  logic [1:0]  addr_lsb,       // dmem address bits [1:0]

    // Store path
    input  logic [31:0] store_data_in,  // rs2_data, unaligned
    output logic [3:0]  wstrb,
    output logic [31:0] mem_wdata,      // aligned/replicated for the target lane(s)

    // Load path
    input  logic [31:0] mem_rdata,      // raw word read back from memory
    output logic [31:0] load_data_out   // sign/zero-extended, lane-selected
);

    // ---------------- Store path ----------------
    always_comb begin
        unique case (funct3)
            3'b000: begin  // SB
                wstrb     = 4'b0001 << addr_lsb;
                mem_wdata = {4{store_data_in[7:0]}};
            end
            3'b001: begin  // SH
                wstrb     = 4'b0011 << addr_lsb;
                mem_wdata = {2{store_data_in[15:0]}};
            end
            3'b010: begin  // SW
                wstrb     = 4'b1111;
                mem_wdata = store_data_in;
            end
            default: begin
                wstrb     = 4'b0000;
                mem_wdata = 32'd0;
            end
        endcase
    end

    // ---------------- Load path ----------------
    logic [7:0]  byte_sel;
    logic [15:0] half_sel;

    assign byte_sel = mem_rdata[addr_lsb*8 +: 8];
    assign half_sel = mem_rdata[{addr_lsb[1], 4'b0000} +: 16];  // addr_lsb[1] picks lower/upper half

    always_comb begin
        unique case (funct3)
            3'b000:  load_data_out = {{24{byte_sel[7]}},  byte_sel};   // LB  (sign-extend)
            3'b001:  load_data_out = {{16{half_sel[15]}}, half_sel};   // LH  (sign-extend)
            3'b010:  load_data_out = mem_rdata;                        // LW
            3'b100:  load_data_out = {24'd0, byte_sel};                // LBU
            3'b101:  load_data_out = {16'd0, half_sel};                // LHU
            default: load_data_out = mem_rdata;
        endcase
    end

endmodule : load_store_unit