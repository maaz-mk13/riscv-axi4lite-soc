
// =============================================================================
// instr_sram.sv
// Instruction memory. Combinational (same-cycle) read -- required for a true
// single-cycle, non-pipelined core: PC drives addr, rdata must be valid
// within the same cycle for decode/execute/writeback to complete together.
//
// Loaded at time 0 via $readmemh from INIT_FILE (plain hex, one 32-bit
// instruction per line, no "0x" prefix). Uninitialized words default to
// zero, which decodes as an unrecognized opcode -> control_unit's safe NOP
// default -- so unprogrammed memory is harmless, not undefined behavior.
//
// NOTE: $readmemh is a simulation-only construct. Real synthesis/FPGA flows
// load program memory a different way (e.g. .mif/.hex loaded into inferred
// BRAM by the synthesis tool, or a separate boot-load mechanism) -- flagged
// here per the architecture doc's synthesis risk list.
// =============================================================================
module instr_sram #(
    parameter string INIT_FILE    = "program.hex",
    parameter int    DEPTH_WORDS  = 1024   // 4 KB / 4 bytes per word
) (
    input  logic [31:0] addr,
    output logic [31:0] rdata
);

    localparam int IDX_BITS = $clog2(DEPTH_WORDS);

    logic [31:0] mem [0:DEPTH_WORDS-1];

    initial begin
        for (int i = 0; i < DEPTH_WORDS; i++) begin
            mem[i] = 32'd0;
        end
        $readmemh(INIT_FILE, mem);
    end

    assign rdata = mem[addr[IDX_BITS+1:2]];  // word-aligned index (byte addr / 4)

endmodule : instr_sram