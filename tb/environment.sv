`timescale 1ns / 1ps

class environment;
  // Components
  generator gen;
  driver driv;
  input_monitor inmon;
  output_monitor outmon;
  scoreboard scb;
  
  // Mailboxes for communication
  mailbox gen2driv;
  mailbox driv2inmon;
  mailbox inmon2scb;
  mailbox outmon2scb;
  
  // Interface
  virtual intf vif;
  
  function new(virtual intf vif);
    this.vif = vif;
    
    // Create mailboxes
    gen2driv = new();
    driv2inmon = new();
    inmon2scb = new();
    outmon2scb = new();
    
    // Create components
    gen = new(gen2driv);
    driv = new(vif, gen2driv, driv2inmon);
    inmon = new(vif, driv2inmon, inmon2scb);
    outmon = new(vif, outmon2scb);
    scb = new(inmon2scb, outmon2scb);
  endfunction
  
  task run();
    $display("\n");
    $display("╔════════════════════════════════════════════════════════╗");
    $display("║   RISC-V PICORV32 VERIFICATION ENVIRONMENT STARTING    ║");
    $display("╚════════════════════════════════════════════════════════╝");
    $display("\n");
    
    fork
      // PHASE 1: Generate all instructions
      begin
        $display(">>> PHASE 1: Generating Instructions...");
        gen.run();
        $display("[ENV] Generator finished, mailbox has %0d transactions", gen2driv.num());
      end
    join
    
    #100;
    
    fork
      // PHASE 2: Load instructions into memory
      begin
        $display("\n>>> PHASE 2: Loading Instructions into Memory...");
        driv.run();
      end
    join
    
    #50;
    
    fork
      // PHASE 3: Input monitor tracks
      begin
        $display("\n>>> PHASE 3: Input Monitor Tracking...");
        inmon.run();
      end
    join
    
    #50;
    
    // PHASE 4: Scoreboard 
    $display("\n>>> PHASE 4: Scoreboard Analysis...");
    scb.run();  
    
    #50;
    
    // PHASE 5: Output monitor in background
    $display("\n>>> PHASE 5: Output Monitor Ready...");
    fork
      outmon.run();
    join_none
    
    $display("\n[ENV] All verification components initialized!\n");
  endtask
  
endclass
