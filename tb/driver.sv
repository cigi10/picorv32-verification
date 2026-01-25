`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 10:12:49 AM
// Design Name: 
// Module Name: driver
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

class driver;
  virtual intf vif;
  mailbox gen2driv;
  mailbox driv2inmon;  // Send loaded instructions to input monitor
  
  int instruction_count = 0;
  
  function new(virtual intf vif, mailbox gen2driv, mailbox driv2inmon);
    this.vif = vif;
    this.gen2driv = gen2driv;
    this.driv2inmon = driv2inmon;
  endfunction
  
  task run();
    transaction trans;
    
    $display("\n[%0t] [DRIVER] Starting - Loading instructions into memory", $time);
    $display("[%0t] [DRIVER] Mailbox has %0d items", $time, gen2driv.num());
    
    // Check if mailbox is empty
    if (gen2driv.num() == 0) begin
      $display("[%0t] [DRIVER] ERROR: Mailbox is empty! Generator didn't run properly!", $time);
      return;
    end
    
    // Load ALL instructions into memory
    while (gen2driv.num() > 0) begin
      gen2driv.get(trans);
      
      // Write instruction to memory at current PC
      vif.memory[instruction_count] = trans.instruction;
      
      $display("[%0t] [DRIVER] Loaded instr[%0d] @ 0x%08h: 0x%08h (%s)", 
               $time, instruction_count, instruction_count*4, 
               trans.instruction, trans.get_name());
      
      // Send copy to input monitor for tracking
      driv2inmon.put(trans);
      
      instruction_count++;
    end
    
    // Add infinite loop at end to stop CPU
    vif.memory[instruction_count] = 32'h0000006f;  // JAL x0, 0 (infinite loop)
    $display("[%0t] [DRIVER] Loaded HALT @ instr[%0d]", $time, instruction_count);
    
    $display("[%0t] [DRIVER] Finished - Loaded %0d instructions into memory\n", 
             $time, instruction_count);
  endtask
  
endclass
