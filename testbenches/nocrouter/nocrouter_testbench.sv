`timescale 1ns/1ps

import uvm_pkg::*;
import noc_bench_core_pkg::*;
import nocrouter_adapter_pkg::*;
import router_uvm_pkg::*;

`include "uvm_macros.svh"

module tb_router_uvm;
  parameter string TEST_MODE = "router_all_in_one_test";

  logic clk;
  logic rst;
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;
  end

  router_tb_if tb_if (.clk(clk), .rst(rst));

  router #(
    .BUFFER_SIZE(8),
    .X_CURRENT(MESH_SIZE_X/2),
    .Y_CURRENT(MESH_SIZE_Y/2)
  ) dut (
    .clk(clk),
    .rst(rst),
    .router_if_local_up (tb_if.egress_if[LOCAL].upstream),
    .router_if_north_up (tb_if.egress_if[NORTH].upstream),
    .router_if_south_up (tb_if.egress_if[SOUTH].upstream),
    .router_if_west_up  (tb_if.egress_if[WEST].upstream),
    .router_if_east_up  (tb_if.egress_if[EAST].upstream),
    .router_if_local_down(tb_if.ingress_if[LOCAL].downstream),
    .router_if_north_down(tb_if.ingress_if[NORTH].downstream),
    .router_if_south_down(tb_if.ingress_if[SOUTH].downstream),
    .router_if_west_down (tb_if.ingress_if[WEST].downstream),
    .router_if_east_down (tb_if.ingress_if[EAST].downstream),
    .error_o()
  );

  initial begin
    uvm_config_db#(virtual router_tb_if)::set(null, "*", "vif", tb_if);
  end

  initial begin
    tb_if.init_links();
    wait (rst == 1'b0);
    tb_if.init_links();
  end

  initial begin
    string testname;
    if ($value$plusargs("UVM_TESTNAME=%s", testname)) begin
      `uvm_info("TB", $sformatf("Running test: %s", testname), UVM_MEDIUM)
      run_test(testname);
    end else begin
      `uvm_info("TB", $sformatf("Running default test: %s", TEST_MODE), UVM_MEDIUM)
      run_test(TEST_MODE);
    end
  end

  initial begin
    $dumpfile("tb_router_uvm.vcd");
    $dumpvars(0, tb_router_uvm);
  end

  initial begin
    #100ms;
    `uvm_fatal("TIMEOUT", "Simulation timeout")
  end

endmodule


