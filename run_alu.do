vlib work
vlog -sv ../rtl/soc_pkg.sv ../rtl/alu.sv ../tb/tb_alu.sv
vsim -c tb_alu -do "run -all; quit"
