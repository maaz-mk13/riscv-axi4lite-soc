// =============================================================================
// axi_transaction.sv
// UVM sequence item: one transaction on the cpu_bus_if.
// Address distribution deliberately weights toward all 4 peripheral
// windows plus one known-invalid address, so randomized sequences
// naturally exercise address decoding and SLVERR handling.
// =============================================================================
class axi_transaction extends uvm_sequence_item;

    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    rand bit        is_write;
    bit      [31:0] rdata;   // captured by the driver on a read

    constraint addr_dist_c {
        addr dist {
            [GPIO_BASE  : GPIO_BASE  + PERIPH_SIZE - 1] := 25,
            [TIMER_BASE : TIMER_BASE + PERIPH_SIZE - 1] := 25,
            [PWM_BASE   : PWM_BASE   + PERIPH_SIZE - 1] := 25,
            [UART_BASE  : UART_BASE  + PERIPH_SIZE - 1] := 15,
            32'h2000_0000                                := 10  // known-unmapped address
        };
    }

    `uvm_object_utils_begin(axi_transaction)
        `uvm_field_int(addr,     UVM_ALL_ON)
        `uvm_field_int(wdata,    UVM_ALL_ON)
        `uvm_field_int(is_write, UVM_ALL_ON)
        `uvm_field_int(rdata,    UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_transaction");
        super.new(name);
    endfunction

endclass : axi_transaction
