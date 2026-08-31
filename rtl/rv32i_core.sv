// =============================================================================
// rv32i_core.sv
// Single-cycle RV32I core top-level. Connects decode_unit, control_unit,
// regfile, alu, and load_store_unit around a PC register and writeback mux.
//
// Memory is NOT yet attached ? imem_addr/imem_rdata and the dmem_* bus are
// exposed as clean external ports so instr_sram / data_sram / the AXI path
// can be wired in without touching this file's internals.
//
// Stall behavior: dmem_valid is asserted only for load/store instructions.
// If dmem_ready is low (e.g. a delayed AXI response), the core holds pc and
// withholds the regfile write for exactly as long as the stall lasts ? this
// is what lets the core tolerate the delayed-response peripherals later on.
// =============================================================================
module rv32i_core
    import soc_pkg::*;
(
    input  logic        clk,
    input  logic        rst,

    // Instruction memory interface
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    // Data memory / peripheral bus interface
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    output logic [3:0]  dmem_wstrb,
    output logic        dmem_valid,
    input  logic        dmem_ready
);

    // ------------------------------------------------------------
    // Program counter
    // ------------------------------------------------------------
    logic [31:0] pc, pc_next, pc_plus4, pc_target;
    logic        stall;
    logic [31:0] imm;

    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;
        end else if (!stall) begin
            pc <= pc_next;
        end
    end

    assign imem_addr = pc;
    assign pc_plus4  = pc + 32'd4;
    assign pc_target = pc + imm;

    // ------------------------------------------------------------
    // Decode
    // ------------------------------------------------------------
    logic [6:0]  opcode, funct7;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;


    decode_unit u_decode (
        .instr  (imem_rdata),
        .opcode (opcode),
        .rd     (rd),
        .rs1    (rs1),
        .rs2    (rs2),
        .funct3 (funct3),
        .funct7 (funct7),
        .imm    (imm)
    );

    // ------------------------------------------------------------
    // Control
    // ------------------------------------------------------------
    logic       reg_write, alu_src, mem_read, mem_write;
    logic [1:0] result_src;
    logic       branch, jump, jalr, auipc;
    alu_op_e    alu_op;

    control_unit u_control (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .reg_write  (reg_write),
        .alu_src    (alu_src),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .result_src (result_src),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr),
        .auipc      (auipc),
        .alu_op     (alu_op)
    );

    // ------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------
    logic [31:0] rs1_data, rs2_data, rd_data;

    regfile u_regfile (
        .clk      (clk),
        .rst      (rst),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .rd_addr  (rd),
        .rd_data  (rd_data),
        .rd_we    (reg_write & ~stall)
    );

    // ------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------
    logic [31:0] alu_in_a, alu_in_b, alu_result;
    logic        alu_zero;

    assign alu_in_a = auipc  ? pc   : rs1_data;
    assign alu_in_b = alu_src ? imm : rs2_data;

    alu u_alu (
        .a      (alu_in_a),
        .b      (alu_in_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // ------------------------------------------------------------
    // Branch resolution (separate from the pc+imm adder above)
    // ------------------------------------------------------------
    logic branch_taken;

    always_comb begin
        branch_taken = 1'b0;
        if (branch) begin
            unique case (funct3)
                3'b000:  branch_taken =  alu_zero;       // BEQ
                3'b001:  branch_taken = ~alu_zero;       // BNE
                3'b100:  branch_taken =  alu_result[0];  // BLT  (alu_op=SLT)
                3'b101:  branch_taken = ~alu_result[0];  // BGE
                3'b110:  branch_taken =  alu_result[0];  // BLTU (alu_op=SLTU)
                3'b111:  branch_taken = ~alu_result[0];  // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

    always_comb begin
        if (jalr) begin
            pc_next = {alu_result[31:1], 1'b0};   // (rs1 + imm) & ~1
        end else if (jump || branch_taken) begin
            pc_next = pc_target;                   // pc + imm
        end else begin
            pc_next = pc_plus4;
        end
    end

    // ------------------------------------------------------------
    // Load/store byte alignment + sign/zero extension
    // ------------------------------------------------------------
    logic [31:0] lsu_mem_wdata, lsu_load_data;
    logic [3:0]  lsu_wstrb;

    load_store_unit u_lsu (
        .funct3        (funct3),
        .addr_lsb      (alu_result[1:0]),
        .store_data_in (rs2_data),
        .wstrb         (lsu_wstrb),
        .mem_wdata     (lsu_mem_wdata),
        .mem_rdata     (dmem_rdata),
        .load_data_out (lsu_load_data)
    );

    // ------------------------------------------------------------
    // Data memory bus
    // ------------------------------------------------------------
    assign dmem_addr  = alu_result;                        // rs1 + imm
    assign dmem_wdata = lsu_mem_wdata;
    assign dmem_wstrb = mem_write ? lsu_wstrb : 4'b0000;
    assign dmem_valid = mem_read | mem_write;
    assign stall      = dmem_valid & ~dmem_ready;

    // ------------------------------------------------------------
    // Writeback mux
    // ------------------------------------------------------------
    always_comb begin
        unique case (result_src)
            RESULT_ALU: rd_data = alu_result;
            RESULT_MEM: rd_data = lsu_load_data;
            RESULT_PC4: rd_data = pc_plus4;
            RESULT_IMM: rd_data = imm;
            default:    rd_data = alu_result;
        endcase
    end

endmodule : rv32i_core