// =============================================================================
// axi_driver.sv
// Drives cpu_bus_if the same way rv32i_core would: assert valid/addr/
// wdata/wstrb, wait for ready, capture rdata on a read, deassert.
// =============================================================================
class axi_driver extends uvm_driver #(axi_transaction);
    `uvm_component_utils(axi_driver)

    virtual cpu_bus_if.driver vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_bus_if.driver)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface must be set for axi_driver")
    endfunction

    task run_phase(uvm_phase phase);
        vif.valid = 1'b0;
        forever begin
            axi_transaction tr;
            seq_item_port.get_next_item(tr);
            drive(tr);
            seq_item_port.item_done();
        end
    endtask
task drive(axi_transaction tr);
    @(posedge vif.clk);

    vif.addr  = tr.addr;
    vif.wdata = tr.wdata;
    vif.wstrb = tr.is_write ? 4'b1111 : 4'b0000;
    vif.valid = 1'b1;

    do begin
        @(posedge vif.clk);
    end while (!vif.ready);

    if (!tr.is_write)
        tr.rdata = vif.rdata;

    vif.valid = 1'b0;
    vif.addr  = '0;
    vif.wdata = '0;
    vif.wstrb = '0;

    @(posedge vif.clk);
endtask 
endclass : axi_driver
