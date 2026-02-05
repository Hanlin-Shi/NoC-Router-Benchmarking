//==================================================================
// tb_ravenoc_uvm.sv - Top-level harness using unified benchmark core
//==================================================================
// Override RaveNoC mesh size for testbench (must be before any includes/imports)
`ifndef NOC_CFG_SZ_ROWS
  `define NOC_CFG_SZ_ROWS 3
`endif
`ifndef NOC_CFG_SZ_COLS
  `define NOC_CFG_SZ_COLS 3
`endif

`timescale 1ns/1ps

import uvm_pkg::*;
import noc_bench_core_pkg::*;
import ravenoc_adapter_pkg::*;
import ravenoc_uvm_pkg::*;

`include "uvm_macros.svh"

module tb_ravenoc_uvm;
  parameter string TEST_NAME = "ravenoc_all_in_one_test";

  logic clk, rst;
  initial begin clk = 0; forever #5 clk = ~clk; end
  initial begin rst = 1; repeat(10) @(posedge clk); rst = 0; end

  ravenoc_vif vif(.clk(clk), .rst(rst));

  // Router_if instances (matches original harness)
  router_if north_send_if();
  router_if north_recv_if();
  router_if south_send_if();
  router_if south_recv_if();
  router_if west_send_if();
  router_if west_recv_if();
  router_if east_send_if();
  router_if east_recv_if();
  router_if local_send_if();
  router_if local_recv_if();

  // Connect TB inputs to DUT recv interfaces
  assign north_recv_if.req.fdata = vif.din_north;
  assign north_recv_if.req.vc_id = vif.din_vc_id_north;
  assign north_recv_if.req.valid = vif.din_valid_north;
  assign vif.din_ready_north     = north_recv_if.resp.ready;

  assign south_recv_if.req.fdata = vif.din_south;
  assign south_recv_if.req.vc_id = vif.din_vc_id_south;
  assign south_recv_if.req.valid = vif.din_valid_south;
  assign vif.din_ready_south     = south_recv_if.resp.ready;

  assign west_recv_if.req.fdata = vif.din_west;
  assign west_recv_if.req.vc_id = vif.din_vc_id_west;
  assign west_recv_if.req.valid = vif.din_valid_west;
  assign vif.din_ready_west     = west_recv_if.resp.ready;

  assign east_recv_if.req.fdata = vif.din_east;
  assign east_recv_if.req.vc_id = vif.din_vc_id_east;
  assign east_recv_if.req.valid = vif.din_valid_east;
  assign vif.din_ready_east     = east_recv_if.resp.ready;

  assign local_recv_if.req.fdata = vif.din_local;
  assign local_recv_if.req.vc_id = vif.din_vc_id_local;
  assign local_recv_if.req.valid = vif.din_valid_local;
  assign vif.din_ready_local     = local_recv_if.resp.ready;

  // DUT outputs map to send interfaces
  assign vif.dout_north     = north_send_if.req.fdata;
  assign vif.dout_vc_id_north = north_send_if.req.vc_id;
  assign vif.dout_valid_north = north_send_if.req.valid;
  assign north_send_if.resp.ready = vif.dout_ready_north;

  assign vif.dout_south     = south_send_if.req.fdata;
  assign vif.dout_vc_id_south = south_send_if.req.vc_id;
  assign vif.dout_valid_south = south_send_if.req.valid;
  assign south_send_if.resp.ready = vif.dout_ready_south;

  assign vif.dout_west      = west_send_if.req.fdata;
  assign vif.dout_vc_id_west = west_send_if.req.vc_id;
  assign vif.dout_valid_west = west_send_if.req.valid;
  assign west_send_if.resp.ready = vif.dout_ready_west;

  assign vif.dout_east      = east_send_if.req.fdata;
  assign vif.dout_vc_id_east = east_send_if.req.vc_id;
  assign vif.dout_valid_east = east_send_if.req.valid;
  assign east_send_if.resp.ready = vif.dout_ready_east;

  assign vif.dout_local     = local_send_if.req.fdata;
  assign vif.dout_vc_id_local = local_send_if.req.vc_id;
  assign vif.dout_valid_local = local_send_if.req.valid;
  assign local_send_if.resp.ready = vif.dout_ready_local;

  router_ravenoc #(
    .ROUTER_X_ID(1),
    .ROUTER_Y_ID(1)
  ) dut (
    .clk(clk),
    .arst(rst),
    .north_send(north_send_if.send_flit),
    .south_send(south_send_if.send_flit),
    .west_send (west_send_if.send_flit),
    .east_send (east_send_if.send_flit),
    .local_send(local_send_if.send_flit),
    .north_recv(north_recv_if.recv_flit),
    .south_recv(south_recv_if.recv_flit),
    .west_recv (west_recv_if.recv_flit),
    .east_recv (east_recv_if.recv_flit),
    .local_recv(local_recv_if.recv_flit),
    .full_wr_fifo_o(vif.full_wr_fifo_o)
  );

  initial begin
    $display("NOC_CFG_SZ_ROWS: %d", `NOC_CFG_SZ_ROWS);
    $display("NOC_CFG_SZ_COLS: %d", `NOC_CFG_SZ_COLS);
    uvm_config_db#(virtual ravenoc_vif)::set(null, "*", "vif", vif);
  end

  initial begin
    vif.init();
  end

  initial begin
    string test_name;
    if ($value$plusargs("UVM_TESTNAME=%s", test_name)) begin
      `uvm_info("TB", $sformatf("Running test: %s", test_name), UVM_MEDIUM)
      run_test(test_name);
    end else begin
      `uvm_info("TB", $sformatf("Running default test: %s", TEST_NAME), UVM_MEDIUM)
      run_test(TEST_NAME);
    end
  end

  initial begin
    $dumpfile("tb_ravenoc_uvm.vcd");
    $dumpvars(0, tb_ravenoc_uvm);
  end

  initial begin
    #500s;
    `uvm_fatal("TIMEOUT","Test timeout reached")
  end

endmodule

