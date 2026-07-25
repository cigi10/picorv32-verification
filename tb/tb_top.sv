`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_top
//////////////////////////////////////////////////////////////////////////////////


module tb_top;
  
  // Clock generation
  bit clk;
  always #5 clk = ~clk;
  
  // Interface instantiation
  intf i_intf(clk);
  
  // =========================================================================
  // MEMORY CONTROLLER - FIXED FOR INSTANT RESPONSE
  // =========================================================================
  
  // Memory ready - responds instantly (combinational)
  // Use always_comb because interface signals are 'logic' type
  always_comb begin
    i_intf.mem_ready = i_intf.mem_valid;
  end
  
  // Memory read - instant response (combinational)
  always_comb begin
    i_intf.mem_rdata = i_intf.memory[i_intf.mem_addr[13:2]];
  end
  
  // Memory write - sequential (on clock edge)
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

  // Previously .trap() was left unconnected, so a misaligned-access or
  // illegal-instruction trap halted the CPU with zero indication why --
  // execution just went quiet. Now it's visible.
  always @(posedge i_intf.trap) begin
    $display("\n[%0t] *** CPU TRAP ASSERTED - execution halted (illegal instruction or misaligned access) ***\n", $time);
  end
  
  // Connect internal signals for monitoring
  assign i_intf.cpuregs_write = dut.cpuregs_write;
  assign i_intf.latched_rd = dut.latched_rd;
  assign i_intf.cpuregs_wrdata = dut.cpuregs_wrdata;
  
  // =========================================================================
  // Test execution
  // =========================================================================

  environment env;  // moved out of initial block for clarity / future reuse

  initial begin
    // Initialize signals
    i_intf.resetn = 0;
    // Don't need to initialize mem_ready or mem_rdata - handled by always_comb
    
    // Create environment
    env = new(i_intf);
    
    // Small delay for initialization
    #20;
    
    // Run environment (loads all instructions, builds reference model,
    // prints coverage, and forks the output monitor + correctness checker
    // to run concurrently with DUT execution)
    env.run();
    
    // Environment setup is DONE - everything loaded, coverage printed,
    // checker is forked and waiting on outmon2scb
    #100;
    
    // NOW release reset - memory is already loaded, checker already forked!
    i_intf.resetn = 1;
    $display("\n╔════════════════════════════════════════════════════════╗");
    $display("║  *** RESET RELEASED - CPU STARTING EXECUTION! ***      ║");
    $display("╚════════════════════════════════════════════════════════╝\n");
    
    // Let CPU execute -- output monitor + correctness checker are running
    // concurrently in the background this whole window.
    // Bumped 15000 -> 40000 -> 200000: the previous window only ever
    // captured 16/50 checkable writes because the CPU was hitting a
    // misaligned-access trap partway through (see interface.sv/tb_top.sv
    // trap fix and transaction.sv address-alignment fix above) -- it
    // wasn't actually a timing problem. With that fixed, this margin
    // covers BARREL_SHIFTER(0)+TWO_STAGE_SHIFT(1)'s slow, cycles-per-bit
    // SLLI/SRLI cost with room to spare.
    #200000;

    // Print pass/fail/skip summary now that the execution window is done
    env.print_final_summary();
    
    $display("\n╔════════════════════════════════════════════════════════╗");
    $display("║            SIMULATION COMPLETE                         ║");
    $display("╚════════════════════════════════════════════════════════╝\n");
    $finish;
  end
  
  // Waveform dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end
  
endmodule