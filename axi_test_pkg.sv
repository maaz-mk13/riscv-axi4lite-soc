// =============================================================================
// axi_test_pkg.sv
// Package assembling all UVM classes for the AXI4-Lite subsystem
// environment. Compile this AFTER soc_pkg.sv and AFTER uvm_pkg is
// available, and BEFORE tb_uvm_top.sv.
// =============================================================================
`include "uvm_macros.svh"

package axi_test_pkg;
    import uvm_pkg::*;
    import soc_pkg::*;

    `include "axi_transaction.sv"
    `include "axi_driver.sv"
    `include "axi_monitor.sv"
    `include "axi_scoreboard.sv"
    `include "axi_agent.sv"
    `include "axi_env.sv"
    `include "axi_sequences.sv"
    `include "base_test.sv"

endpackage : axi_test_pkg
