`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_top
//////////////////////////////////////////////////////////////////////////////////

module tb_top;
  
  // clock generation
  bit clk;
  always #5 clk = ~clk;
  
  // interface instantiation
  intf i_intf(clk);
  
  // =========================================================================
  // MEMORY CONTROLLER - FIXED FOR INSTANT RESPONSE
  // =========================================================================
  
  // memory ready - responds instantly (combinational)
  always_comb begin
    i_intf.mem_ready = i_intf.mem_valid;
  end
  
  // memory read - instant response (combinational)
  always_comb begin
    i_intf.mem_rdata = i_intf.memory[i_intf.mem_addr[13:2]];
  end
  
  // memory write - sequential (on clock edge)
  always @(posedge clk) begin
    if (i_intf.mem_valid && i_intf.mem_ready && |i_intf.mem_wstrb) begin
      if (i_intf.mem_wstrb[0]) i_intf.memory[i_intf.mem_addr[13:2]][7:0]   <= i_intf.mem_wdata[7:0];
      if (i_intf.mem_wstrb[1]) i_intf.memory[i_intf.mem_addr[13:2]][15:8]  <= i_intf.mem_wdata[15:8];
      if (i_intf.mem_wstrb[2]) i_intf.memory[i_intf.mem_addr[13:2]][23:16] <= i_intf.mem_wdata[23:16];
      if (i_intf.mem_wstrb[3]) i_intf.memory[i_intf.mem_addr[13:2]][31:24] <= i_intf.mem_wdata[31:24];
    end
  end
  
  // =========================================================================
  // PicoRV32 CPU instantiation
  // =========================================================================
  
  picorv32 #(
    .ENABLE_COUNTERS(0),
    .ENABLE_REGS_DUALPORT(0),
    .ENABLE_REGS_16_31(1),
    .REGS_INIT_ZERO(1),
    .BARREL_SHIFTER(0),
    .TWO_STAGE_SHIFT(1),
    .CATCH_MISALIGN(1),
    .CATCH_ILLINSN(1)
  ) dut (
    .clk(clk),
    .resetn(i_intf.resetn),
    .mem_valid(i_intf.mem_valid),
    .mem_instr(),
    .mem_ready(i_intf.mem_ready),
    .mem_addr(i_intf.mem_addr),
    .mem_wdata(i_intf.mem_wdata),
    .mem_wstrb(i_intf.mem_wstrb),
    .mem_rdata(i_intf.mem_rdata),
    .trap(i_intf.trap),
    .irq(32'b0),
    .eoi()
  );

  always @(posedge i_intf.trap) begin
    $display("\n[%0t] *** CPU TRAP ASSERTED - execution halted (illegal instruction or misaligned access) ***\n", $time);
  end
  
  // connect internal signals for monitoring
  assign i_intf.cpuregs_write = dut.cpuregs_write;
  assign i_intf.latched_rd = dut.latched_rd;
  assign i_intf.cpuregs_wrdata = dut.cpuregs_wrdata;
  
  // =========================================================================
  // test execution
  // =========================================================================

  environment env;  // moved out of initial block for clarity / future reuse

  initial begin
    // initialize signals
    i_intf.resetn = 0;
    
    // create environment
    env = new(i_intf);
    
    #20;
    
    // run environment
    env.run();
    
    #100;
    
    i_intf.resetn = 1;
    $display("\n╔════════════════════════════════════════════════════════╗");
    $display("║  *** RESET RELEASED - CPU STARTING EXECUTION! ***      ║");
    $display("╚════════════════════════════════════════════════════════╝\n");
    
    #200000;

    // print pass/fail/skip summary now that the execution window is done
    env.print_final_summary();
    
    $display("\n╔════════════════════════════════════════════════════════╗");
    $display("║            SIMULATION COMPLETE                         ║");
    $display("╚════════════════════════════════════════════════════════╝\n");
    $finish;
  end
  
  // waveform dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end
  
endmodule
