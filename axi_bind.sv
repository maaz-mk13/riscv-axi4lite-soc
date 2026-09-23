// =============================================================================
// axi_bind.sv
// Binds axi_cpu_bus_checker onto every instance of cpu_bus_if automatically
// -- no need to instantiate the checker by hand in each testbench.
// =============================================================================
bind cpu_bus_if axi_cpu_bus_checker u_axi_cpu_bus_checker (
    .clk   (clk),
    .rst   (rst),
    .valid (valid),
    .ready (ready),
    .addr  (addr),
    .wdata (wdata),
    .wstrb (wstrb)
);
