`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 10:20:58 AM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top;
  
  // Clock generation
  bit clk;
  always #5 clk = ~clk;
  
  // Interface instantiation
  intf i_intf(clk);
  
   // Memory ready - combinational
  always_comb begin
    i_intf.mem_ready = i_intf.mem_valid;
  end
  
  // Memory read - combinational
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
  

  picorv32 #(
    .ENABLE_COUNTERS(0),
    .ENABLE_REGS_DUALPORT(0),
    .ENABLE_REGS_16_31(1),
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
    .trap(),
    .irq(32'b0),
    .eoi()
  );
  
  // Connect internal signals for monitoring
  assign i_intf.cpuregs_write = dut.cpuregs_write;
  assign i_intf.latched_rd = dut.latched_rd;
  assign i_intf.cpuregs_wrdata = dut.cpuregs_wrdata;
  

  
  initial begin
    environment env;
    
    // Initialize signals
    i_intf.resetn = 0;
    
    // Create environment
    env = new(i_intf);
    
    // Small delay for initialization
    #20;
    
    // Run environment 
    env.run();
    
    #100;
    
    i_intf.resetn = 1;
    $display("\n╔════════════════════════════════════════════════════════╗");
    $display("║  *** RESET RELEASED - CPU STARTING EXECUTION! ***      ║");
    $display("╚════════════════════════════════════════════════════════╝\n");
    
    // Let CPU execute
    #15000;
    
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
