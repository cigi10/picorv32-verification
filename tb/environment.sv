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

    // PHASE 4: Scoreboard builds coverage + the predicted-results queue.
    // NOTE: this happens BEFORE reset is released (before the DUT has run
    // at all) -- that's fine, since it only needs the instruction stream,
    // not DUT outputs, to build predictions.
    $display("\n>>> PHASE 4: Scoreboard Analysis (coverage + reference model build)...");
    scb.run();

    #50;

    // PHASE 5: Output monitor AND scoreboard's correctness checker now run
    // CONCURRENTLY, for the same window, while the DUT actually executes.
    // This is the fix: previously the scoreboard finished before reset was
    // even released, so it could never see real DUT writes. Now both are
    // forked together and torn down together.
    $display("\n>>> PHASE 5: Output Monitor + Correctness Checker running concurrently...");
    fork
      outmon.run();
      scb.check_outputs();  // runs forever, draining outmon2scb as writes arrive
    join_none

    $display("\n[ENV] All verification components initialized!\n");
  endtask

  // Call this from tb_top after the execution window (#15000) completes,
  // to print the pass/fail/skip summary. check_outputs() runs forever via
  // join_none above, so it needs to be told when to report -- tb_top calls
  // this directly on env.scb after the wait window.
  task print_final_summary();
    scb.print_check_summary();
  endtask

endclass