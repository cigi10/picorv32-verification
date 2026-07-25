`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 01/24/2026 10:19:40 AM
// Design Name:
// Module Name: interface
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
interface intf(input bit clk);
  logic resetn = 0;  // initialize here 

  // PicoRV32 signals
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [31:0] mem_rdata;
  logic [3:0] mem_wstrb;
  logic mem_valid;
  logic mem_ready;

  // internal CPU signals we're monitoring
  logic cpuregs_write;
  logic [4:0] latched_rd;
  logic [31:0] cpuregs_wrdata;

  // CPU trap (illegal instruction / misaligned access with CATCH_MISALIGN=1)
  logic trap;

  // memory array (4KB = 1024 words)
  logic [31:0] memory [0:1023];

  // clocking block for synchronization
  clocking cb @(posedge clk);
    default input #1 output #1;
    output resetn;
    input mem_valid, mem_addr, mem_wdata, mem_wstrb;
    output mem_rdata, mem_ready;
    input cpuregs_write, latched_rd, cpuregs_wrdata;
  endclocking

  // modport for testbench
  modport TB (clocking cb, output resetn, input clk);

endinterface
