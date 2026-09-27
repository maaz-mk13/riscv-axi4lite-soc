module tb_adapter_coverage;
  logic clk=0, rst;
  always #5 clk=~clk;

  logic [31:0] cpu_addr,cpu_wdata,cpu_rdata;
  logic [3:0] cpu_wstrb;
  logic cpu_valid,cpu_ready;
  logic [31:0] AWADDR,WDATA,ARADDR,RDATA;
  logic [3:0] WSTRB;
  logic [1:0] BRESP,RRESP;
  logic AWVALID,AWREADY,WVALID,WREADY,BVALID,BREADY;
  logic ARVALID,ARREADY,RVALID,RREADY;

  core_to_axi_master_adapter dut(.*);

  task automatic reset_dut;
    begin
      rst=1; cpu_valid=0; cpu_addr=0; cpu_wdata=0; cpu_wstrb=0;
      AWREADY=0; WREADY=0; BVALID=0; ARREADY=0; RVALID=0; RDATA=0;
      BRESP=0; RRESP=0;
      repeat(3) @(posedge clk);
      rst=0;
      @(posedge clk);
    end
  endtask

  task automatic write_both;
    begin
      cpu_addr=32'h40000000; cpu_wdata=32'h11111111; cpu_wstrb=4'hf; cpu_valid=1;
      wait(AWVALID && WVALID);
      AWREADY=1; WREADY=1;
      @(posedge clk);
      AWREADY=0; WREADY=0;
      wait(BREADY);
      BVALID=1;
      @(posedge clk);
      BVALID=0;
      cpu_valid=0;
      @(posedge clk);
    end
  endtask

  task automatic write_aw_first;
    begin
      cpu_addr=32'h40000004; cpu_wdata=32'h22222222; cpu_wstrb=4'hf; cpu_valid=1;
      wait(AWVALID && WVALID);
      AWREADY=1; WREADY=0;
      @(posedge clk);
      AWREADY=0;
      // AW is now done, WVALID remains high: exercise aw_done=1
      WREADY=1;
      @(posedge clk);
      WREADY=0;
      wait(BREADY);
      BVALID=1;
      @(posedge clk);
      BVALID=0;
      cpu_valid=0;
      @(posedge clk);
    end
  endtask

  task automatic write_w_first;
    begin
      cpu_addr=32'h40000008; cpu_wdata=32'h33333333; cpu_wstrb=4'hf; cpu_valid=1;
      wait(AWVALID && WVALID);
      AWREADY=0; WREADY=1;
      @(posedge clk);
      WREADY=0;
      // W is now done, AWVALID remains high: exercise w_done=1
      AWREADY=1;
      @(posedge clk);
      AWREADY=0;
      wait(BREADY);
      BVALID=1;
      @(posedge clk);
      BVALID=0;
      cpu_valid=0;
      @(posedge clk);
    end
  endtask

  task automatic read_delayed;
    begin
      cpu_addr=32'h40000000; cpu_wdata=0; cpu_wstrb=0; cpu_valid=1;
      wait(ARVALID);
      ARREADY=0;
      @(posedge clk); // ARVALID=1, ARREADY=0
      ARREADY=1;
      @(posedge clk); // handshake
      ARREADY=0;
      wait(RREADY);
      RDATA=32'hAAAAAAAA;
      RVALID=1;
      @(posedge clk);
      RVALID=0;
      cpu_valid=0;
      @(posedge clk);
    end
  endtask

  task automatic read_normal;
    begin
      cpu_addr=32'h40000010; cpu_wdata=0; cpu_wstrb=0; cpu_valid=1;
      wait(ARVALID);
      ARREADY=1;
      @(posedge clk);
      ARREADY=0;
      wait(RREADY);
      RDATA=32'hBBBBBBBB;
      RVALID=1;
      @(posedge clk);
      RVALID=0;
      cpu_valid=0;
      @(posedge clk);
    end
  endtask
task automatic toggle_stress;
    begin
        // -------------------------
        // WRITE: different addresses/data
        // -------------------------

        cpu_addr  = 32'h00000000;
        cpu_wdata = 32'h00000000;
        cpu_wstrb = 4'b1111;
        cpu_valid = 1'b1;

        AWREADY = 1'b1;
        WREADY  = 1'b1;
        BRESP   = 2'b00;

        @(posedge clk);

        cpu_addr  = 32'hFFFFFFFF;
        cpu_wdata = 32'hFFFFFFFF;
        BRESP     = 2'b01;

        @(posedge clk);

        cpu_addr  = 32'hAAAAAAAA;
        cpu_wdata = 32'hAAAAAAAA;
        BRESP     = 2'b10;

        @(posedge clk);

        cpu_addr  = 32'h55555555;
        cpu_wdata = 32'h55555555;
        BRESP     = 2'b11;

        @(posedge clk);

        cpu_valid = 1'b0;
        BVALID = 1'b1;

        @(posedge clk);

        BVALID = 1'b0;
        AWREADY = 1'b0;
        WREADY  = 1'b0;

        // -------------------------
        // READ: different addresses/data
        // -------------------------

        cpu_addr  = 32'hFFFFFFFF;
        cpu_wstrb = 4'b0000;
        cpu_valid = 1'b1;

        ARREADY = 1'b1;

        RRESP = 2'b00;
        RDATA = 32'h00000000;

        @(posedge clk);

        RRESP = 2'b01;
        RDATA = 32'hFFFFFFFF;

        @(posedge clk);

        RRESP = 2'b10;
        RDATA = 32'hAAAAAAAA;

        @(posedge clk);

        RRESP = 2'b11;
        RDATA = 32'h55555555;

        @(posedge clk);

        cpu_valid = 1'b0;
        RVALID = 1'b1;

        @(posedge clk);

        RVALID = 1'b0;
        ARREADY = 1'b0;

        @(posedge clk);
    end
endtask
task automatic condition_stress;
  begin
    // AWVALID=1, AWREADY=0
    cpu_addr  = 32'h40000030;
    cpu_wdata = 32'h12345678;
    cpu_wstrb = 4'hF;
    cpu_valid = 1'b1;

    AWREADY = 1'b0;
    WREADY  = 1'b1;

    @(posedge clk);

    // AW handshake
    AWREADY = 1'b1;

    @(posedge clk);

    AWREADY = 1'b0;
    WREADY  = 1'b0;

    wait(BREADY);

    // Delay BVALID
    repeat(2) @(posedge clk);
    BVALID = 1'b1;

    @(posedge clk);

    BVALID = 1'b0;
    cpu_valid = 1'b0;

    @(posedge clk);

    // READ: ARVALID=1, ARREADY=0
    cpu_addr  = 32'h40000034;
    cpu_wstrb = 4'b0000;
    cpu_valid = 1'b1;

    ARREADY = 1'b0;

    @(posedge clk);
    @(posedge clk);

    // AR handshake
    ARREADY = 1'b1;

    @(posedge clk);

    ARREADY = 1'b0;

    wait(RREADY);

    repeat(2) @(posedge clk);
    RDATA  = 32'hDEADBEEF;
    RVALID = 1'b1;

    @(posedge clk);

    RVALID = 1'b0;
    cpu_valid = 1'b0;

    @(posedge clk);
  end
endtask
task automatic write_response_delayed;
  begin
    cpu_addr  = 32'h40000020;
    cpu_wdata = 32'h12345678;
    cpu_wstrb = 4'hf;
    cpu_valid = 1'b1;

    wait(AWVALID && WVALID);

    AWREADY = 1'b1;
    WREADY  = 1'b1;

    @(posedge clk);

    AWREADY = 1'b0;
    WREADY  = 1'b0;

    // Stay in WRITE_RESP for several cycles
    repeat(3) @(posedge clk);

    BVALID = 1'b1;

    @(posedge clk);

    BVALID = 1'b0;
    cpu_valid = 1'b0;

    @(posedge clk);
  end
endtask
task automatic read_response_delayed;
  begin
    cpu_addr  = 32'h40000024;
    cpu_wdata = 32'h0;
    cpu_wstrb = 4'h0;
    cpu_valid = 1'b1;

    wait(ARVALID);

    ARREADY = 1'b1;

    @(posedge clk);

    ARREADY = 1'b0;

    // Stay in READ_DATA for several cycles
    repeat(3) @(posedge clk);

    RDATA  = 32'hCAFEBABE;
    RVALID = 1'b1;

    @(posedge clk);

    RVALID = 1'b0;
    cpu_valid = 1'b0;

    @(posedge clk);
  end
endtask
  initial begin
    reset_dut();
    write_both();
    write_aw_first();
    write_w_first();
    read_delayed();
    read_normal();
    // repeat to increase toggle activity
    write_aw_first();
    write_w_first();
    read_delayed();
    write_both();
    read_normal();
toggle_stress();
condition_stress();
write_response_delayed();
read_response_delayed();
    #20;
    $display("TB_ADAPTER_COVERAGE: DONE");
    $finish;
  end
endmodule
