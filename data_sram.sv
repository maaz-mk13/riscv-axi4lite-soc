// =============================================================================
// data_sram.sv
// Data memory. Combinational (same-cycle) read, synchronous byte-enabled
// write -- matches the standard single-cycle datapath: a load's data must
// be available in the same cycle it's requested so writeback can commit on
// the next clock edge; a store commits on the clock edge like any other
// synchronous write.
//
// ready is tied to valid: this SRAM never stalls (no wait states). It is
// only the future AXI-peripheral path that can hold dmem_ready low -- the
// core's stall logic exists for that case, not for this one.
// =============================================================================
module data_sram #(
    parameter int DEPTH_WORDS = 1024   // 4 KB / 4 bytes per word
) (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        valid,
    output logic [31:0] rdata,
    output logic        ready
);

    localparam int IDX_BITS = $clog2(DEPTH_WORDS);

    logic [31:0] mem [0:DEPTH_WORDS-1];

    // No initial-block zero-fill here on purpose: real SRAM powers up with
    // unknown content, and having both an `initial` block and an `always_ff`
    // block drive the same array triggers Questa's multiple-driver check
    // (vopt-7061) even though there's no actual runtime race. The test
    // program writes before it reads, so this doesn't affect correctness.

    assign rdata = mem[addr[IDX_BITS+1:2]];
    assign ready = valid;

    always_ff @(posedge clk) begin
        if (valid && (wstrb != 4'b0000)) begin
            if (wstrb[0]) mem[addr[IDX_BITS+1:2]][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[addr[IDX_BITS+1:2]][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[addr[IDX_BITS+1:2]][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[addr[IDX_BITS+1:2]][31:24] <= wdata[31:24];
        end
    end

endmodule : data_sram