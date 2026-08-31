module tb_regfile;

    logic        clk = 0;
    logic        rst;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rd_data;
    logic        rd_we;
    logic [31:0] rs1_data, rs2_data;

    int errors = 0;

    regfile dut (.*);

    always #5 clk = ~clk;

    task automatic write_reg(input [4:0] addr, input [31:0] data);
        @(negedge clk);
        rd_addr = addr;
        rd_data = data;
        rd_we   = 1'b1;
        @(posedge clk);
        #1;
        rd_we   = 1'b0;
    endtask

    task automatic check_reg(input [4:0] addr, input [31:0] expected);
        rs1_addr = addr;
        #1;
        if (rs1_data !== expected) begin
            $error("FAIL x%0d: expected 0x%08h got 0x%08h", addr, expected, rs1_data);
            errors++;
        end else begin
            $display("PASS x%0d = 0x%08h", addr, rs1_data);
        end
    endtask

    initial begin
        rst = 1; rd_we = 0; rd_addr = 0; rd_data = 0; rs1_addr = 0; rs2_addr = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // Test 1: reset state - all 32 registers must read zero
        for (int i = 0; i < 32; i++) begin
            check_reg(i[4:0], 32'd0);
        end

        // Test 2: write then readback
        write_reg(5'd1, 32'h5AAD_5AAD);
        check_reg(5'd1, 32'h5AAD_5AAD);

        write_reg(5'd31, 32'h1234_5678);
        check_reg(5'd31, 32'h1234_5678);

        // Test 3: x0 is hardwired zero, even if a write to it is attempted
        write_reg(5'd0, 32'hFFFF_FFFF);
        check_reg(5'd0, 32'd0);

        // Test 4: simultaneous dual-port read
        write_reg(5'd5, 32'hAAAA_0000);
        write_reg(5'd6, 32'h0000_BBBB);
        rs1_addr = 5'd5;
        rs2_addr = 5'd6;
        #1;
        if (rs1_data !== 32'hAAAA_0000 || rs2_data !== 32'h0000_BBBB) begin
            $error("FAIL dual-port read: rs1=0x%08h rs2=0x%08h", rs1_data, rs2_data);
            errors++;
        end else begin
            $display("PASS dual-port read");
        end

        if (errors == 0) begin
            $display("=== TB_REGFILE: ALL TESTS PASSED ===");
        end else begin
            $display("=== TB_REGFILE: %0d ERROR(S) ===", errors);
        end

        $stop;
    end

endmodule : tb_regfile