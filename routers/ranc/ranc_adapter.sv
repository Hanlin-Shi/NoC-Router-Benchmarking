//==================================================================
//
// RANC UVM Package - Simplified UVM test platform package
//
//==================================================================
package ranc_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //==================================================================
  // Parameters definition - from original testbench
  //==================================================================
  parameter int PACKET_WIDTH = 30;
  parameter int DX_MSB = 29;
  parameter int DX_LSB = 21;
  parameter int DY_MSB = 20;
  parameter int DY_LSB = 12;
  parameter int PAYLOAD_WIDTH = DY_LSB;
  parameter int DX_WIDTH = DX_MSB - DX_LSB + 1;
  parameter int DY_WIDTH = DY_MSB - DY_LSB + 1;
  parameter int NORTH_SOUTH_WIDTH = PACKET_WIDTH - (DX_MSB - DY_MSB);

  // Port identifiers
  typedef enum int {
    PORT_NONE  = 0,
    PORT_LOCAL = 1,
    PORT_EAST  = 2,
    PORT_WEST  = 3,
    PORT_NORTH = 4,
    PORT_SOUTH = 5
  } port_type_e;

  // Traffic patterns
  typedef enum int {
    PATTERN_UNIFORM   = 0,  // Uniform random distribution
    PATTERN_HOTSPOT   = 1,  // Hotspot pattern
    PATTERN_TRANSPOSE = 2   // Transpose pattern
  } traffic_pattern_e;

  // Load levels
  typedef enum int {
    LOAD_LIGHT     = 0,  // Every 8 cycles injection
    LOAD_MEDIUM    = 1,  // Every 4 cycles injection
    LOAD_HEAVY     = 2,  // Every 2 cycles injection
    LOAD_SATURATED = 3   // Every 1 cycle injection
  } load_level_e;

  // Hotspot sub-patterns
  typedef enum int {
    HOTSPOT_1PORT  = 0,  // 1 port -> LOCAL
    HOTSPOT_2PORTS = 1,  // 2 ports -> LOCAL
    HOTSPOT_3PORTS = 2,  // 3 ports -> LOCAL
    HOTSPOT_4PORTS = 3   // 4 ports -> LOCAL
  } hotspot_pattern_e;

  //==================================================================
  // Packet transaction class
  //==================================================================
  class ranc_packet extends uvm_sequence_item;
    rand bit signed [DX_WIDTH-1:0] dx;
    rand bit signed [DY_WIDTH-1:0] dy;
    rand bit [PAYLOAD_WIDTH-1:0] payload;
    rand port_type_e source_port;
    rand port_type_e dest_port;

    time send_time;
    time recv_time;
    time latency;
    port_type_e exit_port;
    bit dropped;

    `uvm_object_utils_begin(ranc_packet)
      `uvm_field_int(dx, UVM_ALL_ON)
      `uvm_field_int(dy, UVM_ALL_ON)
      `uvm_field_int(payload, UVM_ALL_ON)
      `uvm_field_enum(port_type_e, source_port, UVM_ALL_ON)
      `uvm_field_enum(port_type_e, dest_port, UVM_ALL_ON)
      `uvm_field_int(send_time, UVM_ALL_ON)
      `uvm_field_int(recv_time, UVM_ALL_ON)
      `uvm_field_int(latency, UVM_ALL_ON)
      `uvm_field_enum(port_type_e, exit_port, UVM_ALL_ON)
      `uvm_field_int(dropped, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ranc_packet");
      super.new(name);
    endfunction

    // Constraint: set coordinates based on destination port
    constraint dest_coord_c {
      (dest_port == PORT_LOCAL) -> (dx == 0 && dy == 0);
      (dest_port == PORT_EAST)  -> (dx == 1 && dy == 0);
      (dest_port == PORT_WEST)  -> (dx == -1 && dy == 0);
      (dest_port == PORT_NORTH) -> (dx == 0 && dy == 1);
      (dest_port == PORT_SOUTH) -> (dx == 0 && dy == -1);
    }

    // Constraint: source port can only be LOCAL (single router test)
    constraint source_port_c {
      source_port == PORT_LOCAL;
    }
  endclass

  //==================================================================
  // Configuration class
  //==================================================================
  class ranc_config extends uvm_object;
    traffic_pattern_e traffic_pattern;
    load_level_e load_level;
    hotspot_pattern_e hotspot_pattern;
    int num_packets_per_stream = 100;
    int max_cycles = 2000;
    int consumer_rate_east = 1;
    int consumer_rate_west = 1;
    int consumer_rate_north = 1;
    int consumer_rate_south = 1;

    `uvm_object_utils_begin(ranc_config)
      `uvm_field_enum(traffic_pattern_e, traffic_pattern, UVM_ALL_ON)
      `uvm_field_enum(load_level_e, load_level, UVM_ALL_ON)
      `uvm_field_enum(hotspot_pattern_e, hotspot_pattern, UVM_ALL_ON)
      `uvm_field_int(num_packets_per_stream, UVM_ALL_ON)
      `uvm_field_int(max_cycles, UVM_ALL_ON)
      `uvm_field_int(consumer_rate_east, UVM_ALL_ON)
      `uvm_field_int(consumer_rate_west, UVM_ALL_ON)
      `uvm_field_int(consumer_rate_north, UVM_ALL_ON)
      `uvm_field_int(consumer_rate_south, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ranc_config");
      super.new(name);
    endfunction
  endclass

  //==================================================================
  // Performance metrics class
  //==================================================================
  class performance_metrics extends uvm_object;
    int packets_sent;
    int packets_received;
    real throughput;      // packets/cycle
    real latency;         // nanoseconds
    real loss_rate;       // percentage
    time experiment_start_time;
    time experiment_end_time;

    `uvm_object_utils_begin(performance_metrics)
      `uvm_field_int(packets_sent, UVM_ALL_ON)
      `uvm_field_int(packets_received, UVM_ALL_ON)
      `uvm_field_real(throughput, UVM_ALL_ON)
      `uvm_field_real(latency, UVM_ALL_ON)
      `uvm_field_real(loss_rate, UVM_ALL_ON)
      `uvm_field_int(experiment_start_time, UVM_ALL_ON)
      `uvm_field_int(experiment_end_time, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "performance_metrics");
      super.new(name);
    endfunction

    function void calculate_metrics();
      time total_time = experiment_end_time - experiment_start_time;
      if (total_time > 0)
        throughput = (packets_received * 10000.0) / total_time;
      else
        throughput = 0.0;
      if (packets_sent > 0)
        loss_rate = ((packets_sent - packets_received) * 100.0) / packets_sent;
      else
        loss_rate = 0.0;
    endfunction
  endclass

  //==================================================================
  // Coverage group - simplified version
  //==================================================================
  class ranc_coverage extends uvm_subscriber #(ranc_packet);
    `uvm_component_utils(ranc_coverage)

    int port_coverage[5][5];  // [source][dest]
    int payload_coverage[3];  // [low, medium, high]
    int coord_coverage[3][3]; // [dx][dy] -1,0,1

    function new(string name, uvm_component parent);
      super.new(name, parent);
      for (int i = 0; i < 5; i++) begin
        for (int j = 0; j < 5; j++)
          port_coverage[i][j] = 0;
      end
      for (int i = 0; i < 3; i++) begin
        payload_coverage[i] = 0;
        for (int j = 0; j < 3; j++)
          coord_coverage[i][j] = 0;
      end
    endfunction

    function void write(ranc_packet t);
      port_coverage[t.source_port][t.dest_port]++;
      begin
        int dx_idx, dy_idx;
        if (t.dx == -1) dx_idx = 0;
        else if (t.dx == 0) dx_idx = 1;
        else dx_idx = 2;
        if (t.dy == -1) dy_idx = 0;
        else if (t.dy == 0) dy_idx = 1;
        else dy_idx = 2;
        coord_coverage[dx_idx][dy_idx]++;
      end
      if (t.payload <= 15) payload_coverage[0]++;
      else if (t.payload <= 255) payload_coverage[1]++;
      else payload_coverage[2]++;
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info(get_type_name(), "Coverage Report:", UVM_MEDIUM)
      `uvm_info(get_type_name(), "Port Coverage:", UVM_MEDIUM)
      for (int i = 1; i < 5; i++) begin
        for (int j = 1; j < 5; j++) begin
          if (port_coverage[i][j] > 0) begin
            `uvm_info(get_type_name(),
              $sformatf("Port %0d->%0d: %0d packets", i, j, port_coverage[i][j]),
              UVM_MEDIUM)
          end
        end
      end
      `uvm_info(get_type_name(),
        $sformatf("Payload Coverage - Low: %0d, Medium: %0d, High: %0d",
                  payload_coverage[0], payload_coverage[1], payload_coverage[2]),
        UVM_MEDIUM)
      `uvm_info(get_type_name(), "Coordinate Coverage:", UVM_MEDIUM)
      for (int i = 0; i < 3; i++) begin
        for (int j = 0; j < 3; j++) begin
          if (coord_coverage[i][j] > 0) begin
            string dx_str = (i == 0) ? "-1" : ((i == 1) ? "0" : "1");
            string dy_str = (j == 0) ? "-1" : ((j == 1) ? "0" : "1");
            `uvm_info(get_type_name(),
              $sformatf("dx=%s, dy=%s: %0d packets", dx_str, dy_str, coord_coverage[i][j]),
              UVM_MEDIUM)
          end
        end
      end
    endfunction
  endclass

  //==================================================================
  // Unpack and direction inference function
  //==================================================================
  function automatic void unpack_packet(
      input  logic [PACKET_WIDTH-1:0] pkt,
      output int                      dx,
      output int                      dy,
      output int                      payload);
    logic signed [DX_WIDTH-1:0] sdx;
    logic signed [DY_WIDTH-1:0] sdy;
    sdx = pkt[PACKET_WIDTH-1 -: DX_WIDTH];
    sdy = pkt[PACKET_WIDTH-1-DX_WIDTH -: DY_WIDTH];
    dx  = sdx;
    dy  = sdy;
    payload = pkt[PAYLOAD_WIDTH-1:0];
  endfunction

  function automatic port_type_e vector2port(logic [PACKET_WIDTH-1:0] pkt);
    int dx, dy, pl;
    unpack_packet(pkt, dx, dy, pl);
    if (dx > 0)       return PORT_EAST;
    else if (dx < 0)  return PORT_WEST;
    else if (dy > 0)  return PORT_NORTH;
    else if (dy < 0)  return PORT_SOUTH;
    else              return PORT_LOCAL;
  endfunction

  // Convert port type to dx,dy coordinates
  function automatic void port2dxdy(
      input  port_type_e      port,
      output int              dx,
      output int              dy);
    case (port)
      PORT_LOCAL: begin dx = 0;  dy = 0;  end
      PORT_EAST:  begin dx = 1;  dy = 0;  end
      PORT_WEST:  begin dx = -1; dy = 0;  end
      PORT_NORTH: begin dx = 0;  dy = 1;  end
      PORT_SOUTH: begin dx = 0;  dy = -1; end
      default:    begin dx = 0;  dy = 0;  end
    endcase
  endfunction

  // Pack dx, dy, payload into 30-bit packet
  function automatic logic [PACKET_WIDTH-1:0] make_packet(
      input int dx,
      input int dy,
      input int payload);
    logic [PACKET_WIDTH-1:0] pkt;
    logic signed [DX_WIDTH-1:0] sdx;
    logic signed [DY_WIDTH-1:0] sdy;
    sdx = dx;
    sdy = dy;
    pkt = {sdx, sdy, payload[PAYLOAD_WIDTH-1:0]};
    return pkt;
  endfunction

endpackage

//==================================================================
// Virtual interface
//==================================================================
interface ranc_vif(input logic clk, input logic rst);
  parameter int PACKET_WIDTH = 30;
  parameter int DX_MSB = 29;
  parameter int DX_LSB = 21;
  parameter int DY_MSB = 20;
  parameter int DY_LSB = 12;
  parameter int PAYLOAD_WIDTH = DY_LSB;
  parameter int DX_WIDTH = DX_MSB - DX_LSB + 1;
  parameter int DY_WIDTH = DY_MSB - DY_LSB + 1;
  parameter int NORTH_SOUTH_WIDTH = PACKET_WIDTH - (DX_MSB - DY_MSB);

  // DUT input signals
  logic [PACKET_WIDTH-1:0] din_local;
  logic din_local_wen;
  logic [PACKET_WIDTH-1:0] din_east, din_west;
  logic [NORTH_SOUTH_WIDTH-1:0] din_north, din_south;
  logic empty_in_east, empty_in_west;
  logic empty_in_north, empty_in_south;
  logic ren_in_east, ren_in_west, ren_in_north, ren_in_south;

  // DUT output signals
  logic [PACKET_WIDTH-1:0] dout_east, dout_west;
  logic [NORTH_SOUTH_WIDTH-1:0] dout_north, dout_south;
  logic [PAYLOAD_WIDTH-1:0] dout_local;
  logic dout_wen_local;
  logic ren_out_east, ren_out_west, ren_out_north, ren_out_south;
  logic empty_out_east, empty_out_west, empty_out_north, empty_out_south;
  logic local_buffers_full;

  // Consumer control signals
  logic consumer_ready_east, consumer_ready_west;
  logic consumer_ready_north, consumer_ready_south;

  clocking driver_cb @(posedge clk);
    output din_local, din_local_wen;
    output din_east, din_west, din_north, din_south;
    output empty_in_east, empty_in_west, empty_in_north, empty_in_south;
    output ren_in_east, ren_in_west, ren_in_north, ren_in_south;
    output consumer_ready_east, consumer_ready_west, consumer_ready_north, consumer_ready_south;
    input dout_east, dout_west, dout_north, dout_south;
    input dout_local, dout_wen_local;
    input ren_out_east, ren_out_west, ren_out_north, ren_out_south;
    input empty_out_east, empty_out_west, empty_out_north, empty_out_south;
    input local_buffers_full;
  endclocking

  clocking monitor_cb @(posedge clk);
    input din_local, din_local_wen;
    input din_east, din_west, din_north, din_south;
    input empty_in_east, empty_in_west, empty_in_north, empty_in_south;
    input ren_in_east, ren_in_west, ren_in_north, ren_in_south;
    input consumer_ready_east, consumer_ready_west, consumer_ready_north, consumer_ready_south;
    input dout_east, dout_west, dout_north, dout_south;
    input dout_local, dout_wen_local;
    input ren_out_east, ren_out_west, ren_out_north, ren_out_south;
    input empty_out_east, empty_out_west, empty_out_north, empty_out_south;
    input local_buffers_full;
  endclocking

  modport driver_mp(clocking driver_cb);
  modport monitor_mp(clocking monitor_cb);

  task init();
    din_local = 0;
    din_local_wen = 0;
    din_east = 0;
    din_west = 0;
    din_north = 0;
    din_south = 0;
    empty_in_east = 1;
    empty_in_west = 1;
    empty_in_north = 1;
    empty_in_south = 1;
    ren_in_east = 1;
    ren_in_west = 1;
    ren_in_north = 1;
    ren_in_south = 1;
    consumer_ready_east = 1;
    consumer_ready_west = 1;
    consumer_ready_north = 1;
    consumer_ready_south = 1;
  endtask
endinterface


//==================================================================
// ranc_adapter_pkg.sv
// -----------------------------------------------------------------
// Router-specific adapter that maps the generic benchmark core onto
// the RANC router testbench signals (30-bit packet, on/off protocol).
//==================================================================
package ranc_adapter_pkg;

  import uvm_pkg::*;
  import noc_bench_core_pkg::*;
  import ranc_uvm_pkg::ranc_packet;
  import ranc_uvm_pkg::ranc_config;
  import ranc_uvm_pkg::performance_metrics;
  import ranc_uvm_pkg::PACKET_WIDTH;
  import ranc_uvm_pkg::DX_MSB;
  import ranc_uvm_pkg::DX_LSB;
  import ranc_uvm_pkg::DY_MSB;
  import ranc_uvm_pkg::DY_LSB;
  import ranc_uvm_pkg::PAYLOAD_WIDTH;
  import ranc_uvm_pkg::DX_WIDTH;
  import ranc_uvm_pkg::DY_WIDTH;
  import ranc_uvm_pkg::NORTH_SOUTH_WIDTH;
  import ranc_uvm_pkg::unpack_packet;

  `include "uvm_macros.svh"

  // Convert port type (from noc_bench_core_pkg) to dx,dy coordinates
  function automatic void port2dxdy(
      input  noc_bench_core_pkg::port_type_e port,
      output int                              dx,
      output int                              dy);
    case (port)
      noc_bench_core_pkg::PORT_LOCAL: begin dx = 0;  dy = 0;  end
      noc_bench_core_pkg::PORT_EAST:  begin dx = 1;  dy = 0;  end
      noc_bench_core_pkg::PORT_WEST:  begin dx = -1; dy = 0;  end
      noc_bench_core_pkg::PORT_NORTH: begin dx = 0;  dy = 1;  end
      noc_bench_core_pkg::PORT_SOUTH: begin dx = 0;  dy = -1; end
      default:                        begin dx = 0;  dy = 0;  end
    endcase
  endfunction

  // Pack dx, dy, payload into 30-bit packet
  function automatic logic [PACKET_WIDTH-1:0] make_packet(
      input int dx,
      input int dy,
      input int payload);
    logic [PACKET_WIDTH-1:0] pkt;
    logic signed [DX_WIDTH-1:0] sdx;
    logic signed [DY_WIDTH-1:0] sdy;
    sdx = dx;
    sdy = dy;
    pkt = {sdx, sdy, payload[PAYLOAD_WIDTH-1:0]};
    return pkt;
  endfunction

  class ranc_bench_base extends noc_bench_base_test;
    `uvm_component_utils(ranc_bench_base)

    virtual ranc_vif vif;

    // Timestamp lookup tables (cycle-based)
    longint unsigned t_send_by_key30 [logic [29:0]];
    longint unsigned t_send_by_id12  [int unsigned];

    logic prev_empty_east, prev_empty_west, prev_empty_north, prev_empty_south;
    logic [29:0] last_dout_east, last_dout_west;
    logic [20:0] last_dout_north, last_dout_south;
    logic        prev_dout_wen_local;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ranc_vif)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF","Virtual ranc_vif not set")
    endfunction

    virtual function string get_default_csv_path();
      return "ranc_results.csv";
    endfunction

    task automatic wait_for_reset_release();
      wait(!vif.rst);
    endtask

    task automatic wait_cycles(int cycles);
      repeat (cycles) @(posedge vif.clk);
    endtask

    task automatic drain_all(int quiet_cycles = 4, int max_wait_cycles = 1_000_000);
      int ok = 0;
      repeat (max_wait_cycles) begin
        @(posedge vif.clk);
        if (vif.empty_out_east  && vif.empty_out_west &&
            vif.empty_out_north && vif.empty_out_south &&
            !vif.dout_wen_local)
          ok++;
        else
          ok = 0;
        if (ok >= quiet_cycles) break;
      end
    endtask

    task automatic drain_until_empty_or_timeout(int unsigned timeout_cycles);
      int unsigned k=0;
      while (k < timeout_cycles) begin
        if (vif.empty_out_east && vif.empty_out_west &&
            vif.empty_out_north && vif.empty_out_south)
          break;
        @(posedge vif.clk); k++;
      end
    endtask

    task automatic settle_links();
      wait_cycles(8);
    endtask

    function void record_send(port_type_e dst_port, logic [29:0] pkt);
      note_send(dst_port);
      t_send_by_key30[pkt]      = cycle_count;
      t_send_by_id12[pkt[11:0]] = cycle_count;
    endfunction

    function void record_recv_with_key30(port_type_e dst_port, logic [29:0] pkt);
      longint unsigned latency = 0;
      if (t_send_by_key30.exists(pkt)) begin
        latency = cycle_count - t_send_by_key30[pkt];
        t_send_by_key30.delete(pkt);
      end else begin
        int unsigned id12 = pkt[11:0];
        if (t_send_by_id12.exists(id12)) begin
          latency = cycle_count - t_send_by_id12[id12];
          t_send_by_id12.delete(id12);
        end
      end
      note_recv(dst_port, latency);
    endfunction

    function void record_recv_with_id12(port_type_e dst_port, int unsigned id12);
      longint unsigned latency = 0;
      if (t_send_by_id12.exists(id12)) begin
        latency = cycle_count - t_send_by_id12[id12];
        t_send_by_id12.delete(id12);
      end
      note_recv(dst_port, latency);
    endfunction

    virtual function void adapter_exp_begin_hook(string tag);
      t_send_by_key30.delete();
      t_send_by_id12.delete();
      prev_empty_east     = vif.empty_out_east;
      prev_empty_west     = vif.empty_out_west;
      prev_empty_north    = vif.empty_out_north;
      prev_empty_south    = vif.empty_out_south;
      prev_dout_wen_local = 1'b0;
      last_dout_east      = '0;
      last_dout_west      = '0;
      last_dout_north     = '0;
      last_dout_south     = '0;
    endfunction

    // ----------------------------------------------------------------
    // Output monitors
    // ----------------------------------------------------------------
    virtual task start_output_monitors();
      fork
        forever @(posedge vif.clk) begin
          cycle_count++;
          if (!vif.empty_out_east)  last_dout_east  <= vif.dout_east;
          if (!vif.empty_out_west)  last_dout_west  <= vif.dout_west;
          if (!vif.empty_out_north) last_dout_north <= vif.dout_north;
          if (!vif.empty_out_south) last_dout_south <= vif.dout_south;

          if (exp_active && !prev_dout_wen_local && vif.dout_wen_local)
            record_recv_with_key30(PORT_LOCAL, vif.dout_local);

          if (exp_active && !prev_empty_east && vif.empty_out_east)
            record_recv_with_key30(PORT_EAST, last_dout_east);
          if (exp_active && !prev_empty_west && vif.empty_out_west)
            record_recv_with_key30(PORT_WEST, last_dout_west);
          if (exp_active && !prev_empty_north && vif.empty_out_north)
            record_recv_with_id12(PORT_NORTH, last_dout_north[11:0]);
          if (exp_active && !prev_empty_south && vif.empty_out_south)
            record_recv_with_id12(PORT_SOUTH, last_dout_south[11:0]);

          prev_empty_east     <= vif.empty_out_east;
          prev_empty_west     <= vif.empty_out_west;
          prev_empty_north    <= vif.empty_out_north;
          prev_empty_south    <= vif.empty_out_south;
          prev_dout_wen_local <= vif.dout_wen_local;
        end
      join_none
    endtask

    virtual task stop_output_monitors();
      // No background processes to stop (forever fork is detached)
    endtask

    // ----------------------------------------------------------------
    // TX helpers
    // ----------------------------------------------------------------
    task automatic do_tx_one_flit(port_type_e in_port,
                                  port_type_e dst_port,
                                  logic [29:0] pkt);
      case (in_port)
        PORT_LOCAL: begin
          while (vif.local_buffers_full) begin
            note_stall(noc_bench_core_pkg::PORT_LOCAL, 1);
            @(posedge vif.clk);
          end
          vif.din_local     = pkt;
          vif.din_local_wen = 1'b1;
          record_send(dst_port, pkt);
          @(posedge vif.clk);
          vif.din_local_wen = 1'b0;
        end
        PORT_EAST: begin
          wait(vif.empty_in_east);
          vif.din_east      = pkt;
          vif.empty_in_east = 1'b0;
          record_send(dst_port, pkt);
          @(posedge vif.clk);
          while (vif.ren_out_east != 1'b1) begin
            note_stall(noc_bench_core_pkg::PORT_EAST, 1);
            @(posedge vif.clk);
          end
          @(posedge vif.clk);
          vif.empty_in_east = 1'b1;
        end
        PORT_WEST: begin
          wait(vif.empty_in_west);
          vif.din_west      = pkt;
          vif.empty_in_west = 1'b0;
          record_send(dst_port, pkt);
          @(posedge vif.clk);
          while (vif.ren_out_west != 1'b1) begin
            note_stall(noc_bench_core_pkg::PORT_WEST, 1);
            @(posedge vif.clk);
          end
          @(posedge vif.clk);
          vif.empty_in_west = 1'b1;
        end
        PORT_NORTH: begin
          wait(vif.empty_in_north);
          vif.din_north      = pkt[20:0];
          vif.empty_in_north = 1'b0;
          record_send(dst_port, pkt);
          @(posedge vif.clk);
          while (vif.ren_out_north != 1'b1) begin
            note_stall(noc_bench_core_pkg::PORT_NORTH, 1);
            @(posedge vif.clk);
          end
          @(posedge vif.clk);
          vif.empty_in_north = 1'b1;
        end
        PORT_SOUTH: begin
          wait(vif.empty_in_south);
          vif.din_south      = pkt[20:0];
          vif.empty_in_south = 1'b0;
          record_send(dst_port, pkt);
          @(posedge vif.clk);
          while (vif.ren_out_south != 1'b1) begin
            note_stall(noc_bench_core_pkg::PORT_SOUTH, 1);
            @(posedge vif.clk);
          end
          @(posedge vif.clk);
          vif.empty_in_south = 1'b1;
        end
        default: ;
      endcase
    endtask

    virtual task drive_stream_on_port(port_type_e in_port,
                                      port_type_e dst_port,
                                      int          n_pkts,
                                      load_level_e load,
                                      int          payload_seed = 0);
      int gap = load2gap(load);
      int dx, dy;
      int i;
      account_scheduled_packets(n_pkts);
      wait_for_reset_release();
      repeat (2) @(posedge vif.clk);
      driver_enter();
      port2dxdy(dst_port, dx, dy);
      for (i = 0; i < n_pkts; i++) begin
        int unsigned pid;
        logic [29:0] pkt;
        if (should_stop_drivers())
          break;
        pid = payload_seed + i;
        pkt = make_packet(dx, dy, pid);
        do_tx_one_flit(in_port, dst_port, pkt);
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

  // ----------------------------------------------------------------
  // Concrete reusable tests (instantiate parameterized bases)
  // ----------------------------------------------------------------
  class ranc_functional_test extends noc_functional_test_base#(ranc_bench_base);
    `uvm_component_utils(ranc_functional_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ranc_system_benchmark_test extends noc_system_benchmark_test_base#(ranc_bench_base);
    `uvm_component_utils(ranc_system_benchmark_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ranc_hotspot_analysis_test extends noc_hotspot_analysis_test_base#(ranc_bench_base);
    `uvm_component_utils(ranc_hotspot_analysis_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ranc_transfer_rate_test extends noc_transfer_rate_test_base#(ranc_bench_base);
    `uvm_component_utils(ranc_transfer_rate_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ranc_all_in_one_test extends noc_all_in_one_test_base#(ranc_bench_base);
    `uvm_component_utils(ranc_all_in_one_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ranc_simple_test extends noc_simple_test_base#(ranc_bench_base);
    `uvm_component_utils(ranc_simple_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

endpackage

