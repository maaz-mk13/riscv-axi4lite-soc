# RISC-V SoC with AXI4-Lite Peripheral Subsystem

Capstone project (Verification track) — a synthesizable single-cycle RV32I
RISC-V SoC with an AXI4-Lite peripheral subsystem (GPIO, Timer, PWM, UART),
verified with a directed self-checking testbench suite and a UVM
environment with functional coverage, code coverage, and SVA assertions.

---

## 1. Project Overview

See [`TECHNICAL_REPORT.md`](./TECHNICAL_REPORT.md) for the full architecture,
verification strategy, and results. In short: a single-cycle RV32I core
talks to instruction/data SRAM directly and to four AXI4-Lite peripherals
(GPIO, Timer, PWM, UART) through a core-to-AXI adapter and an AXI4-Lite
interconnect with address decoding and SLVERR generation for unmapped
addresses.

## 2. Features

- Synthesizable RV32I core (base ISA, single-cycle, no pipelining)
- Instruction and data SRAM (4 KB each, combinational read)
- Full AXI4-Lite subsystem: master adapter, interconnect, address decode,
  SLVERR on unmapped addresses, tolerant of delayed peripheral responses
- 4 memory-mapped peripherals: GPIO, Timer (one-shot/periodic), PWM,
  UART (fixed 8N1)
- Self-checking directed testbench for every module, plus system-level
  integration tests
- UVM environment (driver/monitor/scoreboard/coverage/sequences) targeting
  the AXI subsystem and all 4 peripherals
- SVA protocol checker bound onto the CPU bus interface
- SDC timing constraints

## 3. Architecture Summary

```
rv32i_core -> data_bus_decoder -> { data_sram | core_to_axi_master_adapter -> axi4lite_interconnect -> { GPIO | Timer | PWM | UART } }
```

Full block diagram and module-by-module description: see
`TECHNICAL_REPORT.md` sections 2-3.

## 4. Repository / Directory Structure

**Current state:** all RTL and testbench files sit flat in the Questa
project working directory (this was a deliberate simulation-workflow
choice — Questa's Project GUI keeps everything in one folder). **The
recommended final structure below should be applied for submission** — see
4.1 for the exact file-to-folder mapping.

```
riscv-axi4lite-soc/
├── rtl/            # all design (non-testbench) .sv files
├── tb/              # all tb_*.sv self-checking testbenches
├── uvm/             # UVM environment + SVA files
├── sim/             # program.hex and other simulation input files
├── constraints/      # soc_top.sdc
├── docs/            # TECHNICAL_REPORT.md, architecture_document.md
└── README.md
```

### 4.1 File-to-Folder Mapping

| Current (flat) | Move to |
|---|---|
| `soc_pkg.sv`, `regfile.sv`, `alu.sv`, `decode_unit.sv`, `control_unit.sv`, `load_store_unit.sv`, `rv32i_core.sv`, `instr_sram.sv`, `data_sram.sv`, `data_bus_decoder.sv`, `core_to_axi_master_adapter.sv`, `axi4lite_interconnect.sv`, `axi4lite_dummy_slave.sv`, `axi4lite_gpio.sv`, `axi4lite_timer.sv`, `axi4lite_pwm.sv`, `axi4lite_uart.sv`, `soc_top.sv` | `rtl/` |
| `tb_regfile.sv`, `tb_alu.sv`, `tb_decode.sv`, `tb_control.sv`, `tb_core.sv`, `tb_axi_path.sv`, `tb_gpio.sv`, `tb_timer.sv`, `tb_pwm.sv`, `tb_uart.sv`, `tb_soc_gpio_integration.sv`, `tb_soc_top.sv`, `tb_soc_invalid_access.sv` | `tb/` |
| `cpu_bus_if.sv`, `axi_cpu_bus_checker.sv`, `axi_bind.sv`, `axi_test_pkg.sv`, `axi_transaction.sv`, `axi_driver.sv`, `axi_monitor.sv`, `axi_scoreboard.sv`, `axi_coverage.sv`, `axi_agent.sv`, `axi_env.sv`, `axi_sequences.sv`, `base_test.sv`, `tb_uvm_top.sv` | `uvm/` |
| `program.hex` and any other `program_*.hex` | `sim/` |
| `soc_top.sdc` | `constraints/` |
| `TECHNICAL_REPORT.md`, `architecture_document.md` | `docs/` |

**Note:** `axi_transaction.sv`, `axi_driver.sv`, `axi_monitor.sv`,
`axi_scoreboard.sv`, `axi_coverage.sv`, `axi_agent.sv`, `axi_env.sv`,
`axi_sequences.sv`, `base_test.sv` are `` `include``-ed inside
`axi_test_pkg.sv` — they must physically sit in the **same folder** as
`axi_test_pkg.sv` (i.e. `uvm/`), not be compiled as separate units.

If you move these files, update your Questa Project's file paths
accordingly (`Project -> Add to Project -> Existing File`, or re-point
existing entries), and re-run the compile order in section 7 from that new
location.

## 5. Required Tools / Environment

- **Simulator:** Siemens Questa Sim-64 **2024.1** (Intel/Altera FPGA
  Starter Edition — free license). UVM-1.1d + Questa's built-in
  `questa_uvm_pkg` ships with this version; no separate UVM library setup
  is required.
- **OS:** Windows (project developed and verified on Windows; paths in
  this README use Windows-style examples but the `vlog`/`vsim` commands
  themselves are platform-independent)

## 6. Prerequisites

1. Questa Sim-64 2024.1 installed and licensed.
2. This repository cloned locally.
3. All files from section 4.1 present (either in the recommended folder
   structure, or flat, as long as your Questa Project's search path can
   find them — Questa's `` `include`` resolution needs the `uvm/`-listed
   files to be co-located).

## 7. Compilation Instructions

### 7.1 Verified Compile Order (command line)

Run these `vlog -sv` commands **in this order** — each file's dependencies
appear before it in this list. (This is the logically correct dependency
order; it differs slightly from historical add-order in the Questa Project
GUI, which resolves dependencies automatically regardless of list order —
but for a batch command-line compile, order matters.)

```
vlog -sv soc_pkg.sv
vlog -sv regfile.sv alu.sv decode_unit.sv control_unit.sv load_store_unit.sv rv32i_core.sv
vlog -sv instr_sram.sv data_sram.sv
vlog -sv core_to_axi_master_adapter.sv axi4lite_interconnect.sv axi4lite_dummy_slave.sv
vlog -sv axi4lite_gpio.sv axi4lite_timer.sv axi4lite_pwm.sv axi4lite_uart.sv
vlog -sv data_bus_decoder.sv soc_top.sv
vlog -sv cpu_bus_if.sv
vlog -sv axi_cpu_bus_checker.sv
vlog -sv axi_bind.sv
vlog -sv axi_test_pkg.sv
```

Then compile every testbench (any order, each depends only on modules
already compiled above):

```
vlog -sv tb_regfile.sv tb_alu.sv tb_decode.sv tb_control.sv tb_core.sv
vlog -sv tb_axi_path.sv tb_gpio.sv tb_timer.sv tb_pwm.sv tb_uart.sv
vlog -sv tb_soc_gpio_integration.sv tb_soc_top.sv tb_soc_invalid_access.sv
vlog -sv tb_uvm_top.sv
```

Or, once the dependency-safe order above has been compiled once, a plain
`vlog -sv <all files listed above, in this same order>` in a single
invocation also works (this is effectively what Questa's **Compile All**
does once the Project's files are present).

### 7.2 Without Typing Commands — Using the Questa GUI

1. Open Questa Sim-64.
2. **File -> Open Project...** and select this repository's `.mpf` file (or
   **File -> New -> Project** and add every `.sv` file from section 4.1 if
   starting fresh).
3. **Compile -> Compile All.** Questa resolves inter-file dependencies
   automatically within a Project — you do not need to manually order files
   in the Project tab.
4. Confirm every file shows a green checkmark (success) in the Project
   tab's Status column before proceeding to simulation.

## 8. Simulation Instructions

For any testbench `tb_xxx`:

```
vsim tb_xxx
run -all
```

or, in the GUI: **Simulate -> Start Simulation...**, select the testbench
module, then in the Transcript pane type `run -all` (or click the **Run
-All** toolbar button).

## 9. How to Run Individual Tests

See the full table in section 10 below — each row's "Compile/Run command"
column is copy-paste ready.

## 10. Test Table

| Testbench | Purpose | Compile/Run Command | Expected Result |
|---|---|---|---|
| `tb_regfile` | Register file: reset, write/readback, x0 hardwired zero, dual-port read | `vlog -sv tb_regfile.sv` then `vsim tb_regfile` then `run -all` | `=== TB_REGFILE: ALL TESTS PASSED ===` |
| `tb_alu` | All 10 ALU operations | `vlog -sv tb_alu.sv` then `vsim tb_alu` then `run -all` | `=== TB_ALU: ALL TESTS PASSED ===` |
| `tb_decode` | Instruction decode for all 6 RV32I formats | `vlog -sv tb_decode.sv` then `vsim tb_decode` then `run -all` | `=== TB_DECODE: ALL TESTS PASSED ===` |
| `tb_control` | Control unit signals for every opcode category | `vlog -sv tb_control.sv` then `vsim tb_control` then `run -all` | `=== TB_CONTROL: ALL TESTS PASSED ===` |
| `tb_core` | Full core running a 21-instruction hand-assembled program | `vlog -sv tb_core.sv` then `vsim tb_core` then `run -all` (requires `program.hex` in the working directory) | `=== TB_CORE: ALL TESTS PASSED ===` |
| `tb_axi_path` | AXI adapter + interconnect + a test slave; SLVERR/no-hang proof | `vlog -sv tb_axi_path.sv` then `vsim tb_axi_path` then `run -all` | `=== TB_AXI_PATH: ALL TESTS PASSED ===` |
| `tb_gpio` | GPIO peripheral, standalone | `vlog -sv tb_gpio.sv` then `vsim tb_gpio` then `run -all` | `=== TB_GPIO: ALL TESTS PASSED ===` |
| `tb_timer` | Timer peripheral, standalone | `vlog -sv tb_timer.sv` then `vsim tb_timer` then `run -all` | `=== TB_TIMER: ALL TESTS PASSED ===` |
| `tb_pwm` | PWM peripheral, standalone | `vlog -sv tb_pwm.sv` then `vsim tb_pwm` then `run -all` | `=== TB_PWM: ALL TESTS PASSED ===` |
| `tb_uart` | UART peripheral, standalone | `vlog -sv tb_uart.sv` then `vsim tb_uart` then `run -all` | `=== TB_UART: ALL TESTS PASSED ===` |
| `tb_soc_gpio_integration` | GPIO through the real AXI chain (not a dummy slave) | `vlog -sv tb_soc_gpio_integration.sv` then `vsim tb_soc_gpio_integration` then `run -all` | `=== TB_SOC_GPIO_INTEGRATION: ALL TESTS PASSED ===` |
| `tb_soc_top` | Full SoC; real CPU instructions reach a physical GPIO pin | `vlog -sv tb_soc_top.sv` then `vsim tb_soc_top` then `run -all` (requires `program_soc_top.hex`) | `=== TB_SOC_TOP: ALL TESTS PASSED ===` |
| `tb_soc_invalid_access` | System-level proof: an unmapped access never hangs the core | `vlog -sv tb_soc_invalid_access.sv` then `vsim tb_soc_invalid_access` then `run -all` (requires `program_invalid_access.hex`) | `=== TB_SOC_INVALID_ACCESS: ALL TESTS PASSED (no hang confirmed) ===` |
| `tb_uvm_top` (`base_test`) | UVM environment: directed + randomized sequences, scoreboard, functional coverage, SVA | `vlog -sv tb_uvm_top.sv` then `vsim tb_uvm_top` then `run -all` | UVM report summary shows `UVM_ERROR : 0`, `UVM_WARNING : 0`, `UVM_FATAL : 0`, and `SCOREBOARD: ALL CHECKS PASSED` |

## 11. How to Run the UVM Test

```
vlog -sv cpu_bus_if.sv axi_cpu_bus_checker.sv axi_bind.sv axi_test_pkg.sv tb_uvm_top.sv
vsim tb_uvm_top
run -all
```

Expect UVM_INFO lines from the monitor for every transaction, ending in:
```
UVM_INFO ... [SCOREBOARD] Checked 4 shadow-predictable reads, 0 mismatch(es)
UVM_INFO ... [SCOREBOARD] === SCOREBOARD: ALL CHECKS PASSED ===
UVM_INFO ... [COVERAGE] Address-region x direction cross coverage = 100.00%
```
and a final **UVM Report Summary** with `UVM_ERROR : 0`.

## 12. How to Reproduce Coverage

Compile with coverage instrumentation and simulate with `-coverage`:

```
vlog -sv -cover sbceft <files as needed for the testbench>
vsim -coverage tb_xxx
run -all
coverage save cov_xxx.ucdb
quit -sim
```

Repeat for every testbench (`tb_regfile`, `tb_alu`, `tb_decode`,
`tb_control`, `tb_core`, `tb_gpio`, `tb_timer`, `tb_pwm`, `tb_uart`,
`tb_soc_top`, `tb_soc_gpio_integration`, `tb_soc_invalid_access`,
`tb_axi_path`, `tb_uvm_top`), each saving its own `.ucdb`.

**Merge all coverage databases into one:**

```
vcover merge final_coverage.ucdb cov_regfile.ucdb cov_alu.ucdb cov_decode.ucdb cov_control.ucdb cov_core.ucdb cov_axi_path.ucdb cov_gpio.ucdb cov_timer.ucdb cov_pwm.ucdb cov_uart.ucdb cov_soc_gpio.ucdb cov_soc_top.ucdb cov_invalid.ucdb cov_uvm.ucdb
```

(Adjust the exact `.ucdb` filenames to whatever you actually saved each
run as.)

**View the summary:**

```
vcover report final_coverage.ucdb -summary
```

**Generate a browsable HTML report:**

```
vcover report final_coverage.ucdb -html -output coverage_html
```
Then open `coverage_html/covSummary.html` in a browser.

## 13. How to Reproduce Reported Results

From a clean checkout:

1. Clone the repository: `git clone https://github.com/maaz-mk13/riscv-axi4lite-soc.git`
2. Open Questa Sim-64 2024.1.
3. Open or create a Project pointing at the cloned repository's RTL/TB
   files (per section 4.1's mapping, or the current flat layout if not yet
   reorganized).
4. Compile all source (section 7.1 or 7.2).
5. Run each directed testbench in turn (section 10's table) and confirm
   each `ALL TESTS PASSED` line.
6. Run the UVM test (section 11) and confirm the UVM Report Summary shows
   `UVM_ERROR : 0`.
7. Generate coverage (section 12) and confirm the reported functional
   coverage (100.00%, 17/17 bins) and code coverage totals match
   `TECHNICAL_REPORT.md` sections 5.9-6.2, allowing for the caveat noted
   there about per-instance vs. per-module reporting.
8. Open the coverage HTML report to visually inspect per-module results.

## 14. Expected PASS Output/Examples

Example transcript excerpt for `tb_gpio`:
```
PASS GPIO_DATA_OUT readback = 0x000000a5
PASS gpio_out = 0xa5
PASS GPIO_DIR readback = 0x000000ff
PASS gpio_dir = 0xff
PASS GPIO_DATA_IN = 0x0000003c
PASS GPIO_STATUS = 0
=== TB_GPIO: ALL TESTS PASSED ===
```

Example transcript excerpt for `tb_uvm_top`:
```
UVM_INFO axi_scoreboard.sv(67) @ ...: uvm_test_top.env.scoreboard [SCOREBOARD] Checked 4 shadow-predictable reads, 0 mismatch(es)
UVM_INFO axi_scoreboard.sv(71) @ ...: uvm_test_top.env.scoreboard [SCOREBOARD] === SCOREBOARD: ALL CHECKS PASSED ===
UVM_INFO axi_coverage.sv(50) @ ...: uvm_test_top.env.coverage [COVERAGE] Address-region x direction cross coverage = 100.00%
--- UVM Report Summary ---
UVM_INFO :   47
UVM_WARNING :    0
UVM_ERROR :    0
UVM_FATAL :    0
```

## 15. Timing/SDC Information

`soc_top.sdc` specifies:
- `create_clock -name clk -period 10.000` (100 MHz)
- `set_clock_uncertainty 0.500`
- 2.000 ns input delay on `rst`, `gpio_in[*]`, `uart_rx`
- 2.000 ns output delay on `gpio_out[*]`, `gpio_dir[*]`, `pwm_out`, `uart_tx`
- An explicit note that no async-assert/sync-deassert reset synchronizer is
  implemented in the current RTL; `rst` is constrained as an ordinary
  synchronous input.

**No synthesis or static timing analysis has been run against this file —
no timing closure is claimed.** This SDC is provided as the project's
timing-constraints deliverable, per the Verification-track scope (no
Physical Design work is claimed or required for this track).

## 16. Verification Summary

- **Directed/self-checking:** every RTL module has its own passing
  self-checking testbench; the full SoC integration and a system-level
  no-hang test both pass.
- **UVM:** full environment (agent/driver/monitor/scoreboard/coverage/
  sequences/test) against the AXI subsystem and all 4 peripherals —
  0 UVM errors/warnings/fatals, 0 scoreboard mismatches, 100% functional
  coverage (17/17 bins).
- **SVA:** protocol checker bound onto the CPU bus interface — no
  assertion failures observed in any run.
- **Code coverage:** 68.51% final merged total (Instance view, filtered);
  the remaining gap is predominantly Toggle coverage on architecturally
  unreachable upper bits of oversized register buses (documented in
  `TECHNICAL_REPORT.md` section 5.9).

Full detail: see `TECHNICAL_REPORT.md`.
