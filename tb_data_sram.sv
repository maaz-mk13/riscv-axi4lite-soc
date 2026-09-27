module tb_data_sram;

    logic clk = 0;

    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        valid;
    logic [31:0] rdata;
    logic        ready;

    int errors = 0;

    always #5 clk = ~clk;

    data_sram dut (
        .clk   (clk),
        .addr  (addr),
        .wdata (wdata),
        .wstrb (wstrb),
        .valid (valid),
        .rdata (rdata),
        .ready (ready)
    );

    task automatic write_mem(
        input [31:0] a,
        input [31:0] d,
        input [3:0]  s
    );
        begin
            @(negedge clk);
            addr  = a;
            wdata = d;
            wstrb = s;
            valid = 1'b1;

            @(posedge clk);

            @(negedge clk);
            valid = 1'b0;
            wstrb = 4'b0000;
        end
    endtask

    task automatic read_mem(
        input [31:0] a,
        input [31:0] expected
    );
        begin
            @(negedge clk);
            addr  = a;
            wdata = 32'h0000_0000;
            wstrb = 4'b0000;
            valid = 1'b1;

            #1;

            if (rdata !== expected) begin
                $error("READ FAIL addr=%h expected=%h got=%h",
                       a, expected, rdata);
                errors++;
            end

            if (ready !== 1'b1) begin
                $error("READY FAIL addr=%h", a);
                errors++;
            end

            @(negedge clk);
            valid = 1'b0;
        end
    endtask

    initial begin

        addr  = 32'h0000_0000;
        wdata = 32'h0000_0000;
        wstrb = 4'b0000;
        valid = 1'b0;

        repeat(2) @(posedge clk);

        write_mem(32'h0000_0000, 32'h0000_0000, 4'b1111);
        write_mem(32'h0000_0000, 32'hFFFF_FFFF, 4'b1111);
        write_mem(32'h0000_0000, 32'hAAAA_AAAA, 4'b1111);
        write_mem(32'h0000_0000, 32'h5555_5555, 4'b1111);

        write_mem(32'h0000_0004, 32'h0000_00AA, 4'b0001);
        write_mem(32'h0000_0004, 32'h0000_BB00, 4'b0010);
        write_mem(32'h0000_0004, 32'h00CC_0000, 4'b0100);
        write_mem(32'h0000_0004, 32'hDD00_0000, 4'b1000);

        write_mem(32'h0000_0008, 32'h1234_5678, 4'b0001);
        write_mem(32'h0000_0008, 32'h8765_4321, 4'b0010);
        write_mem(32'h0000_0008, 32'hA5A5_A5A5, 4'b0100);
        write_mem(32'h0000_0008, 32'h5A5A_5A5A, 4'b1000);

        write_mem(32'h0000_000C, 32'hDEAD_BEEF, 4'b0011);
        write_mem(32'h0000_0010, 32'hCAFE_BABE, 4'b1100);
        write_mem(32'h0000_0014, 32'h1357_9BDF, 4'b0111);
        write_mem(32'h0000_0018, 32'h2468_ACF0, 4'b1110);
        write_mem(32'h0000_001C, 32'hFFFF_0000, 4'b1010);
        write_mem(32'h0000_0020, 32'h0000_FFFF, 4'b0101);

        write_mem(32'h0000_0000, 32'h1111_1111, 4'b1111);
        write_mem(32'h0000_0040, 32'h2222_2222, 4'b1111);
        write_mem(32'h0000_0100, 32'h3333_3333, 4'b1111);
        write_mem(32'h0000_0200, 32'h4444_4444, 4'b1111);
        write_mem(32'h0000_0400, 32'h5555_5555, 4'b1111);
        write_mem(32'h0000_0800, 32'h6666_6666, 4'b1111);
        write_mem(32'h0000_0FFC, 32'h7777_7777, 4'b1111);

        read_mem(32'h0000_0000, 32'h1111_1111);
        read_mem(32'h0000_0040, 32'h2222_2222);
        read_mem(32'h0000_0100, 32'h3333_3333);
        read_mem(32'h0000_0200, 32'h4444_4444);
        read_mem(32'h0000_0400, 32'h5555_5555);
        read_mem(32'h0000_0800, 32'h6666_6666);
        read_mem(32'h0000_0FFC, 32'h7777_7777);

        if (errors == 0)
            $display("=== TB_DATA_SRAM: ALL TESTS PASSED ===");
        else
            $display("=== TB_DATA_SRAM: %0d ERROR(S) ===", errors);

        $finish;
    end

endmodule
