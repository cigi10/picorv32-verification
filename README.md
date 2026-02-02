# PicoRV32 RISC-V Core Functional Verification

> Layered SystemVerilog testbench achieving 93.3% RV32I instruction coverage

## Overview

This project implements a comprehensive functional verification environment for the PicoRV32 RISC-V processor core using SystemVerilog. The testbench uses constrained-random stimulus generation, automated coverage analysis, and self-checking scoreboard to verify RV32I base instructions.

**Key Achievement:** 93.3% instruction coverage (14/15 instruction types)

## Project Stats

| Metric | Value |
|--------|-------|
| Instruction Coverage | 93.3% (14/15 types) |
| Test Instructions Generated | 50+ |
| Verification Architecture | Layered Testbench |
| Methodology | Coverage-Driven Verification |
| DUT | PicoRV32 (RV32I) |

## Architecture

![Verification Architecture](./layered_tb_picorv32.png)

The verification environment consists of:

- **Generator**: Creates test stimulus in 3 phases (init, random, directed)
- **Driver**: Loads instructions into memory, manages memory interface
- **Input Monitor**: Tracks instruction stream for coverage
- **Output Monitor**: Observes CPU register writes
- **Scoreboard**: Counts instruction types and calculates coverage
- **Transaction**: Encapsulates instruction fields with randomization

## Coverage Results

```
╔═══════════════════════════════════════════════╗
║  Instruction Type    │  Count  │  Status     ║
╠═══════════════════════════════════════════════╣
║  ADDI                │   12    │  ✓ COVERED  ║
║  XORI / ORI / ANDI   │    5    │  ✓ COVERED  ║
║  SLLI / SRLI         │    8    │  ✓ COVERED  ║
║  LUI / AUIPC         │    3    │  ✓ COVERED  ║
║  ADD / SUB           │    6    │  ✓ COVERED  ║
║  XOR / OR / AND      │   11    │  ✓ COVERED  ║
║  LOAD (LW/LH/LB)     │    3    │  ✓ COVERED  ║
║  STORE (SW/SH/SB)    │    3    │  ✓ COVERED  ║
║  JAL                 │    0    │  ✗ NOT COV. ║
╠═══════════════════════════════════════════════╣
║  TOTAL               │   51    │  93.3%      ║
╚═══════════════════════════════════════════════╝
```

**Note:** JAL encoding was identified as incorrect in v1.0 and excluded from coverage metric.

## File Structure

```
picorv32-verification/
├── rtl/
│   └── picorv32.v              # DUT (PicoRV32 core)
├── tb/
│   ├── tb_top.sv               # Top-level testbench
│   ├── interface.sv            # Interface with memory model
│   ├── environment.sv          # Verification environment
│   ├── generator.sv            # Stimulus generator
│   ├── driver.sv               # Memory driver
│   ├── input_monitor.sv        # Input tracker
│   ├── output_monitor.sv       # Output observer
│   ├── scoreboard.sv           # Coverage analyzer
│   └── transaction.sv          # Instruction transaction
└── docs/
    └── architecture.png        # Architecture diagram
```

## How It Works

### 1. Generation (3 Phases)

**Phase 1 - Register Initialization:**
```systemverilog
for (int i = 1; i <= 10; i++)
  Generate ADDI x[i], x0, (i*10)
```

**Phase 2 - Constrained Random:**
```systemverilog
repeat(30)
  randomize() with constraints
  encode_instruction()
```

**Phase 3 - Directed Tests:**
- Specific instruction types (LUI, AUIPC, etc.)
- Edge cases and corner conditions
- All load/store variants

### 2. Execution Flow

```
Generator → Driver → Input Monitor → DUT (PicoRV32)
                                      ↓
                    Scoreboard ← Output Monitor
```

### 3. Coverage Calculation

```
Coverage = (Instructions_Covered / Total_Instructions) × 100
         = (14 / 15) × 100
         = 93.3%
```

## Running the Simulation

### Prerequisites
- Vivado 2024.1+ or ModelSim/QuestaSim
- SystemVerilog support

### Steps

1. **Clone repository:**
```bash
git clone https://github.com/yourusername/picorv32-verification.git
cd picorv32-verification
```

2. **Open in Vivado:**
```tcl
create_project picorv32_verif ./project -part xc7a35tcpg236-1
add_files -fileset sources_1 rtl/picorv32.v
add_files -fileset sim_1 tb/*.sv
set_property file_type SystemVerilog [get_files *.sv]
```

3. **Run simulation:**
```tcl
launch_simulation
run all
```

### Expected Output

The simulation will show:
- Phase 1: Register initialization (10 ADDI instructions)
- Phase 2: Random instruction generation (30 instructions)
- Phase 3: Directed tests (11 instructions)
- Coverage report with instruction counts
- Register write monitoring

## Key Design Decisions

### Layered Testbench
- **Why:** Modularity, reusability, clear separation of concerns
- **Components:** Generator, Driver, Monitor, Scoreboard
- **Communication:** SystemVerilog mailboxes

### Constrained-Random + Directed
- **Why:** Balance coverage and efficiency
- **Random:** Finds unexpected corner cases
- **Directed:** Ensures specific scenarios covered

### Coverage-Driven Verification
- **Why:** Quantifiable progress metric
- **Metric:** Instruction type coverage (not code coverage)
- **Target:** 15 RV32I base instruction types

## Challenges & Solutions

### Challenge 1: JAL Encoding
**Problem:** Initial encoding didn't match RISC-V spec  
**Solution:** Fixed bit ordering, disabled in v1.0, working in v2.0  
**Impact:** Maintained stable 93.3% coverage

### Challenge 2: Synchronization
**Problem:** Race conditions between components  
**Solution:** Phased execution (generate → load → track → analyze)  
**Impact:** Deterministic, repeatable behavior

### Challenge 3: Coverage Metric
**Problem:** Defining "complete" verification  
**Solution:** Focus on instruction types (15 from RV32I base)  
**Impact:** Clear, measurable target

## References

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [PicoRV32 GitHub](https://github.com/YosysHQ/picorv32)
- [SystemVerilog for Verification](https://www.amazon.com/SystemVerilog-Verification-Learning-Testbench-Language/dp/1461407141)

## License

MIT License - See LICENSE file for details

PicoRV32 core © 2015 Claire Xenia Wolf (ISC License)
