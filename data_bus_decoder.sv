// =============================================================================
// data_bus_decoder.sv
// Routes the core's simple data-memory bus to either data_sram (for
// DATA_SRAM_BASE range) or the AXI path (for AXI_PERIPH_BASE range),
// based on soc_pkg's memory map. Purely combinational -- safe because the
// core holds its address stable for the whole transaction (see rv32i_core's
// stall behavior).
//
// Any address that falls in neither range (a reserved gap) is handled
// locally: core_ready is asserted immediately with core_rdata=0, so the
// core can never hang waiting on a truly unmapped region. This mirrors the
// same "always respond" philosophy the AXI interconnect uses for addresses
// within its own space that don't match any peripheral.
// =============================================================================
module data_bus_decoder
    import soc_pkg::*;
(
    input  logic        clk,
    input  logic        rst,

    // ---- Core-side (from rv32i_core) ----
    input  logic [31:0] core_addr,
    input  logic [31:0] core_wdata,
    input  logic [3:0]  core_wstrb,
    input  logic        core_valid,
    output logic [31:0] core_rdata,
    output logic        core_ready,

    // ---- SRAM-side (to data_sram) ----
    output logic [31:0] sram_addr,
    output logic [31:0] sram_wdata,
    output logic [3:0]  sram_wstrb,
    output logic        sram_valid,
    input  logic [31:0] sram_rdata,
    input  logic        sram_ready,

    // ---- AXI-side (to core_to_axi_master_adapter's cpu_* port) ----
    output logic [31:0] axi_addr,
    output logic [31:0] axi_wdata,
    output logic [3:0]  axi_wstrb,
    output logic        axi_valid,
    input  logic [31:0] axi_rdata,
    input  logic        axi_ready
);

    logic addr_in_sram, addr_in_axi;

    assign addr_in_sram = (core_addr >= DATA_SRAM_BASE) &&
                          (core_addr <  DATA_SRAM_BASE + DATA_SRAM_SIZE);
    assign addr_in_axi  = (core_addr >= AXI_PERIPH_BASE) &&
                          (core_addr <  AXI_PERIPH_BASE + AXI_PERIPH_SIZE);

    assign sram_addr  = core_addr;
    assign sram_wdata = core_wdata;
    assign sram_wstrb = core_wstrb;
    assign sram_valid = core_valid && addr_in_sram;

    assign axi_addr  = core_addr;
    assign axi_wdata = core_wdata;
    assign axi_wstrb = core_wstrb;
    assign axi_valid = core_valid && addr_in_axi;

    always_comb begin
        if (addr_in_sram) begin
            core_rdata = sram_rdata;
            core_ready = sram_ready;
        end else if (addr_in_axi) begin
            core_rdata = axi_rdata;
            core_ready = axi_ready;
        end else begin
            // Reserved/unmapped gap -- respond immediately, never hang.
            core_rdata = 32'd0;
            core_ready = core_valid;
        end
    end

endmodule : data_bus_decoder
