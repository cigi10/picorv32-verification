# PicoRV32 RISC-V Core Functional Verification

> Layered SystemVerilog testbench achieving **100% RV32I instruction-type coverage** with a fully self-checking scoreboard.

## Overview

This project implements a layered functional verification environment for the PicoRV32 RISC-V processor core in SystemVerilog. It combines constrained-random and directed stimulus generation, a golden reference model, automated correctness checking, and instruction-type coverage tracking.

**Key Achievement:** 100% instruction coverage (16/16 RV32I categories) with 49/49 correctness checks passing and a clean, trap-free simulation finish.

## Project Stats

| Metric | Value |
|---|---|
| Instruction Coverage | 100% (16/16 types) |
| Instructions Generated | 53 (50 stimulus + 3 phase markers, +1 halt) |
| Correctness Checks | 49/49 PASS, 0 FAIL, 0 SKIPPED, 0 UNCHECKED |
| Verification Architecture | Layered testbench, mailbox-connected |
| Methodology | Coverage-driven + self-checking scoreboard |
| DUT | PicoRV32 (RV32I, `REGS_INIT_ZERO=1`) |

## Architecture

### 1. Top-level layered testbench

<img width="1920" height="1080" alt="5" src="https://github.com/user-attachments/assets/629d5265-530c-4fb2-8db0-4c6b4c7ea3cb" />


### 2. Generator: 3-phase stimulus

<img width="1920" height="1080" alt="6" src="https://github.com/user-attachments/assets/4b7ee6a3-5e1e-4b2a-99a0-7b029f230163" />

### 3. Execution timeline

<img width="1920" height="1080" alt="7" src="https://github.com/user-attachments/assets/547b394d-f53d-4430-8096-01eb4ad88a98" />

### 4. Scoreboard reference model

<img width="1920" height="1080" alt="8" src="https://github.com/user-attachments/assets/76127f61-deb4-428d-bd8f-619223fd40b2" />

## Coverage Results

```
╔══════════════════════════════════════════════════════════╗
║          INSTRUCTION COVERAGE REPORT                     ║
╠══════════════════════════════════════════════════════════╣
║ Instruction     │  Count  │  Status                      ║
╟─────────────────┼─────────┼──────────────────────────────╢
║ ADDI            │    10   │   COVERED                    ║
║ XORI            │     1   │   COVERED                    ║
║ ORI             │     1   │   COVERED                    ║
║ ANDI            │     1   │   COVERED                    ║
║ SLLI            │     8   │   COVERED                    ║
║ SRLI            │     1   │   COVERED                    ║
║ LUI             │     1   │   COVERED                    ║
║ AUIPC           │     2   │   COVERED                    ║
║ ADD             │     6   │   COVERED                    ║
║ SUB             │     5   │   COVERED                    ║
║ XOR             │     1   │   COVERED                    ║
║ OR              │     2   │   COVERED                    ║
║ AND             │     3   │   COVERED                    ║
║ LOAD (LW/LH/LB) │     5   │   COVERED                    ║
║ STORE (SW/SH/SB)│     4   │   COVERED                    ║
║ JAL             │     1   │   COVERED                    ║
╟─────────────────┼─────────┼──────────────────────────────╢
║ TOTAL INSTR     │    53   │                              ║
║ COVERAGE        │ 16/16   │  100.0% instruction types    ║
╚══════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════╗
║          CORRECTNESS CHECK SUMMARY                        ║
╠═══════════════════════════════════════════════════════════╣
║ PASS    : 49
║ FAIL    : 0
║ SKIPPED : 0
║ UNCHECKED (never observed): 0
╚═══════════════════════════════════════════════════════════╝
```

## File Structure

```
picorv32-verification/
├── rtl/
│   └── picorv32.v              # DUT (PicoRV32 core)
├── tb/
│   ├── tb_top.sv               # Top-level testbench, clk/reset, mem controller
│   ├── interface.sv            # Virtual interface + memory model
│   ├── environment.sv          # Instantiates & connects all TB components
│   ├── generator.sv            # 3-phase stimulus generator
│   ├── driver.sv               # Loads instructions into memory
│   ├── input_monitor.sv        # Tracks instruction stream
│   ├── output_monitor.sv       # Observes CPU register writes
│   ├── scoreboard.sv           # Golden reference model + coverage + checker
│   └── transaction.sv          # Instruction transaction class
└── diagrams/
        ├── 01_top_level_architecture.png   
        ├── 02_generator_phases.png         
        ├── 03_execution_timeline.png       
        └── 04_scoreboard_internals.png     
```

## How It Works

### 1. Generation (3 phases)
- **Phase 1:** ADDI x1..x10 with known immediates: establishes ground truth for later ALU ops
- **Phase 2:** 30 constrained-random instructions across ALU, load/store, and logic ops
- **Phase 3:** Directed tests for instruction types the random phase doesn't reliably hit (LUI, AUIPC, all immediate ops, JAL) plus store variants

### 2. Execution flow
```
Generator ──▶ Driver ──┬──▶ Input Monitor ─┐
                        │                    ▼
                        ▼                Scoreboard
                       DUT                   ▲
                        │                    │
                        └──▶ Output Monitor ┘
```
Loading and coverage-model construction happen *before* reset is released; the correctness checker is already forked and waiting when the CPU starts executing, so no writes are missed.

### 3. Reference-model checking
The scoreboard is a **full golden model**, not a counter: it tracks 32 golden registers, a 1024-word golden memory, and PC, predicting each instruction's result in program order and comparing it against the real DUT register write as it's observed.

## Running the Simulation

### Prerequisites
- Vivado 2025.2 (or ModelSim/QuestaSim with SystemVerilog support)

### Steps
```tcl
create_project picorv32_verif ./project -part xc7a35tcpg236-1
add_files -fileset sources_1 rtl/picorv32.v
add_files -fileset sim_1 tb/*.sv
set_property file_type SystemVerilog [get_files *.sv]
launch_simulation
run all
```

### Expected Output
- Phase 1–3: instruction generation, memory load, input tracking
- Phase 4: coverage report (100%, 16/16)
- Phase 5: reset release, concurrent output monitoring + correctness checking
- Final summary: 49/49 PASS, clean `$finish` (no trap)

## Key Design Decisions

**Layered testbench**: generator / driver / monitors / scoreboard connected via SystemVerilog mailboxes, for modularity and reuse.

**Constrained-random + directed**: random phase surfaces unexpected corner cases; directed phase guarantees every instruction category is hit at least once.

**Instruction-type coverage**: the metric tracked is RV32I instruction *category* coverage (16 categories), not line/toggle code coverage.

## Changelog

### v2.0: Full correctness checking, 100% coverage, clean finish
- Added a full golden reference model (registers + memory + PC) to the scoreboard, upgrading it from a coverage counter to a self-checking scoreboard.
- Fixed `REGS_INIT_ZERO` mismatch: PicoRV32 wasn't zero-initializing its register file to match the golden model's assumption, causing loads/stores through never-written registers to compute garbage addresses.
- Connected the previously-unmonitored `trap` signal so illegal-instruction/misalignment traps are visible in the log instead of the CPU silently going quiet.
- Fixed a sign-extension bug in `predict_result`: `imm[11:0]` was being combined directly with an unsigned register value, silently losing signedness under SystemVerilog's arithmetic conversion rules, ADDI with negative immediates mispredicted.
- Fixed the JAL directed test: an immediate of `64` jumped past the driver's appended halt loop into unprogrammed (zero) memory, tripping an illegal-instruction trap right at the end of the run. Changed to `imm=4` so JAL lands directly on the halt loop.
- Result: instruction coverage went from 93.3% (14/15, JAL excluded) to **100% (16/16)**, and correctness checking went from untracked to **49/49 PASS**.

### v1.0: Initial coverage-driven environment
- Layered TB with constrained-random + directed generation.
- JAL encoding was broken and excluded from the coverage metric: 93.3% (14/15).

## References

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [PicoRV32 GitHub](https://github.com/YosysHQ/picorv32)
- [SystemVerilog for Verification](https://www.amazon.com/SystemVerilog-Verification-Learning-Testbench-Language/dp/1461407141)

## License

MIT License — see `LICENSE` file for details.

PicoRV32 core © 2015 Claire Xenia Wolf (ISC License)
