`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: scoreboard
//
// FULL REFERENCE MODEL - tracks golden register file + golden memory + PC,
// predicts expected results in program order, checks against real DUT
// writes captured by output_monitor.
//
// KNOWN LIMITATIONS (documented on purpose, not hidden):
//  1. PC/order tracking assumes straight-line execution. This holds for
//     THIS program because JAL is the last real instruction generated --
//     if a jump/branch executed mid-program, subsequent golden predictions
//     would desync from actual DUT execution order. A general-purpose
//     version would need to track control flow, not just increment PC.
//  2. STORE (SB/SH/SW) writes rd=0, so there is no register write to
//     compare against -- output_monitor only observes register writes,
//     not memory-bus writes. STORE updates the golden memory model (so
//     later LOADs predict correctly) but is not itself checked. Checking
//     STORE would need a separate memory-write monitor snooping
//     mem_valid/mem_wstrb/mem_addr/mem_wdata on the DUT bus.
//  3. Uninitialized registers are guaranteed to reset to 0: tb_top.sv now
//     instantiates picorv32 with REGS_INIT_ZERO(1). (Previously this was
//     left at PicoRV32's default of 0 -- meaning the register file did
//     NOT reset to zero -- while this model assumed it did. That gap is
//     what caused loads/stores through never-written registers like x26,
//     x29 to compute unpredictable addresses and read back stale
//     instruction words, eventually tripping a misalignment trap.)
//////////////////////////////////////////////////////////////////////////////////

class scoreboard;
  mailbox inmon2scb;
  mailbox outmon2scb;

  // Golden reference state
  bit [31:0] golden_regs [0:31];
  bit [31:0] golden_mem  [0:1023];  // mirrors interface's memory array
  bit [31:0] golden_pc;             // tracks PROGADDR_RESET + 4*n

  // Coverage counters
  int addi_cnt = 0, lui_cnt = 0, auipc_cnt = 0;
  int add_cnt = 0, sub_cnt = 0, xor_r_cnt = 0, or_r_cnt = 0, and_r_cnt = 0;
  int xori_cnt = 0, ori_cnt = 0, andi_cnt = 0;
  int slli_cnt = 0, srli_cnt = 0;
  int lw_cnt = 0, lh_cnt = 0, lb_cnt = 0;
  int sw_cnt = 0, sh_cnt = 0, sb_cnt = 0;
  int jal_cnt = 0;
  int total_cnt = 0;

  // Correctness-checking counters
  int check_pass_cnt = 0;
  int check_fail_cnt = 0;
  int check_skipped_cnt = 0;  // only for truly unrecognized instructions now

  typedef struct {
    bit [4:0]  rd;
    bit [31:0] val;
    string     name;
    bit        checkable;
  } expected_t;

  expected_t expected_q[$];

  function new(mailbox inmon2scb, mailbox outmon2scb);
    this.inmon2scb = inmon2scb;
    this.outmon2scb = outmon2scb;

    for (int i = 0; i < 32; i++)   golden_regs[i] = 0;
    for (int i = 0; i < 1024; i++) golden_mem[i]  = 0;
    golden_pc = 32'h0;  // matches PROGADDR_RESET default
  endfunction

  //==========================================================================
  // PHASE 1: drain inmon2scb, count coverage AND build the predicted-
  // results queue (including memory-model side effects) in program order.
  //==========================================================================
  task run();
    transaction trans;

    $display("\n[%0t] [SCOREBOARD] Starting", $time);
    $display("[SCOREBOARD] Phase 1: Collecting instructions for coverage + building reference model");

    while (inmon2scb.num() > 0) begin
      inmon2scb.get(trans);
      count_instruction(trans);
      build_expected(trans);
      total_cnt++;
    end

    $display("[SCOREBOARD] Collected %0d instructions total", total_cnt);
    $display("[SCOREBOARD] %0d expected results queued for correctness checking",
              expected_q.size());

    print_coverage_report();

    $display("\n[SCOREBOARD] Coverage analysis complete!");
    $display("[SCOREBOARD] Finished\n");
  endtask

  //==========================================================================
  // Golden memory model helpers -- mirror the DUT's byte/halfword/word
  // addressing (word index = addr[11:2], byte offset = addr[1:0]).
  //==========================================================================
  function void golden_mem_write(input bit [31:0] addr, input bit [31:0] wdata, input string name);
    int word_idx = addr[11:2];
    bit [1:0] byte_off = addr[1:0];

    case (name)
      "SB": begin
        case (byte_off)
          2'b00: golden_mem[word_idx][7:0]   = wdata[7:0];
          2'b01: golden_mem[word_idx][15:8]  = wdata[7:0];
          2'b10: golden_mem[word_idx][23:16] = wdata[7:0];
          2'b11: golden_mem[word_idx][31:24] = wdata[7:0];
        endcase
      end
      "SH": begin
        if (byte_off[1]) golden_mem[word_idx][31:16] = wdata[15:0];
        else              golden_mem[word_idx][15:0]  = wdata[15:0];
      end
      "SW": golden_mem[word_idx] = wdata;
    endcase
  endfunction

  function bit [31:0] golden_mem_read(input bit [31:0] addr, input string name);
    int word_idx = addr[11:2];
    bit [1:0] byte_off = addr[1:0];
    bit [31:0] word = golden_mem[word_idx];

    case (name)
      "LB": case (byte_off)
        2'b00: return {{24{word[7]}},  word[7:0]};
        2'b01: return {{24{word[15]}}, word[15:8]};
        2'b10: return {{24{word[23]}}, word[23:16]};
        2'b11: return {{24{word[31]}}, word[31:24]};
      endcase
      "LBU": case (byte_off)
        2'b00: return {24'h0, word[7:0]};
        2'b01: return {24'h0, word[15:8]};
        2'b10: return {24'h0, word[23:16]};
        2'b11: return {24'h0, word[31:24]};
      endcase
      "LH":  return byte_off[1] ? {{16{word[31]}}, word[31:16]} : {{16{word[15]}}, word[15:0]};
      "LHU": return byte_off[1] ? {16'h0, word[31:16]}          : {16'h0, word[15:0]};
      "LW":  return word;
      default: return 32'hx;
    endcase
  endfunction

  //==========================================================================
  // Reference model: predict result for ALU/immediate/LUI ops that don't
  // need memory or PC (those are handled directly in build_expected).
  //==========================================================================
  function bit [31:0] predict_result(input transaction trans, output bit checkable);
    bit [31:0] result;
    bit signed [31:0] simm;  // sign-extended imm[11:0] -- built explicitly into a
                              // full 32-bit value so it doesn't get silently
                              // reinterpreted as unsigned when combined with
                              // golden_regs[] below (a real bug: $signed(imm[11:0])
                              // mixed directly with an unsigned operand loses its
                              // signedness under SystemVerilog's usual arithmetic
                              // conversion rules -- this is why ADDI with a
                              // negative immediate was mispredicted as unsigned).
    checkable = 1;
    simm = {{20{trans.imm[11]}}, trans.imm[11:0]};

    case (trans.get_name())
      "ADDI": result = golden_regs[trans.rs1] + simm;
      "XORI": result = golden_regs[trans.rs1] ^ simm;
      "ORI":  result = golden_regs[trans.rs1] | simm;
      "ANDI": result = golden_regs[trans.rs1] & simm;
      "SLLI": result = golden_regs[trans.rs1] << trans.imm[4:0];
      "SRLI": result = golden_regs[trans.rs1] >> trans.imm[4:0];
      "ADD":  result = golden_regs[trans.rs1] + golden_regs[trans.rs2];
      "SUB":  result = golden_regs[trans.rs1] - golden_regs[trans.rs2];
      "XOR":  result = golden_regs[trans.rs1] ^ golden_regs[trans.rs2];
      "OR":   result = golden_regs[trans.rs1] | golden_regs[trans.rs2];
      "AND":  result = golden_regs[trans.rs1] & golden_regs[trans.rs2];
      "LUI":  result = trans.imm[31:12] << 12;
      default: begin
        result = 32'hx;
        checkable = 0;
      end
    endcase

    return result;
  endfunction

  // Build the expected-value queue entry for one transaction, updating
  // golden_regs / golden_mem / golden_pc so later instructions predict
  // against correct evolved state.
  function void build_expected(input transaction trans);
    bit [31:0] predicted, addr;
    bit        checkable;
    expected_t e;
    string     name = trans.get_name();

    // STORE: memory side-effect only, no register to check (rd=0)
    if (name == "SB" || name == "SH" || name == "SW") begin
      addr = golden_regs[trans.rs1] + trans.imm[11:0];
      golden_mem_write(addr, golden_regs[trans.rs2], name);
      golden_pc += 4;
      return;
    end

    // x0 is never architecturally written -- nothing to check, but PC
    // still advances (covers any future rd=0 case beyond STORE)
    if (trans.rd == 0) begin
      golden_pc += 4;
      return;
    end

    case (name)
      "LB", "LH", "LW", "LBU", "LHU": begin
        addr = golden_regs[trans.rs1] + trans.imm[11:0];
        predicted = golden_mem_read(addr, name);
        checkable = 1;
      end
      "AUIPC": begin
        predicted = golden_pc + (trans.imm[31:12] << 12);
        checkable = 1;
      end
      "JAL": begin
        // Return address. NOTE: does not model the actual jump target --
        // see class-level comment on the straight-line-order limitation.
        predicted = golden_pc + 4;
        checkable = 1;
      end
      default: predicted = predict_result(trans, checkable);  // ALU/immediate/LUI
    endcase

    e.rd        = trans.rd;
    e.val       = predicted;
    e.name      = name;
    e.checkable = checkable;
    expected_q.push_back(e);

    if (checkable)
      golden_regs[trans.rd] = predicted;

    golden_pc += 4;
  endfunction

  //==========================================================================
  // Runs CONCURRENTLY with output_monitor after reset release (forked in
  // environment.sv): drain outmon2scb as real writes arrive, compare
  // against expected_q in program order.
  //==========================================================================
  task check_outputs();
    transaction actual;
    expected_t  exp;

    $display("[%0t] [SCOREBOARD-CHECK] Correctness checker started, %0d entries queued",
              $time, expected_q.size());

    forever begin
      outmon2scb.get(actual);

      if (expected_q.size() == 0) begin
        $display("[%0t] [SCOREBOARD-CHECK] WARNING: unexpected write x%0d = 0x%08h, no expected entry queued",
                  $time, actual.expected_rd, actual.expected_result);
        continue;
      end

      exp = expected_q.pop_front();

      if (!exp.checkable) begin
        $display("[%0t] [SCOREBOARD-CHECK] SKIP (%s not modeled): x%0d <= 0x%08h",
                  $time, exp.name, actual.expected_rd, actual.expected_result);
        check_skipped_cnt++;
        continue;
      end

      if (exp.rd == actual.expected_rd && exp.val === actual.expected_result) begin
        $display("[%0t] [SCOREBOARD-CHECK] PASS (%s): x%0d = 0x%08h",
                  $time, exp.name, actual.expected_rd, actual.expected_result);
        check_pass_cnt++;
      end else begin
        $display("[%0t] [SCOREBOARD-CHECK] *** MISMATCH *** (%s): expected x%0d=0x%08h, got x%0d=0x%08h",
                  $time, exp.name, exp.rd, exp.val, actual.expected_rd, actual.expected_result);
        check_fail_cnt++;
      end
    end
  endtask

  task print_check_summary();
    $display("\n");
    $display("╔═══════════════════════════════════════════════════════════╗");
    $display("║          CORRECTNESS CHECK SUMMARY                       ║");
    $display("╠═══════════════════════════════════════════════════════════╣");
    $display("║ PASS    : %0d", check_pass_cnt);
    $display("║ FAIL    : %0d", check_fail_cnt);
    $display("║ SKIPPED : %0d  (unrecognized instruction, should be ~0)", check_skipped_cnt);
    $display("║ UNCHECKED (never observed): %0d", expected_q.size());
    $display("║ (Note: STORE writes are not checked here -- no register");
    $display("║  write is generated for them. See class header comment.)");
    if (expected_q.size() > 0)
      $display("║ *** WARNING: execution window ended before all predicted");
      $display("║     results were observed -- CPU may have trapped/stalled.");
    $display("╚═══════════════════════════════════════════════════════════╝\n");
  endtask

  //==========================================================================
  // Coverage counting (unchanged)
  //==========================================================================
  function void count_instruction(input transaction trans);
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
      "JAL":   jal_cnt++;
    endcase
  endfunction

  task print_coverage_report();
    int covered_types = 0;
    real coverage_pct;
    int NUM_TYPES;
    NUM_TYPES = 16;  // 15 RV32I categories + JAL

    $display("\n");
    $display("╔═══════════════════════════════════════════════════════════╗");
    $display("║          INSTRUCTION COVERAGE REPORT                     ║");
    $display("╠═══════════════════════════════════════════════════════════╣");
    $display("║ Instruction     │  Count  │  Status                      ║");
    $display("╟─────────────────┼─────────┼──────────────────────────────╢");

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

    if (lui_cnt > 0) covered_types++;
    $display("║ LUI             │   %3d   │  %s  ║", lui_cnt,
             lui_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");

    if (auipc_cnt > 0) covered_types++;
    $display("║ AUIPC           │   %3d   │  %s  ║", auipc_cnt,
             auipc_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");

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

    if ((lw_cnt + lh_cnt + lb_cnt) > 0) covered_types++;
    $display("║ LOAD (LW/LH/LB) │   %3d   │  %s  ║", lw_cnt + lh_cnt + lb_cnt,
             (lw_cnt + lh_cnt + lb_cnt) > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");

    if ((sw_cnt + sh_cnt + sb_cnt) > 0) covered_types++;
    $display("║ STORE (SW/SH/SB)│   %3d   │  %s  ║", sw_cnt + sh_cnt + sb_cnt,
             (sw_cnt + sh_cnt + sb_cnt) > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");

    if (jal_cnt > 0) covered_types++;
    $display("║ JAL             │   %3d   │  %s  ║", jal_cnt,
             jal_cnt > 0 ? "✓ COVERED        " : "✗ NOT COVERED    ");

    $display("╟─────────────────┼─────────┼──────────────────────────────╢");
    $display("║ TOTAL INSTR     │   %3d   │                              ║", total_cnt);

    coverage_pct = (real'(covered_types) / real'(NUM_TYPES)) * 100.0;

    $display("║ COVERAGE        │ %2d/%2d   │  %5.1f%% instruction types   ║",
             covered_types, NUM_TYPES, coverage_pct);

    if (coverage_pct >= 100.0) begin
      $display("╟─────────────────┴─────────┴──────────────────────────────╢");
      $display("║   ALL %2d INSTRUCTION TYPE CATEGORIES EXERCISED           ║", NUM_TYPES);
    end

    $display("╚═══════════════════════════════════════════════════════════╝");
    $display("\n");
  endtask

endclass