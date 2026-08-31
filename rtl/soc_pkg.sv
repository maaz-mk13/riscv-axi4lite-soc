// =============================================================================
// soc_pkg.sv  (v2 ? adds RV32I opcodes + writeback mux encoding for the core)
// Shared package: memory map, peripheral register offsets, ALU op encoding,
// RV32I opcodes, core control encodings.
// EVERY module in this project should import this package rather than
// hardcoding addresses/offsets, so the whole team stays in sync.
// =============================================================================
package soc_pkg;

  // ---------------------------------------------------------------------
  // Top-level memory map
  // ---------------------------------------------------------------------
  parameter logic [31:0] INSTR_SRAM_BASE = 32'h0000_0000;
  parameter logic [31:0] INSTR_SRAM_SIZE = 32'h0000_1000;  // 4 KB (1024 words)

  parameter logic [31:0] DATA_SRAM_BASE  = 32'h1000_0000;
  parameter logic [31:0] DATA_SRAM_SIZE  = 32'h0000_1000;  // 4 KB (1024 words)

  parameter logic [31:0] AXI_PERIPH_BASE = 32'h4000_0000;
  parameter logic [31:0] AXI_PERIPH_SIZE = 32'h0000_4000;  // 16 KB total

  parameter logic [31:0] GPIO_BASE   = 32'h4000_0000;
  parameter logic [31:0] TIMER_BASE  = 32'h4000_1000;
  parameter logic [31:0] PWM_BASE    = 32'h4000_2000;
  parameter logic [31:0] UART_BASE   = 32'h4000_3000;
  parameter logic [31:0] PERIPH_SIZE = 32'h0000_1000;      // 4 KB decode window each

  // ---------------------------------------------------------------------
  // GPIO register offsets (from GPIO_BASE)
  // ---------------------------------------------------------------------
  parameter logic [3:0] GPIO_DATA_OUT = 4'h0;  // RW - output pin values
  parameter logic [3:0] GPIO_DATA_IN  = 4'h4;  // RO - sampled input pin values
  parameter logic [3:0] GPIO_DIR      = 4'h8;  // RW - 0=input, 1=output per bit
  parameter logic [3:0] GPIO_STATUS   = 4'hC;  // RO - reserved, reads 0

  // ---------------------------------------------------------------------
  // Timer register offsets (from TIMER_BASE)
  // ---------------------------------------------------------------------
  parameter logic [3:0] TIMER_CTRL   = 4'h0;   // RW - bit0=enable, bit1=mode
  parameter logic [3:0] TIMER_COUNT  = 4'h4;   // RO - live down-counter value
  parameter logic [3:0] TIMER_LOAD   = 4'h8;   // RW - reload value
  parameter logic [3:0] TIMER_STATUS = 4'hC;   // RW1C - bit0=expired flag

  // ---------------------------------------------------------------------
  // PWM register offsets (from PWM_BASE)
  // ---------------------------------------------------------------------
  parameter logic [3:0] PWM_CTRL   = 4'h0;     // RW - bit0=enable
  parameter logic [3:0] PWM_PERIOD = 4'h4;     // RW - period in clock cycles
  parameter logic [3:0] PWM_DUTY   = 4'h8;     // RW - high-time in clock cycles
  parameter logic [3:0] PWM_STATUS = 4'hC;     // RO - bit0=current output level

  // ---------------------------------------------------------------------
  // UART register offsets (from UART_BASE)
  // ---------------------------------------------------------------------
  parameter logic [3:0] UART_TXDATA = 4'h0;    // WO - write triggers TX of byte
  parameter logic [3:0] UART_RXDATA = 4'h4;    // RO - last received byte
  parameter logic [3:0] UART_STATUS = 4'h8;    // RO - bit0=tx_ready, bit1=rx_valid
  parameter logic [3:0] UART_CTRL   = 4'hC;    // RW - baud divisor

  // ---------------------------------------------------------------------
  // ALU operation encoding (shared between decoder/control and alu.sv)
  // ---------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLL  = 4'b0101,
    ALU_SRL  = 4'b0110,
    ALU_SRA  = 4'b0111,
    ALU_SLT  = 4'b1000,
    ALU_SLTU = 4'b1001
  } alu_op_e;

  // ---------------------------------------------------------------------
  // AXI4-Lite response codes used in this project (OKAY / SLVERR only)
  // ---------------------------------------------------------------------
  parameter logic [1:0] AXI_RESP_OKAY   = 2'b00;
  parameter logic [1:0] AXI_RESP_SLVERR = 2'b10;

  // ---------------------------------------------------------------------
  // RV32I base opcodes (instr[6:0])
  // ---------------------------------------------------------------------
  parameter logic [6:0] OPCODE_RTYPE  = 7'b0110011;  // register-register ALU ops
  parameter logic [6:0] OPCODE_ITYPE  = 7'b0010011;  // register-immediate ALU ops
  parameter logic [6:0] OPCODE_LOAD   = 7'b0000011;  // LB/LH/LW/LBU/LHU
  parameter logic [6:0] OPCODE_STORE  = 7'b0100011;  // SB/SH/SW
  parameter logic [6:0] OPCODE_BRANCH = 7'b1100011;  // BEQ/BNE/BLT/BGE/BLTU/BGEU
  parameter logic [6:0] OPCODE_JAL    = 7'b1101111;
  parameter logic [6:0] OPCODE_JALR   = 7'b1100111;
  parameter logic [6:0] OPCODE_LUI    = 7'b0110111;
  parameter logic [6:0] OPCODE_AUIPC  = 7'b0010111;
  parameter logic [6:0] OPCODE_SYSTEM = 7'b1110011;  // ECALL/EBREAK -- out of
                                                        // scope for this capstone,
                                                        // control_unit treats as NOP
                                                        // (explicit simplification,
                                                        // not silently dropped)

  // ---------------------------------------------------------------------
  // Writeback mux select (rv32i_core: what gets written back to rd)
  // ---------------------------------------------------------------------
  parameter logic [1:0] RESULT_ALU = 2'b00;  // ALU result (R-type/I-type/AUIPC)
  parameter logic [1:0] RESULT_MEM = 2'b01;  // Loaded data from memory
  parameter logic [1:0] RESULT_PC4 = 2'b10;  // PC+4 (JAL/JALR return address)
  parameter logic [1:0] RESULT_IMM = 2'b11;  // Immediate directly (LUI)

endpackage : soc_pkg