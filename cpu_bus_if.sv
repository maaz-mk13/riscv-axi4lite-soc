// =============================================================================
// cpu_bus_if.sv
// The same simple valid/ready bus rv32i_core uses to talk to
// core_to_axi_master_adapter. UVM drives this interface to act as a
// virtual CPU, exercising the real AXI adapter + interconnect + peripherals
// exactly the way the actual core does.
// =============================================================================
interface cpu_bus_if (
    input logic clk,
    input logic rst
);

    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        valid;
    logic [31:0] rdata;
    logic        ready;

    modport driver (
        input  clk, rst,
        output addr, wdata, wstrb, valid,
        input  rdata, ready
    );

    modport monitor (
        input clk, rst,
        input addr, wdata, wstrb, valid,
        input rdata, ready
    );

endinterface : cpu_bus_if
