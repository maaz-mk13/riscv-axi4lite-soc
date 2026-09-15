vlib work
vlog -sv ../rtl/soc_pkg.sv ../rtl/regfile.sv ../tb/tb_regfile.sv
vsim -c tb_regfile -do "run -all; quit"
