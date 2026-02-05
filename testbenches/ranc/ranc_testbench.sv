//==================================================================
// tb_ranc_uvm.sv - Router-specific top-level (clock/reset/DUT only)
//==================================================================
`timescale 1ns/1ps

import uvm_pkg::*;
import noc_bench_core_pkg::*;
import ranc_adapter_pkg::*;
import ranc_uvm_pkg::*;

`include "uvm_macros.svh"

module tb_ranc_uvm;
  parameter string TEST_MODE = "ranc_all_in_one_test";

  // Clock / Reset
  logic clk, rst;
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk; // 100 MHz
  end

  initial begin
    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;
  end

  // Virtual interface
  ranc_vif ranc_if (.clk(clk), .rst(rst));

  // DUT instantiation
  Router #(
    .PACKET_WIDTH(30),
    .DX_MSB(29), .DX_LSB(21),
    .DY_MSB(20), .DY_LSB(12)
  ) uut (
    .clk(clk),
    .rst(rst),
    // Ingress
    .din_local     (ranc_if.din_local),
    .din_local_wen (ranc_if.din_local_wen),
    .din_east      (ranc_if.din_east),
    .din_west      (ranc_if.din_west),
    .din_north     (ranc_if.din_north),
    .din_south     (ranc_if.din_south),
    .ren_in_east   (ranc_if.ren_in_east),
    .ren_in_west   (ranc_if.ren_in_west),
    .ren_in_north  (ranc_if.ren_in_north),
    .ren_in_south  (ranc_if.ren_in_south),
    .empty_in_east (ranc_if.empty_in_east),
    .empty_in_west (ranc_if.empty_in_west),
    .empty_in_north(ranc_if.empty_in_north),
    .empty_in_south(ranc_if.empty_in_south),
    // Egress
    .dout_east      (ranc_if.dout_east),
    .dout_west      (ranc_if.dout_west),
    .dout_north     (ranc_if.dout_north),
    .dout_south     (ranc_if.dout_south),
    .dout_local     (ranc_if.dout_local),
    .dout_wen_local (ranc_if.dout_wen_local),
    .ren_out_east   (ranc_if.ren_out_east),
    .ren_out_west   (ranc_if.ren_out_west),
    .ren_out_north  (ranc_if.ren_out_north),
    .ren_out_south  (ranc_if.ren_out_south),
    .empty_out_east (ranc_if.empty_out_east),
    .empty_out_west (ranc_if.empty_out_west),
    .empty_out_north(ranc_if.empty_out_north),
    .empty_out_south(ranc_if.empty_out_south),
    .local_buffers_full(ranc_if.local_buffers_full)
  );

  // Provide virtual interface to UVM
  initial begin
    uvm_config_db#(virtual ranc_vif)::set(null, "*", "vif", ranc_if);
  end

  // Default neighbor behavior
  initial begin
    wait(!rst);
    ranc_if.ren_in_west  = 1'b1;
    ranc_if.ren_in_east  = 1'b1;
    ranc_if.ren_in_north = 1'b1;
    ranc_if.ren_in_south = 1'b1;
    ranc_if.empty_in_west  = 1'b1;
    ranc_if.empty_in_east  = 1'b1;
    ranc_if.empty_in_north = 1'b1;
    ranc_if.empty_in_south = 1'b1;
    ranc_if.init();
  end

  // Launch test (prefer +UVM_TESTNAME)
  initial begin
    string test_name;
    if ($value$plusargs("UVM_TESTNAME=%s", test_name)) begin
      `uvm_info("TB", $sformatf("Running test: %s", test_name), UVM_MEDIUM)
      run_test(test_name);
    end else begin
      `uvm_info("TB", $sformatf("No test specified, running %s", TEST_MODE), UVM_MEDIUM)
      run_test(TEST_MODE);
    end
  end

  // Waveform dump
  initial begin
    $dumpfile("tb_ranc_uvm.vcd");
    $dumpvars(0, tb_ranc_uvm);
  end

  // Timeout guard
  initial begin
    #100ms;
    `uvm_fatal("TIMEOUT","Test timeout reached")
  end

endmodule

