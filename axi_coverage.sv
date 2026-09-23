// =============================================================================
// axi_coverage.sv
// Functional coverage: address region (GPIO/Timer/PWM/UART/invalid) crossed
// with read/write direction. Subscribes to the same monitor analysis port
// as the scoreboard.
// =============================================================================
class axi_coverage extends uvm_subscriber #(axi_transaction);
    `uvm_component_utils(axi_coverage)

    int unsigned tr_addr_region;  // 0=GPIO,1=Timer,2=PWM,3=UART,4=invalid
    bit          tr_is_write;

    covergroup addr_dir_cg;
        option.per_instance = 1;

        cp_region: coverpoint tr_addr_region {
            bins gpio    = {0};
            bins timer   = {1};
            bins pwm     = {2};
            bins uart    = {3};
            bins invalid = {4};
        }

        cp_dir: coverpoint tr_is_write {
            bins write = {1};
            bins read  = {0};
        }

        cross_region_dir: cross cp_region, cp_dir;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        addr_dir_cg = new();
    endfunction

    function void write(axi_transaction t);
        tr_is_write = t.is_write;

        if      (t.addr inside {[GPIO_BASE  : GPIO_BASE  + PERIPH_SIZE - 1]}) tr_addr_region = 0;
        else if (t.addr inside {[TIMER_BASE : TIMER_BASE + PERIPH_SIZE - 1]}) tr_addr_region = 1;
        else if (t.addr inside {[PWM_BASE   : PWM_BASE   + PERIPH_SIZE - 1]}) tr_addr_region = 2;
        else if (t.addr inside {[UART_BASE  : UART_BASE  + PERIPH_SIZE - 1]}) tr_addr_region = 3;
        else                                                                    tr_addr_region = 4;

        addr_dir_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE",
            $sformatf("Address-region x direction cross coverage = %0.2f%%",
                      addr_dir_cg.cross_region_dir.get_coverage()),
            UVM_LOW)
    endfunction

endclass : axi_coverage
