// =============================================================================
// axi_sequences.sv
// axi_write_read_seq: directed -- write one register, read it back.
// axi_random_seq: randomized -- lets axi_transaction's address distribution
//                 exercise all 4 peripheral windows plus the invalid region.
// =============================================================================
class axi_base_sequence extends uvm_sequence #(axi_transaction);
    `uvm_object_utils(axi_base_sequence)
    function new(string name = "axi_base_sequence");
        super.new(name);
    endfunction
endclass : axi_base_sequence

class axi_write_read_seq extends axi_base_sequence;
    `uvm_object_utils(axi_write_read_seq)

    bit [31:0] addr;
    bit [31:0] data;

    function new(string name = "axi_write_read_seq");
        super.new(name);
    endfunction

    task body();
        axi_transaction tr;

        tr = axi_transaction::type_id::create("tr");
        start_item(tr);
        tr.addr = addr; tr.wdata = data; tr.is_write = 1'b1;
        finish_item(tr);

        tr = axi_transaction::type_id::create("tr");
        start_item(tr);
        tr.addr = addr; tr.is_write = 1'b0;
        finish_item(tr);
    endtask
endclass : axi_write_read_seq

class axi_random_seq extends axi_base_sequence;
    `uvm_object_utils(axi_random_seq)

    int num_transactions = 20;

    function new(string name = "axi_random_seq");
        super.new(name);
    endfunction

    task body();
        repeat (num_transactions) begin
            axi_transaction tr = axi_transaction::type_id::create("tr");
            start_item(tr);
            if (!tr.randomize()) `uvm_error("RANDSEQ", "randomize() failed")
            finish_item(tr);
        end
    endtask
endclass : axi_random_seq
