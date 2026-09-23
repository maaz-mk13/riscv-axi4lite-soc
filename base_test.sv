// =============================================================================
// base_test.sv
// Builds the environment, runs one directed write-read per peripheral's
// key RW register, then a randomized sequence covering all peripheral
// windows plus the invalid region.
// =============================================================================
class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    axi_env env;

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi_write_read_seq wr_seq;
        axi_random_seq     rand_seq;

        phase.raise_objection(this);

        wr_seq = axi_write_read_seq::type_id::create("wr_seq");
        wr_seq.addr = GPIO_BASE + GPIO_DATA_OUT; wr_seq.data = 32'hA5;
        wr_seq.start(env.agent.sequencer);

        wr_seq = axi_write_read_seq::type_id::create("wr_seq");
        wr_seq.addr = TIMER_BASE + TIMER_LOAD; wr_seq.data = 32'd50;
        wr_seq.start(env.agent.sequencer);

        wr_seq = axi_write_read_seq::type_id::create("wr_seq");
        wr_seq.addr = PWM_BASE + PWM_PERIOD; wr_seq.data = 32'd20;
        wr_seq.start(env.agent.sequencer);

        wr_seq = axi_write_read_seq::type_id::create("wr_seq");
        wr_seq.addr = UART_BASE + UART_CTRL; wr_seq.data = 32'd8;
        wr_seq.start(env.agent.sequencer);

        // Directed: guarantee the invalid/unmapped region gets covered
        // (write + read) -- random weighting alone left this bin empty
        // in an earlier run, so it's forced here rather than hoped for.
        wr_seq = axi_write_read_seq::type_id::create("wr_seq");
        wr_seq.addr = 32'h2000_0000; wr_seq.data = 32'hDEAD_DEAD;
        wr_seq.start(env.agent.sequencer);

        rand_seq = axi_random_seq::type_id::create("rand_seq");
        rand_seq.num_transactions = 30;
        rand_seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask

endclass : base_test
