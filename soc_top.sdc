# =============================================================================
# soc_top.sdc
# Basic synthesis timing constraints for the RISC-V AXI4-Lite SoC.
# Target: 100 MHz (10.000 ns period) -- adjust if your synthesis target
# (e.g. a specific FPGA family) needs a different clock rate.
# =============================================================================

# ---- Primary clock ----
create_clock -name clk -period 10.000 [get_ports clk]
set_clock_uncertainty 0.500 [get_clocks clk]

# ---- Input delays (external signals arriving relative to clk) ----
set_input_delay -clock clk 2.000 [get_ports rst]
set_input_delay -clock clk 2.000 [get_ports {gpio_in[*]}]
set_input_delay -clock clk 2.000 [get_ports uart_rx]

# ---- Output delays (external signals driven relative to clk) ----
set_output_delay -clock clk 2.000 [get_ports {gpio_out[*]}]
set_output_delay -clock clk 2.000 [get_ports {gpio_dir[*]}]
set_output_delay -clock clk 2.000 [get_ports pwm_out]
set_output_delay -clock clk 2.000 [get_ports uart_tx]

# ---- Reset ----
# NOTE: this design does not implement a dedicated asynchronous-assert /
# synchronous-deassert reset synchronizer (originally proposed in the
# architecture doc) -- rst is used directly as a synchronous active-high
# reset throughout every module. This is constrained as a normal
# synchronous input above, not as a false path. If a truly asynchronous
# external reset source is introduced later (e.g. a physical reset button
# on real hardware), a 2-flop synchronizer should be added and this
# constraint revisited accordingly.
