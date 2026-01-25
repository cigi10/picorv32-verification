`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 10:15:05 AM
// Design Name: 
// Module Name: scoreboard
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


class scoreboard;
  mailbox inmon2scb;   // Instructions that were loaded
  mailbox outmon2scb;  // Register writes from CPU
  
  // Register file model
  bit [31:0] reg_file [0:31];
  
  // Coverage counters
  int addi_cnt = 0, lui_cnt = 0, auipc_cnt = 0;
  int add_cnt = 0, sub_cnt = 0, xor_r_cnt = 0, or_r_cnt = 0, and_r_cnt = 0;
  int xori_cnt = 0, ori_cnt = 0, andi_cnt = 0;
  int slli_cnt = 0, srli_cnt = 0;
  int lw_cnt = 0, lh_cnt = 0, lb_cnt = 0;
  int sw_cnt = 0, sh_cnt = 0, sb_cnt = 0;
  int total_cnt = 0;
  

  function new(mailbox inmon2scb, mailbox outmon2scb);
    this.inmon2scb = inmon2scb;
    this.outmon2scb = outmon2scb;
    
    // Initialize register file (x0 = 0 always)
    for (int i = 0; i < 32; i++) reg_file[i] = 0;
  endfunction
  
  task run();
    transaction trans;
    
    $display("\n[%0t] [SCOREBOARD] Starting", $time);
    
    // Phase 1: Collect and count all input instructions
    $display("[SCOREBOARD] Phase 1: Collecting instructions for coverage");
    
    // Collect all available instructions (input monitor already forwarded them)
    while (inmon2scb.num() > 0) begin
      inmon2scb.get(trans);
      count_instruction(trans);
      total_cnt++;
    end
    
    $display("[SCOREBOARD] Collected %0d instructions total", total_cnt);
    
    // Print coverage report
    print_coverage_report();
    
    // Phase 2: Could monitor outputs here if needed
    $display("\n[SCOREBOARD] Coverage analysis complete!");
    
    $display("[SCOREBOARD] Finished\n");
  endtask
  
  // Count each instruction type for coverage
  function void count_instruction(transaction trans);
    string name = trans.get_name();
    
    case (name)
      "ADDI":  addi_cnt++;
      "LUI":   lui_cnt++;
      "AUIPC": auipc_cnt++;
      "ADD":   add_cnt++;
      "SUB":   sub_cnt++;
      "XOR":   xor_r_cnt++;
      "OR":    or_r_cnt++;
      "AND":   and_r_cnt++;
      "XORI":  xori_cnt++;
      "ORI":   ori_cnt++;
      "ANDI":  andi_cnt++;
      "SLLI":  slli_cnt++;
      "SRLI":  srli_cnt++;
      "LW":    lw_cnt++;
      "LH":    lh_cnt++;
      "LB":    lb_cnt++;
      "SW":    sw_cnt++;
      "SH":    sh_cnt++;
      "SB":    sb_cnt++;
    endcase
  endfunction
  
  task print_coverage_report();
    int covered_types = 0;
    real coverage_pct;
    
    $display("\n");
    $display("╔═══════════════════════════════════════════════════════════╗");
    $display("║          INSTRUCTION COVERAGE REPORT                     ║");
    $display("╠═══════════════════════════════════════════════════════════╣");
    $display("║ Instruction     │  Count  │  Status                      ║");
    $display("╟─────────────────┼─────────┼──────────────────────────────╢");
    
    // I-Type ALU
    if (addi_cnt > 0) covered_types++;
    $display("║ ADDI            │   %3d   │  %s  ║", addi_cnt, 
             addi_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (xori_cnt > 0) covered_types++;
    $display("║ XORI            │   %3d   │  %s  ║", xori_cnt, 
             xori_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (ori_cnt > 0) covered_types++;
    $display("║ ORI             │   %3d   │  %s  ║", ori_cnt, 
             ori_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (andi_cnt > 0) covered_types++;
    $display("║ ANDI            │   %3d   │  %s  ║", andi_cnt, 
             andi_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (slli_cnt > 0) covered_types++;
    $display("║ SLLI            │   %3d   │  %s  ║", slli_cnt, 
             slli_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (srli_cnt > 0) covered_types++;
    $display("║ SRLI            │   %3d   │  %s  ║", srli_cnt, 
             srli_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    // U-Type
    if (lui_cnt > 0) covered_types++;
    $display("║ LUI             │   %3d   │  %s  ║", lui_cnt, 
             lui_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (auipc_cnt > 0) covered_types++;
    $display("║ AUIPC           │   %3d   │  %s  ║", auipc_cnt, 
             auipc_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    // R-Type
    if (add_cnt > 0) covered_types++;
    $display("║ ADD             │   %3d   │  %s  ║", add_cnt, 
             add_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (sub_cnt > 0) covered_types++;
    $display("║ SUB             │   %3d   │  %s  ║", sub_cnt, 
             sub_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (xor_r_cnt > 0) covered_types++;
    $display("║ XOR             │   %3d   │  %s  ║", xor_r_cnt, 
             xor_r_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (or_r_cnt > 0) covered_types++;
    $display("║ OR              │   %3d   │  %s  ║", or_r_cnt, 
             or_r_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (and_r_cnt > 0) covered_types++;
    $display("║ AND             │   %3d   │  %s  ║", and_r_cnt, 
             and_r_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    // Loads/Stores
    if (lw_cnt > 0) covered_types++;
    $display("║ LOAD (LW/LH/LB) │   %3d   │  %s  ║", lw_cnt + lh_cnt + lb_cnt, 
             (lw_cnt + lh_cnt + lb_cnt) > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    if (sw_cnt > 0) covered_types++;
    $display("║ STORE (SW/SH/SB)│   %3d   │  %s  ║", sw_cnt + sh_cnt + sb_cnt, 
             (sw_cnt + sh_cnt + sb_cnt) > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");
    
    $display("╟─────────────────┼─────────┼──────────────────────────────╢");
    $display("║ TOTAL INSTR     │   %3d   │                              ║", total_cnt);
    
    coverage_pct = (real'(covered_types) / 15.0) * 100.0;
    $display("║ COVERAGE        │  %2d/15  │  %5.1f%% instruction types   ║", 
             covered_types, coverage_pct);
    $display("╚═══════════════════════════════════════════════════════════╝");
    $display("\n");
  endtask
  
endclass
