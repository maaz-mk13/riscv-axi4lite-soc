// =============================================================================
// axi_cpu_bus_checker.sv
// Protocol assertions for cpu_bus_if, independent of UVM -- these would
// fire even in a purely directed testbench. Bound onto the interface (see
// axi_bind.sv) rather than instantiated directly, so it observes every
// signal without needing its own port connections wired up per-testbench.
// =============================================================================
module axi_cpu_bus_checker (
    input logic        clk,
    input logic        rst,
    input logic        valid,
    input logic        ready,
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic [3:0]  wstrb
);

    // ---- valid must never be X/Z ----
    property no_x_valid_p;
        @(posedge clk) disable iff (rst) !$isunknown(valid);
    endproperty
    assert property (no_x_valid_p)
        else $error("PROTOCOL: valid went to X/Z");

    // ---- addr must stay stable while a request is pending (valid high, ready not yet seen) ----
    property addr_stable_p;
        @(posedge clk) disable iff (rst)
        (valid && !ready) |=> $stable(addr);
    endproperty
    assert property (addr_stable_p)
        else $error("PROTOCOL: addr changed while a transaction was still pending");

    // ---- for a write (wstrb != 0), wdata/wstrb must stay stable while pending ----
    property wdata_stable_p;
        @(posedge clk) disable iff (rst)
        (valid && !ready && (wstrb != 4'b0000)) |=> ($stable(wdata) && $stable(wstrb));
    endproperty
    assert property (wdata_stable_p)
        else $error("PROTOCOL: wdata/wstrb changed mid-write while still pending");

    // ---- liveness: ready must eventually arrive after valid asserts (no permanent hang) ----
    // Window is generous (200 cycles) to comfortably allow for delayed AXI
    // responses -- this checks for a genuine hang, not tight timing.
    property ready_eventually_p;
        @(posedge clk) disable iff (rst)
        valid |-> ##[0:200] ready;
    endproperty
    assert property (ready_eventually_p)
        else $error("PROTOCOL: ready did not arrive within 200 cycles of valid -- possible hang");

endmodule : axi_cpu_bus_checker
