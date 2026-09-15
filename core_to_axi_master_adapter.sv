
// =============================================================================
// core_to_axi_master_adapter.sv
// Converts the core's simple valid/ready data bus into a full AXI4-Lite
// master interface. Implements the documented simplification: AWVALID and
// WVALID are asserted together for writes (single non-pipelined master,
// no independent AW/W queuing).
//
// Only one transaction is ever outstanding (matches the single-cycle core,
// which holds cpu_addr/cpu_wdata/cpu_valid stable until cpu_ready arrives).
// This means address decode downstream can be purely combinational -- the
// address never changes mid-transaction.
// =============================================================================
module core_to_axi_master_adapter (
    input  logic        clk,
    input  logic        rst,

    // ---- CPU-side simple bus ----
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,
    input  logic [3:0]  cpu_wstrb,   // nonzero => write request, zero => read request
    input  logic        cpu_valid,
    output logic [31:0] cpu_rdata,
    output logic        cpu_ready,

    // ---- AXI4-Lite master ----
    output logic [31:0] AWADDR,
    output logic        AWVALID,
    input  logic        AWREADY,

    output logic [31:0] WDATA,
    output logic [3:0]  WSTRB,
    output logic        WVALID,
    input  logic        WREADY,

    input  logic [1:0]  BRESP,
    input  logic        BVALID,
    output logic        BREADY,

    output logic [31:0] ARADDR,
    output logic        ARVALID,
    input  logic        ARREADY,

    input  logic [31:0] RDATA,
    input  logic [1:0]  RRESP,
    input  logic        RVALID,
    output logic        RREADY
);

    typedef enum logic [2:0] {
        IDLE,
        WRITE_ADDR_DATA,   // AWVALID+WVALID asserted together, waiting for both READYs
        WRITE_RESP,        // waiting for BVALID
        READ_ADDR,         // ARVALID asserted, waiting for ARREADY
        READ_DATA          // waiting for RVALID
    } state_e;

    state_e state, state_next;

    logic is_write;
    assign is_write = |cpu_wstrb;

    // Latches for channels that complete their handshake at different times
    // during WRITE_ADDR_DATA (AW may accept before W, or vice versa).
    logic aw_done, w_done;

    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            aw_done <= 1'b0;
            w_done  <= 1'b0;
        end else begin
            state <= state_next;
            unique case (state)
                IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                end
                WRITE_ADDR_DATA: begin
                    if (AWVALID && AWREADY) aw_done <= 1'b1;
                    if (WVALID  && WREADY)  w_done  <= 1'b1;
                end
                default: ; // no action
            endcase
        end
    end

    always_comb begin
        state_next = state;
        unique case (state)
            IDLE: begin
                if (cpu_valid && is_write)       state_next = WRITE_ADDR_DATA;
                else if (cpu_valid && !is_write) state_next = READ_ADDR;
            end
            WRITE_ADDR_DATA: begin
                if ((AWVALID && AWREADY || aw_done) && (WVALID && WREADY || w_done)) begin
                    state_next = WRITE_RESP;
                end
            end
            WRITE_RESP: begin
                if (BVALID) state_next = IDLE;
            end
            READ_ADDR: begin
                if (ARVALID && ARREADY) state_next = READ_DATA;
            end
            READ_DATA: begin
                if (RVALID) state_next = IDLE;
            end
            default: state_next = IDLE;
        endcase
    end

    // ---- Write address/data channels ----
    assign AWADDR  = cpu_addr;
    assign AWVALID = (state == WRITE_ADDR_DATA) && !aw_done;
    assign WDATA   = cpu_wdata;
    assign WSTRB   = cpu_wstrb;
    assign WVALID  = (state == WRITE_ADDR_DATA) && !w_done;
    assign BREADY  = (state == WRITE_RESP);

    // ---- Read address/data channels ----
    assign ARADDR  = cpu_addr;
    assign ARVALID = (state == READ_ADDR);
    assign RREADY  = (state == READ_DATA);

    // ---- CPU-side response ----
    assign cpu_ready = (state == WRITE_RESP && BVALID) || (state == READ_DATA && RVALID);
    assign cpu_rdata = RDATA;

endmodule : core_to_axi_master_adapter