// =============================================================================
// axi_agent.sv
// Standard active UVM agent: driver + sequencer + monitor.
// =============================================================================
class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)

    axi_driver               driver;
    uvm_sequencer #(axi_transaction) sequencer;
    axi_monitor               monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = axi_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = axi_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(axi_transaction)::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : axi_agent
