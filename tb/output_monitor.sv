`timescale 1ns / 1ps

class output_monitor;
  virtual intf vif;
  mailbox outmon2scb;  // Send results to scoreboard
  
  int reg_write_count = 0;
  
  function new(virtual intf vif, mailbox outmon2scb);
    this.vif = vif;
    this.outmon2scb = outmon2scb;
  endfunction
  
  task run();
    transaction trans;
    
    $display("\n[%0t] [OUTPUT MONITOR] Starting - Watching CPU register writes", $time);
    
    // Wait for CPU to start executing
    @(posedge vif.resetn);
    $display("[%0t] [OUTPUT MON] CPU reset released, monitoring started", $time);
    
    // Monitor register writes for a reasonable time
    fork
      begin
        repeat(5000) begin  // Monitor for 5000 clock cycles
          @(posedge vif.clk);
          
          // Check if CPU wrote to a register
          if (vif.cpuregs_write && vif.latched_rd != 0) begin
            trans = new();
            trans.expected_rd = vif.latched_rd;
            trans.expected_result = vif.cpuregs_wrdata;
            
            $display("[%0t] [OUTPUT MON] Reg Write: x%0d <= 0x%08h", 
                     $time, trans.expected_rd, trans.expected_result);
            
            // Send to scoreboard for checking
            outmon2scb.put(trans);
            reg_write_count++;
          end
        end
      end
    join_none
    
    #4000;
    
    $display("[%0t] [OUTPUT MONITOR] Finished - Captured %0d register writes\n", 
             $time, reg_write_count);
  endtask
  
endclass
