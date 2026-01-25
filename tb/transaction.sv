`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 01:39:21 AM
// Design Name: 
// Module Name: transaction
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


class transaction;
  // Instruction fields
  rand bit [6:0]  opcode;
  rand bit [4:0]  rd;
  rand bit [4:0]  rs1;
  rand bit [4:0]  rs2;
  rand bit [2:0]  funct3;
  rand bit [6:0]  funct7;
  rand bit [31:0] imm;
  
  // Encoded instruction
  bit [31:0] instruction;
  
  // For scoreboard checking
  bit [31:0] expected_result;
  bit [4:0]  expected_rd;
  
  // Constrain to valid RV32I instructions only
  constraint valid_opcode {
    opcode inside {
      7'b0110011,  // R-type (ADD, SUB, etc.)
      7'b0010011,  // I-type ALU (ADDI, XORI, etc.)
      7'b0000011,  // Load (LW, LH, LB)
      7'b0100011,  // Store (SW, SH, SB)
      7'b0110111,  // LUI
      7'b0010111   // AUIPC
    };
  }
  
  constraint valid_funct {
    if (opcode == 7'b0110011) {  // R-type
      funct3 inside {3'b000, 3'b100, 3'b110, 3'b111};
      funct7 inside {7'b0000000, 7'b0100000};
    }
    if (opcode == 7'b0010011) {  // I-type ALU
      funct3 inside {3'b000, 3'b100, 3'b110, 3'b111, 3'b001, 3'b101};
      if (funct3 == 3'b001 || funct3 == 3'b101)
        funct7 == 7'b0000000;
    }
    if (opcode == 7'b0000011) {  // Load
      funct3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
    }
    if (opcode == 7'b0100011) {  // Store
      funct3 inside {3'b000, 3'b001, 3'b010};
    }
  }
  
  constraint valid_registers {
    rd  inside {[1:31]};  // Don't write to x0
    rs1 inside {[0:31]};
    rs2 inside {[0:31]};
  }
  
  constraint reasonable_immediate {
    if (opcode == 7'b0000011) {     // LOAD instructions (LW, LH, LB, LBU, LHU)
      imm[11:0] inside {[0:511]};   // Address offset 0-511
      imm[31:12] == 20'h0;          // Upper bits must be 0
    } else if (opcode == 7'b0100011) {  // STORE instructions (SW, SH, SB)
      imm[11:0] inside {[0:511]};   // Address offset 0-511
      imm[31:12] == 20'h0;          // Upper bits must be 0
    } else {
      imm[31:12] == 20'h0;          // All other instructions: keep small
    }
  }
  
  // Encode instruction based on type
  function void encode_instruction();
    case(opcode)
      7'b0110011: begin  // R-type
        instruction = {funct7, rs2, rs1, funct3, rd, opcode};
      end
      
      7'b0010011: begin  // I-type ALU
        instruction = {imm[11:0], rs1, funct3, rd, opcode};
      end
      
      7'b0000011: begin  // Load
        instruction = {imm[11:0], rs1, funct3, rd, opcode};
      end
      
      7'b0100011: begin  // Store
        instruction = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
      end
      
      7'b0110111, 7'b0010111: begin  // LUI, AUIPC
        instruction = {imm[31:12], rd, opcode};
      end
      
      default: instruction = 32'h00000013;  // NOP (ADDI x0, x0, 0)
    endcase
  endfunction
  
  // Get human-readable instruction name
  function string get_name();
    case(opcode)
      7'b0110011: begin  // R-type
        case(funct3)
          3'b000: return (funct7 == 7'b0000000) ? "ADD" : "SUB";
          3'b100: return "XOR";
          3'b110: return "OR";
          3'b111: return "AND";
          default: return "R-TYPE";
        endcase
      end
      
      7'b0010011: begin  // I-type ALU
        case(funct3)
          3'b000: return "ADDI";
          3'b100: return "XORI";
          3'b110: return "ORI";
          3'b111: return "ANDI";
          3'b001: return "SLLI";
          3'b101: return "SRLI";
          default: return "I-TYPE";
        endcase
      end
      
      7'b0000011: begin  // Load
        case(funct3)
          3'b000: return "LB";
          3'b001: return "LH";
          3'b010: return "LW";
          3'b100: return "LBU";
          3'b101: return "LHU";
          default: return "LOAD";
        endcase
      end
      
      7'b0100011: begin  // Store
        case(funct3)
          3'b000: return "SB";
          3'b001: return "SH";
          3'b010: return "SW";
          default: return "STORE";
        endcase
      end
      
      7'b0110111: return "LUI";
      7'b0010111: return "AUIPC";
      default: return "UNKNOWN";
    endcase
  endfunction
  
  // Display transaction
  function void display(input string tag = "");
    $display("[%0t] %s: %s | rd=x%0d rs1=x%0d rs2=x%0d imm=0x%0h | instr=0x%08h", 
             $time, tag, get_name(), rd, rs1, rs2, imm, instruction);
  endfunction
  
endclass
