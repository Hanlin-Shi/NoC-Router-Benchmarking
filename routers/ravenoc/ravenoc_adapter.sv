//==================================================================
// ravenoc_uvm_pkg.sv - RANC style UVM test platform package
//==================================================================
package ravenoc_uvm_pkg;
  import uvm_pkg::*;
  import ravenoc_pkg::*;
  `include "uvm_macros.svh"

  parameter int PACKET_WIDTH = 30;
  parameter int DX_MSB = 29;
  parameter int DX_LSB = 21;
  parameter int DY_MSB = 20;
  parameter int DY_LSB = 12;
  parameter int PAYLOAD_WIDTH = DY_LSB;
  parameter int DX_WIDTH = DX_MSB - DX_LSB + 1;
  parameter int DY_WIDTH = DY_MSB - DY_LSB + 1;

  typedef enum int {
    PORT_NONE  = 0,
    PORT_LOCAL = 1,
    PORT_EAST  = 2,
    PORT_WEST  = 3,
    PORT_NORTH = 4,
    PORT_SOUTH = 5
  } port_type_e;

  typedef enum int {
    PATTERN_UNIFORM   = 0,
    PATTERN_HOTSPOT   = 1,
    PATTERN_TRANSPOSE = 2
  } traffic_pattern_e;

  typedef enum int {
    LOAD_LIGHT     = 0,
    LOAD_MEDIUM    = 1,
    LOAD_HEAVY     = 2,
    LOAD_SATURATED = 3
  } load_level_e;

  typedef enum int {
    HOTSPOT_1PORT  = 0,
    HOTSPOT_2PORTS = 1,
    HOTSPOT_3PORTS = 2,
    HOTSPOT_4PORTS = 3
  } hotspot_pattern_e;

  class ravenoc_config extends uvm_object;
    traffic_pattern_e traffic_pattern;
    load_level_e      load_level;
    hotspot_pattern_e hotspot_pattern;
    int num_packets_per_stream = 100;
    int max_cycles = 2000;
    int router_x_id = 1;
    int router_y_id = 1;

    `uvm_object_utils_begin(ravenoc_config)
      `uvm_field_enum(traffic_pattern_e, traffic_pattern, UVM_ALL_ON)
      `uvm_field_enum(load_level_e,      load_level,      UVM_ALL_ON)
      `uvm_field_enum(hotspot_pattern_e, hotspot_pattern, UVM_ALL_ON)
      `uvm_field_int (num_packets_per_stream,             UVM_ALL_ON)
      `uvm_field_int (max_cycles,                         UVM_ALL_ON)
      `uvm_field_int (router_x_id,                        UVM_ALL_ON)
      `uvm_field_int (router_y_id,                        UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ravenoc_config");
      super.new(name);
    endfunction
  endclass

  function automatic int load2gap(load_level_e l);
    case (l)
      LOAD_LIGHT:     return 8;
      LOAD_MEDIUM:    return 4;
      LOAD_HEAVY:     return 2;
      LOAD_SATURATED: return 1;
      default:        return 8;
    endcase
  endfunction

  function automatic void port2xy(
      input  port_type_e    dst,
      input  int unsigned   router_x_id,
      input  int unsigned   router_y_id,
      output int unsigned   x,
      output int unsigned   y);
    // Get mesh bounds from RaveNoC package (calculated from defines)
    localparam int MAX_X = (1 << ravenoc_pkg::XWidth) - 1;
    localparam int MAX_Y = (1 << ravenoc_pkg::YWidth) - 1;
    
    x = router_x_id;
    y = router_y_id;
    unique case (dst)
      PORT_NORTH: begin
        x = (router_x_id > 0) ? router_x_id - 1 : 0;
        y = router_y_id;
      end
      PORT_SOUTH: begin
        x = (router_x_id < MAX_X) ? router_x_id + 1 : MAX_X;
        y = router_y_id;
      end
      PORT_WEST: begin
        x = router_x_id;
        y = (router_y_id > 0) ? router_y_id - 1 : 0;
      end
      PORT_EAST: begin
        x = router_x_id;
        y = (router_y_id < MAX_Y) ? router_y_id + 1 : MAX_Y;
      end
      default: begin
        x = router_x_id;
        y = router_y_id;
      end
    endcase
  endfunction

  function automatic void xy2next_port(
      input int unsigned router_x,
      input int unsigned router_y,
      input int unsigned x_dest,
      input int unsigned y_dest,
      output port_type_e next_port);
    if (x_dest == router_x && y_dest == router_y)
      next_port = PORT_LOCAL;
    else if (x_dest == router_x) begin
      if (y_dest < router_y)
        next_port = PORT_WEST;
      else
        next_port = PORT_EAST;
    end else begin
      if (x_dest > router_x)
        next_port = PORT_SOUTH;
      else
        next_port = PORT_NORTH;
    end
  endfunction

  function automatic logic [ravenoc_pkg::FlitWidth-1:0]
    pack_head_flit(input int unsigned x,
                   input int unsigned y,
                   input logic [ravenoc_pkg::MinDataWidth-1:0] payload);
    ravenoc_pkg::s_flit_head_data_t head_flit;
    logic [ravenoc_pkg::FlitWidth-1:0] full_flit;
    head_flit.type_f   = ravenoc_pkg::HEAD_FLIT;
    head_flit.x_dest   = x[ravenoc_pkg::XWidth-1:0];
    head_flit.y_dest   = y[ravenoc_pkg::YWidth-1:0];
    head_flit.pkt_size = '0;
    head_flit.data     = payload;
    full_flit = head_flit;
    return full_flit;
  endfunction

endpackage

//==================================================================
// RaveNoC virtual interface (RANC style signals)
//==================================================================
interface ravenoc_vif(input logic clk, input logic rst);
  logic [ravenoc_pkg::FlitWidth-1:0] din_north, din_south, din_west, din_east, din_local;
  logic [ravenoc_pkg::VcWidth-1:0]   din_vc_id_north, din_vc_id_south, din_vc_id_west, din_vc_id_east, din_vc_id_local;
  logic din_valid_north, din_valid_south, din_valid_west, din_valid_east, din_valid_local;
  logic din_ready_north, din_ready_south, din_ready_west, din_ready_east, din_ready_local;

  logic [ravenoc_pkg::FlitWidth-1:0] dout_north, dout_south, dout_west, dout_east, dout_local;
  logic [ravenoc_pkg::VcWidth-1:0]   dout_vc_id_north, dout_vc_id_south, dout_vc_id_west, dout_vc_id_east, dout_vc_id_local;
  logic dout_valid_north, dout_valid_south, dout_valid_west, dout_valid_east, dout_valid_local;
  logic dout_ready_north, dout_ready_south, dout_ready_west, dout_ready_east, dout_ready_local;
  logic full_wr_fifo_o;

  assign dout_ready_north = 1'b1;
  assign dout_ready_south = 1'b1;
  assign dout_ready_west  = 1'b1;
  assign dout_ready_east  = 1'b1;
  assign dout_ready_local = 1'b1;

  task automatic init();
    din_north = '0; din_south = '0; din_west = '0; din_east = '0; din_local = '0;
    din_vc_id_north = '0; din_vc_id_south = '0; din_vc_id_west = '0; din_vc_id_east = '0; din_vc_id_local = '0;
    din_valid_north = 1'b0; din_valid_south = 1'b0; din_valid_west = 1'b0;
    din_valid_east  = 1'b0; din_valid_local = 1'b0;
  endtask
endinterface


//==================================================================
// ravenoc_adapter_pkg.sv
// Router-specific adapter binding the benchmark core to RaveNoC
//==================================================================
package ravenoc_adapter_pkg;

  import uvm_pkg::*;
  import noc_bench_core_pkg::*;
  import ravenoc_uvm_pkg::ravenoc_config;
  import ravenoc_uvm_pkg::pack_head_flit;
  import ravenoc_pkg::*;

  `include "uvm_macros.svh"

  // Adapter helper functions mapping noc_bench_core_pkg types to ravenoc_uvm_pkg types
  function automatic ravenoc_uvm_pkg::port_type_e core2ravenoc_port(noc_bench_core_pkg::port_type_e p);
    case (p)
      noc_bench_core_pkg::PORT_LOCAL: return ravenoc_uvm_pkg::PORT_LOCAL;
      noc_bench_core_pkg::PORT_EAST:  return ravenoc_uvm_pkg::PORT_EAST;
      noc_bench_core_pkg::PORT_WEST:  return ravenoc_uvm_pkg::PORT_WEST;
      noc_bench_core_pkg::PORT_NORTH: return ravenoc_uvm_pkg::PORT_NORTH;
      noc_bench_core_pkg::PORT_SOUTH: return ravenoc_uvm_pkg::PORT_SOUTH;
      default:                        return ravenoc_uvm_pkg::PORT_NONE;
    endcase
  endfunction

  function automatic noc_bench_core_pkg::port_type_e ravenoc2core_port(ravenoc_uvm_pkg::port_type_e p);
    case (p)
      ravenoc_uvm_pkg::PORT_LOCAL: return noc_bench_core_pkg::PORT_LOCAL;
      ravenoc_uvm_pkg::PORT_EAST:  return noc_bench_core_pkg::PORT_EAST;
      ravenoc_uvm_pkg::PORT_WEST:  return noc_bench_core_pkg::PORT_WEST;
      ravenoc_uvm_pkg::PORT_NORTH: return noc_bench_core_pkg::PORT_NORTH;
      ravenoc_uvm_pkg::PORT_SOUTH: return noc_bench_core_pkg::PORT_SOUTH;
      default:                     return noc_bench_core_pkg::PORT_LOCAL;
    endcase
  endfunction

  function automatic ravenoc_uvm_pkg::load_level_e core2ravenoc_load(noc_bench_core_pkg::load_level_e l);
    case (l)
      noc_bench_core_pkg::LOAD_LIGHT:     return ravenoc_uvm_pkg::LOAD_LIGHT;
      noc_bench_core_pkg::LOAD_MEDIUM:    return ravenoc_uvm_pkg::LOAD_MEDIUM;
      noc_bench_core_pkg::LOAD_HEAVY:     return ravenoc_uvm_pkg::LOAD_HEAVY;
      noc_bench_core_pkg::LOAD_SATURATED: return ravenoc_uvm_pkg::LOAD_SATURATED;
      default:                            return ravenoc_uvm_pkg::LOAD_LIGHT;
    endcase
  endfunction

  function automatic int load2gap(noc_bench_core_pkg::load_level_e l);
    return ravenoc_uvm_pkg::load2gap(core2ravenoc_load(l));
  endfunction

  function automatic void port2xy(
      input  noc_bench_core_pkg::port_type_e dst,
      input  int unsigned                    router_x_id,
      input  int unsigned                    router_y_id,
      output int unsigned                    x,
      output int unsigned                    y);
    ravenoc_uvm_pkg::port_type_e ravenoc_port;
    ravenoc_port = core2ravenoc_port(dst);
    ravenoc_uvm_pkg::port2xy(ravenoc_port, router_x_id, router_y_id, x, y);
  endfunction

  function automatic void xy2next_port(
      input  int unsigned                    router_x,
      input  int unsigned                    router_y,
      input  int unsigned                    x_dest,
      input  int unsigned                    y_dest,
      output noc_bench_core_pkg::port_type_e next_port);
    ravenoc_uvm_pkg::port_type_e ravenoc_port;
    ravenoc_uvm_pkg::xy2next_port(router_x, router_y, x_dest, y_dest, ravenoc_port);
    next_port = ravenoc2core_port(ravenoc_port);
  endfunction

  class ravenoc_bench_base extends noc_bench_base_test;
    `uvm_component_utils(ravenoc_bench_base)

    virtual ravenoc_vif vif;
    ravenoc_config       local_cfg;

    // Timestamp table for latency (cycle-based)
    longint unsigned t_send_by_key [logic [ravenoc_pkg::FlitWidth-1:0]];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ravenoc_vif)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF","Virtual ravenoc_vif not found")
      local_cfg = ravenoc_config::type_id::create("local_cfg");
      local_cfg.router_x_id = 1;
      local_cfg.router_y_id = 1;
    endfunction

    virtual function string get_default_csv_path();
      return "ravenoc_results.csv";
    endfunction

    virtual function void adapter_exp_begin_hook(string tag);
      t_send_by_key.delete();
    endfunction

    task automatic wait_for_reset_release();
      wait(!vif.rst);
    endtask

    task automatic wait_cycles(int cycles);
      repeat (cycles) @(posedge vif.clk);
    endtask

    task automatic drain_all(int quiet_cycles = 4, int max_wait_cycles = 1_000_000);
      int waited = 0;
      repeat (max_wait_cycles) begin
        @(posedge vif.clk);
        waited++;
        if (waited >= quiet_cycles)
          break;
      end
    endtask

    task automatic settle_links();
      wait_cycles(4);
    endtask

    // Override path validation to exclude loopbacks
    virtual function bit is_valid_transfer_path(noc_bench_core_pkg::port_type_e src, 
                                                 noc_bench_core_pkg::port_type_e dst);
      if (src == dst)
        return 0;
      return 1;
    endfunction

    function void record_send(noc_bench_core_pkg::port_type_e dst_port,
                              logic [ravenoc_pkg::FlitWidth-1:0] flit);
      note_send(dst_port);
      t_send_by_key[flit] = cycle_count;
    endfunction

    function void record_recv(noc_bench_core_pkg::port_type_e dst_port,
                              logic [ravenoc_pkg::FlitWidth-1:0] flit);
      longint unsigned latency = 0;
      if (t_send_by_key.exists(flit)) begin
        latency = cycle_count - t_send_by_key[flit];
        t_send_by_key.delete(flit);
      end
      note_recv(dst_port, latency);
    endfunction

    virtual task start_output_monitors();
      fork
        forever @(posedge vif.clk) begin
          cycle_count++;
          if (exp_active && vif.dout_valid_north && vif.dout_ready_north)
            handle_monitor(noc_bench_core_pkg::PORT_NORTH, vif.dout_north);
          if (exp_active && vif.dout_valid_south && vif.dout_ready_south)
            handle_monitor(noc_bench_core_pkg::PORT_SOUTH, vif.dout_south);
          if (exp_active && vif.dout_valid_west && vif.dout_ready_west)
            handle_monitor(noc_bench_core_pkg::PORT_WEST, vif.dout_west);
          if (exp_active && vif.dout_valid_east && vif.dout_ready_east)
            handle_monitor(noc_bench_core_pkg::PORT_EAST, vif.dout_east);
          if (exp_active && vif.dout_valid_local && vif.dout_ready_local)
            handle_monitor(noc_bench_core_pkg::PORT_LOCAL, vif.dout_local);
        end
      join_none
    endtask

    task automatic handle_monitor(noc_bench_core_pkg::port_type_e actual_port,
                                  logic [ravenoc_pkg::FlitWidth-1:0] flit);
      ravenoc_pkg::s_flit_head_data_t head;
      noc_bench_core_pkg::port_type_e expect_port;
      head = ravenoc_pkg::s_flit_head_data_t'(flit);
      xy2next_port(local_cfg.router_x_id,
                                    local_cfg.router_y_id,
                                    head.x_dest,
                                    head.y_dest,
                                    expect_port);
      if (expect_port != actual_port) begin
        `uvm_warning("PORT_CHECK",
          $sformatf("Expected %s but observed %s",
                    port2str(expect_port), port2str(actual_port)))
      end
      record_recv(actual_port, flit);
    endtask

    task automatic do_tx_one_flit(noc_bench_core_pkg::port_type_e in_port,
                                  noc_bench_core_pkg::port_type_e dst_port,
                                  logic [ravenoc_pkg::FlitWidth-1:0] flit);
      logic ready;
      wait_for_reset_release();
      do begin
        @(posedge vif.clk);
        case (in_port)
          noc_bench_core_pkg::PORT_LOCAL:  ready = vif.din_ready_local;
          noc_bench_core_pkg::PORT_NORTH:  ready = vif.din_ready_north;
          noc_bench_core_pkg::PORT_SOUTH:  ready = vif.din_ready_south;
          noc_bench_core_pkg::PORT_WEST:   ready = vif.din_ready_west;
          noc_bench_core_pkg::PORT_EAST:   ready = vif.din_ready_east;
          default:                         ready = 1'b0;
        endcase
        if (!ready) note_stall(in_port, 1);
      end while (!ready);

      case (in_port)
        noc_bench_core_pkg::PORT_LOCAL: begin
          vif.din_local       <= flit;
          vif.din_vc_id_local <= '0;
          vif.din_valid_local <= 1'b1;
        end
        noc_bench_core_pkg::PORT_NORTH: begin
          vif.din_north       <= flit;
          vif.din_vc_id_north <= '0;
          vif.din_valid_north <= 1'b1;
        end
        noc_bench_core_pkg::PORT_SOUTH: begin
          vif.din_south       <= flit;
          vif.din_vc_id_south <= '0;
          vif.din_valid_south <= 1'b1;
        end
        noc_bench_core_pkg::PORT_WEST: begin
          vif.din_west       <= flit;
          vif.din_vc_id_west <= '0;
          vif.din_valid_west <= 1'b1;
        end
        noc_bench_core_pkg::PORT_EAST: begin
          vif.din_east       <= flit;
          vif.din_vc_id_east <= '0;
          vif.din_valid_east <= 1'b1;
        end
        default: ;
      endcase

      record_send(dst_port, flit);

      do begin
        @(posedge vif.clk);
        case (in_port)
          noc_bench_core_pkg::PORT_LOCAL:  ready = vif.din_ready_local;
          noc_bench_core_pkg::PORT_NORTH:  ready = vif.din_ready_north;
          noc_bench_core_pkg::PORT_SOUTH:  ready = vif.din_ready_south;
          noc_bench_core_pkg::PORT_WEST:   ready = vif.din_ready_west;
          noc_bench_core_pkg::PORT_EAST:   ready = vif.din_ready_east;
          default:                         ready = 1'b0;
        endcase
        if (!ready) note_stall(in_port, 1);
      end while (!ready);

      case (in_port)
        noc_bench_core_pkg::PORT_LOCAL:  vif.din_valid_local <= 1'b0;
        noc_bench_core_pkg::PORT_NORTH:  vif.din_valid_north <= 1'b0;
        noc_bench_core_pkg::PORT_SOUTH:  vif.din_valid_south <= 1'b0;
        noc_bench_core_pkg::PORT_WEST:   vif.din_valid_west  <= 1'b0;
        noc_bench_core_pkg::PORT_EAST:   vif.din_valid_east  <= 1'b0;
        default: ;
      endcase
    endtask

    virtual task drive_stream_on_port(noc_bench_core_pkg::port_type_e in_port,
                                      noc_bench_core_pkg::port_type_e dst_port,
                                      int                              n_pkts,
                                      noc_bench_core_pkg::load_level_e load,
                                      int                              payload_seed = 0);
      // Declare all variables first (SystemVerilog 2012 requirement)
      int gap;
      int unsigned dx, dy;
      int i;
      
      // Initialize variables
      gap = load2gap(load);
      port2xy(dst_port,
                               local_cfg.router_x_id,
                               local_cfg.router_y_id,
                               dx, dy);
      account_scheduled_packets(n_pkts);
      driver_enter();
      for (i = 0; i < n_pkts; i++) begin
        logic [ravenoc_pkg::FlitWidth-1:0] flit;
        logic [ravenoc_pkg::MinDataWidth-1:0] payload;
        if (should_stop_drivers())
          break;
        payload = (payload_seed + i) & ((1 << ravenoc_pkg::MinDataWidth) - 1);
        flit = pack_head_flit(int'(dx), int'(dy), payload);
        do_tx_one_flit(in_port, dst_port, flit);
        repeat (gap) begin
          @(posedge vif.clk);
          if (should_stop_drivers())
            break;
        end
        if (should_stop_drivers())
          break;
      end
      driver_exit();
    endtask

  endclass

  class ravenoc_functional_test extends noc_functional_test_base#(ravenoc_bench_base);
    `uvm_component_utils(ravenoc_functional_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    
    // Override: RaveNoC uses actual completion time (not windowed like old RANC)
    virtual task run_phase(uvm_phase phase);
      string tag;
      phase.raise_objection(this);
      this.start_output_monitors();
      tag = "functional_basic";
      this.exp_begin(tag);
      this.cfg.traffic_pattern        = PATTERN_UNIFORM;
      this.cfg.load_level             = LOAD_LIGHT;
      this.cfg.num_packets_per_stream = 100;
      this.run_pattern_job(this.cfg.traffic_pattern,
                           this.cfg.load_level,
                           this.cfg.num_packets_per_stream);
      this.exp_end(tag);
      phase.drop_objection(this);
    endtask
  endclass

  class ravenoc_system_benchmark_test extends noc_system_benchmark_test_base#(ravenoc_bench_base);
    `uvm_component_utils(ravenoc_system_benchmark_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ravenoc_hotspot_analysis_test extends noc_hotspot_analysis_test_base#(ravenoc_bench_base);
    `uvm_component_utils(ravenoc_hotspot_analysis_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ravenoc_transfer_rate_test extends noc_transfer_rate_test_base#(ravenoc_bench_base);
    `uvm_component_utils(ravenoc_transfer_rate_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    
    // Override: RaveNoC uses actual completion time (not windowed like old RANC)
    virtual task run_phase(uvm_phase phase);
      int idx;
      string tag;
      phase.raise_objection(this);
      this.start_output_monitors();
      for (idx = 0; idx < NUM_TRANSFER_PATHS; idx++) begin
        if (!is_valid_transfer_path(TRANSFER_PATHS[idx].src, TRANSFER_PATHS[idx].dst))
          continue;
        tag = $sformatf("transfer_rate_%s_to_%s",
                        port2enum_str(TRANSFER_PATHS[idx].src),
                        port2enum_str(TRANSFER_PATHS[idx].dst));
        this.exp_begin(tag);
        this.cfg.load_level = LOAD_SATURATED;
        this.run_stream_job(TRANSFER_PATHS[idx].src,
                            TRANSFER_PATHS[idx].dst,
                            100,
                            this.cfg.load_level,
                            32'hA0_000 + idx);
        this.exp_end(tag);
      end
      phase.drop_objection(this);
    endtask
  endclass

  class ravenoc_all_in_one_test extends noc_all_in_one_test_base#(ravenoc_bench_base);
    `uvm_component_utils(ravenoc_all_in_one_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    
    // Override: RaveNoC uses actual completion time for ALL tests (not windowed)
    virtual task run_phase(uvm_phase phase);
      int pattern, load, hotspot, idx;
      string tag;
      phase.raise_objection(this);
      this.start_output_monitors();

      // Functional basic (actual time mode, NOT window mode like RANC)
      tag = "functional_basic";
      this.exp_begin(tag);
      this.cfg.traffic_pattern        = PATTERN_UNIFORM;
      this.cfg.load_level             = LOAD_LIGHT;
      this.cfg.num_packets_per_stream = 100;
      this.run_pattern_job(this.cfg.traffic_pattern,
                           this.cfg.load_level,
                           this.cfg.num_packets_per_stream);
      this.exp_end(tag);

      // Transfer rate (actual time mode, NOT window mode like RANC)
      run_transfer_rate_if_valid(PORT_LOCAL, PORT_NORTH, 0);
      run_transfer_rate_if_valid(PORT_NORTH, PORT_LOCAL, 1);
      run_transfer_rate_if_valid(PORT_SOUTH, PORT_LOCAL, 2);
      run_transfer_rate_if_valid(PORT_WEST,  PORT_LOCAL, 3);
      run_transfer_rate_if_valid(PORT_EAST,  PORT_LOCAL, 4);
      run_transfer_rate_if_valid(PORT_LOCAL, PORT_SOUTH, 5);
      run_transfer_rate_if_valid(PORT_NORTH, PORT_SOUTH, 6);
      run_transfer_rate_if_valid(PORT_SOUTH, PORT_NORTH, 7);
      run_transfer_rate_if_valid(PORT_WEST,  PORT_NORTH, 8);
      run_transfer_rate_if_valid(PORT_EAST,  PORT_NORTH, 9);
      run_transfer_rate_if_valid(PORT_LOCAL, PORT_WEST,  10);
      run_transfer_rate_if_valid(PORT_NORTH, PORT_WEST,  11);
      run_transfer_rate_if_valid(PORT_SOUTH, PORT_WEST,  12);
      run_transfer_rate_if_valid(PORT_WEST,  PORT_SOUTH, 13);
      run_transfer_rate_if_valid(PORT_EAST,  PORT_SOUTH, 14);
      run_transfer_rate_if_valid(PORT_LOCAL, PORT_EAST,  15);
      run_transfer_rate_if_valid(PORT_NORTH, PORT_EAST,  16);
      run_transfer_rate_if_valid(PORT_SOUTH, PORT_EAST,  17);
      run_transfer_rate_if_valid(PORT_WEST,  PORT_EAST,  18);
      run_transfer_rate_if_valid(PORT_EAST,  PORT_WEST,  19);

      // System benchmark (3x4, actual time mode)
      for (pattern = 0; pattern < 3; pattern++) begin
        for (load = 0; load < 4; load++) begin
          tag = $sformatf("benchmark_%s_%s",
                          pattern2str(traffic_pattern_e'(pattern)),
                          load2str(load_level_e'(load)));
          this.exp_begin(tag);
          this.cfg.traffic_pattern        = traffic_pattern_e'(pattern);
          this.cfg.load_level             = load_level_e'(load);
          this.cfg.num_packets_per_stream = 500;
          this.run_pattern_job(this.cfg.traffic_pattern,
                               this.cfg.load_level,
                               this.cfg.num_packets_per_stream);
          this.exp_end(tag);
        end
      end

      // Hotspot analysis (4x4, actual time mode)
      for (hotspot = 0; hotspot < 4; hotspot++) begin
        for (load = 0; load < 4; load++) begin
          tag = $sformatf("hotspot_%s_%s",
                          hotspot2str(hotspot_pattern_e'(hotspot)),
                          load2str(load_level_e'(load)));
          this.exp_begin(tag);
          this.cfg.hotspot_pattern        = hotspot_pattern_e'(hotspot);
          this.cfg.load_level             = load_level_e'(load);
          this.cfg.num_packets_per_stream = 100;
          this.run_hotspot_job(this.cfg.hotspot_pattern,
                               this.cfg.load_level,
                               this.cfg.num_packets_per_stream);
          this.exp_end(tag);
        end
      end

      phase.drop_objection(this);
    endtask
  endclass

  class ravenoc_simple_test extends noc_simple_test_base#(ravenoc_bench_base);
    `uvm_component_utils(ravenoc_simple_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

endpackage


