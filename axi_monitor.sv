// =============================================================================
// axi_monitor.sv
// Passively watches cpu_bus_if and publishes one transaction object every
// time a request completes (valid && ready), for the scoreboard to check.
// =============================================================================
class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)

    virtual cpu_bus_if.monitor vif;
    uvm_analysis_port #(axi_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_bus_if.monitor)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface must be set for axi_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            #1;
            if (vif.valid && vif.ready) begin
                axi_transaction tr = axi_transaction::type_id::create("tr");
                tr.addr     = vif.addr;
                tr.wdata    = vif.wdata;
                tr.is_write = vif.wstrb != 4'b0000;
                tr.rdata    = vif.rdata;
`uvm_info("MONITOR",
    $sformatf("ADDR=%08h WDATA=%08h WSTRB=%0h IS_WRITE=%0b RDATA=%08h",
              tr.addr, tr.wdata, vif.wstrb, tr.is_write, tr.rdata),
    UVM_LOW)
                ap.write(tr);
            end
        end
    endtask

endclass : axi_monitor
