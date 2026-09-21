// =============================================================================
// axi_scoreboard.sv
// Shadow-register scoreboard: tracks every write to a known RW register and
// checks that a subsequent read of that same register returns what was
// written. Live/read-only registers (TIMER_COUNT, *_STATUS, GPIO_DATA_IN,
// UART_RXDATA) and unmapped addresses aren't shadow-checkable this way --
// they're excluded here on purpose, since they're already covered by the
// dedicated directed testbenches (tb_timer, tb_gpio, etc).
// =============================================================================
class axi_scoreboard extends uvm_subscriber #(axi_transaction);
    `uvm_component_utils(axi_scoreboard)

    bit [31:0] shadow_gpio_data_out;
    bit [31:0] shadow_gpio_dir;
    bit [31:0] shadow_timer_ctrl, shadow_timer_load;
    bit [31:0] shadow_pwm_ctrl, shadow_pwm_period, shadow_pwm_duty;
    bit [31:0] shadow_uart_ctrl;

    int num_checked;
    int num_errors;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void write(axi_transaction t);
        if (t.is_write) begin
            unique case (t.addr)
                GPIO_BASE  + GPIO_DATA_OUT: shadow_gpio_data_out = t.wdata;
                GPIO_BASE  + GPIO_DIR:      shadow_gpio_dir      = t.wdata;
                TIMER_BASE + TIMER_CTRL:    shadow_timer_ctrl    = t.wdata;
                TIMER_BASE + TIMER_LOAD:    shadow_timer_load    = t.wdata;
                PWM_BASE   + PWM_CTRL:      shadow_pwm_ctrl      = t.wdata;
                PWM_BASE   + PWM_PERIOD:    shadow_pwm_period    = t.wdata;
                PWM_BASE   + PWM_DUTY:      shadow_pwm_duty      = t.wdata;
                UART_BASE  + UART_CTRL:     shadow_uart_ctrl     = t.wdata;
                default: ; // live/RO register or unmapped address -- not shadowed
            endcase
        end else begin
            unique case (t.addr)
                GPIO_BASE  + GPIO_DATA_OUT: check_read(t, shadow_gpio_data_out);
                GPIO_BASE  + GPIO_DIR:      check_read(t, shadow_gpio_dir);
                TIMER_BASE + TIMER_CTRL:    check_read(t, shadow_timer_ctrl);
                TIMER_BASE + TIMER_LOAD:    check_read(t, shadow_timer_load);
                PWM_BASE   + PWM_CTRL:      check_read(t, shadow_pwm_ctrl);
                PWM_BASE   + PWM_PERIOD:    check_read(t, shadow_pwm_period);
                PWM_BASE   + PWM_DUTY:      check_read(t, shadow_pwm_duty);
                UART_BASE  + UART_CTRL:     check_read(t, shadow_uart_ctrl);
                default: ; // not shadow-checkable, skip silently
            endcase
        end
    endfunction

    function void check_read(axi_transaction t, bit [31:0] expected);
        num_checked++;
        if (t.rdata !== expected) begin
            num_errors++;
            `uvm_error("SCOREBOARD",
                $sformatf("Mismatch @0x%08h: expected 0x%08h got 0x%08h", t.addr, expected, t.rdata))
        end else begin
            `uvm_info("SCOREBOARD",
                $sformatf("Match @0x%08h = 0x%08h", t.addr, t.rdata), UVM_HIGH)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD",
            $sformatf("Checked %0d shadow-predictable reads, %0d mismatch(es)", num_checked, num_errors),
            UVM_LOW)
        if (num_errors == 0) begin
            `uvm_info("SCOREBOARD", "=== SCOREBOARD: ALL CHECKS PASSED ===", UVM_LOW)
        end else begin
            `uvm_error("SCOREBOARD", $sformatf("=== SCOREBOARD: %0d MISMATCH(ES) ===", num_errors))
        end
    endfunction

endclass : axi_scoreboard
