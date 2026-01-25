`timescale 1ns / 1ps


class input_monitor;
  virtual intf vif;
  mailbox driv2inmon;
  mailbox inmon2scb;  // Send to scoreboard
  
  int instr_count = 0;
  
  function new(virtual intf vif, mailbox driv2inmon, mailbox inmon2scb);
    this.vif = vif;
    this.driv2inmon = driv2inmon;
    this.inmon2scb = inmon2scb;
  endfunction
  
  task run();
    transaction trans;
    
    $display("\n[%0t] [INPUT MONITOR] Starting - Collecting loaded instructions", $time);
    
    // Collect all instructions from driver
while (driv2inmon.num() > 0) begin
      if (driv2inmon.num() > 0) begin
        driv2inmon.get(trans);
        
        // Forward to scoreboard for coverage tracking
        inmon2scb.put(trans);
        
        $display("[%0t] [INPUT MON] Tracked: %s (instr #%0d)", 
                 $time, trans.get_name(), instr_count);
        
        instr_count++;
      end else begin
        #1;  // Wait for more data
      end
    end
    
    $display("[%0t] [INPUT MONITOR] Finished - Tracked %0d instructions\n", 
             $time, instr_count);
  endtask
  
endclass
