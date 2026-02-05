//==================================================================
// noc_bench_core_pkg.sv
// -----------------------------------------------------------------
// Router-agnostic UVM benchmark core shared across all adapters.
// Provides:
//   * Unified enums/config data structures
//   * Common experiment lifecycle + statistics + CSV logging
//   * Reusable traffic pattern drivers and benchmark scenarios
//   * Abstract hooks for router-specific adapters (signals/flits)
//==================================================================
package noc_bench_core_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---------------------------------------------------------------
  // Shared enums and helpers
  // ---------------------------------------------------------------
  typedef enum int {
    PORT_LOCAL = 0,
    PORT_EAST  = 1,
    PORT_WEST  = 2,
    PORT_NORTH = 3,
    PORT_SOUTH = 4
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

  localparam int NOC_NUM_PORTS = 5;

  function automatic int port2idx(port_type_e p);
    case (p)
      PORT_LOCAL:  return 0;
      PORT_EAST:   return 1;
      PORT_WEST:   return 2;
      PORT_NORTH:  return 3;
      PORT_SOUTH:  return 4;
      default:     return 0;
    endcase
  endfunction

  function automatic string port2str(port_type_e p);
    case (p)
      PORT_LOCAL: return "local";
      PORT_EAST:  return "east";
      PORT_WEST:  return "west";
      PORT_NORTH: return "north";
      PORT_SOUTH: return "south";
      default:    return "unknown";
    endcase
  endfunction

  function automatic string port2enum_str(port_type_e p);
    case (p)
      PORT_LOCAL: return "PORT_LOCAL";
      PORT_EAST:  return "PORT_EAST";
      PORT_WEST:  return "PORT_WEST";
      PORT_NORTH: return "PORT_NORTH";
      PORT_SOUTH: return "PORT_SOUTH";
      default:    return "PORT_UNKNOWN";
    endcase
  endfunction

  function automatic string pattern2str(traffic_pattern_e pat);
    case (pat)
      PATTERN_UNIFORM:   return "uniform";
      PATTERN_HOTSPOT:   return "hotspot";
      PATTERN_TRANSPOSE: return "transpose";
      default:           return "unknown";
    endcase
  endfunction

  function automatic string load2str(load_level_e load);
    case (load)
      LOAD_LIGHT:     return "light";
      LOAD_MEDIUM:    return "medium";
      LOAD_HEAVY:     return "heavy";
      LOAD_SATURATED: return "saturated";
      default:        return "light";
    endcase
  endfunction

  function automatic string hotspot2str(hotspot_pattern_e hp);
    case (hp)
      HOTSPOT_1PORT:  return "north";
      HOTSPOT_2PORTS: return "north_south";
      HOTSPOT_3PORTS: return "north_south_east";
      HOTSPOT_4PORTS: return "north_south_east_west";
      default:        return "north";
    endcase
  endfunction

  function automatic int load2gap(load_level_e l);
    case (l)
      LOAD_LIGHT:     return 8;
      LOAD_MEDIUM:    return 4;
      LOAD_HEAVY:     return 2;
      LOAD_SATURATED: return 1;
      default:        return 8;
    endcase
  endfunction

  typedef struct packed {
    port_type_e src;
    port_type_e dst;
  } transfer_path_t;

  localparam int NUM_TRANSFER_PATHS = 20;
  localparam transfer_path_t TRANSFER_PATHS [20] = '{
    '{PORT_LOCAL, PORT_NORTH}, '{PORT_NORTH, PORT_LOCAL},
    '{PORT_SOUTH, PORT_LOCAL}, '{PORT_WEST,  PORT_LOCAL},
    '{PORT_EAST,  PORT_LOCAL},
    '{PORT_LOCAL, PORT_SOUTH}, '{PORT_NORTH, PORT_SOUTH},
    '{PORT_SOUTH, PORT_NORTH}, '{PORT_WEST,  PORT_NORTH},
    '{PORT_EAST,  PORT_NORTH},
    '{PORT_LOCAL, PORT_WEST},  '{PORT_NORTH, PORT_WEST},
    '{PORT_SOUTH, PORT_WEST},  '{PORT_WEST,  PORT_SOUTH},
    '{PORT_EAST,  PORT_SOUTH},
    '{PORT_LOCAL, PORT_EAST},  '{PORT_NORTH, PORT_EAST},
    '{PORT_SOUTH, PORT_EAST},  '{PORT_WEST,  PORT_EAST},
    '{PORT_EAST,  PORT_WEST}
  };

  // ---------------------------------------------------------------
  // Shared configuration container
  // ---------------------------------------------------------------
  class noc_bench_config extends uvm_object;
    traffic_pattern_e traffic_pattern;
    load_level_e      load_level;
    hotspot_pattern_e hotspot_pattern;
    int               num_packets_per_stream = 500;
    int               max_cycles             = 2000;

    `uvm_object_utils_begin(noc_bench_config)
      `uvm_field_enum(traffic_pattern_e, traffic_pattern, UVM_ALL_ON)
      `uvm_field_enum(load_level_e,      load_level,      UVM_ALL_ON)
      `uvm_field_enum(hotspot_pattern_e, hotspot_pattern, UVM_ALL_ON)
      `uvm_field_int (num_packets_per_stream,             UVM_ALL_ON)
      `uvm_field_int (max_cycles,                         UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "noc_bench_config");
      super.new(name);
      traffic_pattern = PATTERN_UNIFORM;
      load_level      = LOAD_LIGHT;
      hotspot_pattern = HOTSPOT_4PORTS;
    endfunction
  endclass

  // ---------------------------------------------------------------
  // Router-agnostic experiment core (abstract hooks for adapters)
  // ---------------------------------------------------------------
  virtual class noc_bench_base_test extends uvm_test;
    `uvm_component_utils(noc_bench_base_test)

    // Configuration / knobs
    noc_bench_config cfg;
    bit          use_time_window      = 1'b0;
    int unsigned measure_cycles       = 2000;
    bit          do_drain             = 1'b0;
    int unsigned drain_timeout_cycles = 0;

    // Statistics
    bit           exp_active;
    longint unsigned cycle_count;
    longint unsigned exp_t_begin;
    longint unsigned exp_t_end;
    longint unsigned scheduled_send_total;
    longint unsigned send_cnt_total;
    longint unsigned recv_cnt_total;
    longint unsigned send_cnt_by_dst [NOC_NUM_PORTS];
    longint unsigned recv_cnt_by_dst [NOC_NUM_PORTS];
    longint unsigned stall_cnt_by_src [NOC_NUM_PORTS];
    longint unsigned latency_sum;

    // CSV
    int        csv_fd;
    static bit csv_header_written = 1'b0;
    string     csv_path;

    // Latency Sampling
    int        latency_fd;
    static bit latency_header_written = 1'b0;
    string     latency_csv_path;
    string     current_exp_tag;

    // Driver coordination (window mode)
    bit                stop_drivers;
    int unsigned       active_driver_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = noc_bench_config::type_id::create("cfg");
      read_plusargs();
      csv_path = get_default_csv_path();
      begin
        string p;
        if ($value$plusargs("CSV=%s", p))
          csv_path = p;
      end
      csv_fd = $fopen(csv_path, "w");
      if (csv_fd == 0) begin
        `uvm_warning("CSV_OPEN",
          $sformatf("Cannot open CSV file: %s", csv_path))
      end
      else if (!csv_header_written) begin
        csv_header_written = 1'b1;
        $fdisplay(csv_fd,
          "test,tag,start_cycles,end_cycles,duration_cycles,scheduled_send,send,recv,loss_percent,throughput_packets_per_cycle,avg_latency_cycles,dest_local,dest_east,dest_west,dest_north,dest_south,egress_local,egress_east,egress_west,egress_north,egress_south,stall_local,stall_east,stall_west,stall_north,stall_south");
        $fflush(csv_fd);
      end

      // Setup Latency CSV
      latency_csv_path = "latency_samples.csv";
      begin
        string p;
        if ($value$plusargs("LATENCY_CSV=%s", p))
          latency_csv_path = p;
      end
      latency_fd = $fopen(latency_csv_path, "w");
      if (latency_fd == 0) begin
        `uvm_warning("LAT_CSV_OPEN", 
          $sformatf("Cannot open Latency CSV file: %s", latency_csv_path))
      end
      else if (!latency_header_written) begin
        latency_header_written = 1'b1;
        $fdisplay(latency_fd, "tag,latency_cycles");
        $fflush(latency_fd);
      end
    endfunction

    virtual function string get_default_csv_path();
      return "router_results.csv";
    endfunction

    // Derived adapters should call these helpers inside drivers.
    function void driver_enter();
      active_driver_count++;
    endfunction

    function void driver_exit();
      if (active_driver_count > 0)
        active_driver_count--;
    endfunction

    function bit should_stop_drivers();
      return stop_drivers;
    endfunction

    function void account_scheduled_packets(int count);
      scheduled_send_total += count;
    endfunction

    function void note_send(port_type_e dst_port);
      send_cnt_total++;
      send_cnt_by_dst[port2idx(dst_port)]++;
    endfunction

    function void note_recv(port_type_e dst_port, longint unsigned latency_sample);
      recv_cnt_total++;
      recv_cnt_by_dst[port2idx(dst_port)]++;
      if (latency_sample > 0)
        latency_sum += latency_sample;

      if (latency_fd != 0) begin
        $fdisplay(latency_fd, "%s,%0d", current_exp_tag, latency_sample);
      end
    endfunction

    function void note_stall(port_type_e src_port, int cycles);
      stall_cnt_by_src[port2idx(src_port)] += cycles;
    endfunction

    virtual function void adapter_exp_begin_hook(string tag);
    endfunction

    virtual function void adapter_exp_end_hook(string tag);
    endfunction

    task automatic exp_begin(string tag);
      int i;
      current_exp_tag = tag;
      // Critical fix: call hook to initialize adapter state before setting exp_active
      // Prevents monitor from sampling before prev_egress_valid is initialized
      adapter_exp_begin_hook(tag);
      exp_active            = 1'b1;
      send_cnt_total        = 0;
      recv_cnt_total        = 0;
      scheduled_send_total  = 0;
      latency_sum           = 0;
      for (i = 0; i < NOC_NUM_PORTS; i++) begin
        send_cnt_by_dst[i]  = 0;
        recv_cnt_by_dst[i]  = 0;
        stall_cnt_by_src[i] = 0;
      end
      cycle_count           = 0;
      exp_t_begin           = cycle_count;
      stop_drivers          = 1'b0;
      active_driver_count   = 0;
      `uvm_info(get_type_name(),
        $sformatf("<< EXP BEGIN: %s @ %0d cycles >>", tag, exp_t_begin),
        UVM_MEDIUM)
    endtask

    task automatic exp_end(string tag);
      longint unsigned dur_cycles;
      real throughput;
      real avg_latency;
      real loss_rate;
      longint unsigned cycle_pre_drain;

      cycle_pre_drain = cycle_count;

      if (send_cnt_total != recv_cnt_total) begin
        wait_with_timeout(tag);
      end

      if (send_cnt_total != recv_cnt_total)
        exp_t_end = cycle_pre_drain;
      else
        exp_t_end = cycle_count;

      dur_cycles = (exp_t_end > exp_t_begin) ? (exp_t_end - exp_t_begin) : 0;
      throughput = (dur_cycles > 0) ? real'(recv_cnt_total) / real'(dur_cycles) : 0.0;
      avg_latency = (recv_cnt_total > 0) ? real'(latency_sum) / real'(recv_cnt_total) : 0.0;
      if (send_cnt_total > 0)
        loss_rate = (real'(send_cnt_total - recv_cnt_total) * 100.0) / real'(send_cnt_total);
      else
        loss_rate = 0.0;
      if (loss_rate < 0.0) loss_rate = 0.0;
      if (recv_cnt_total > send_cnt_total) begin
        `uvm_warning("RECV_GT_SEND",
          $sformatf("Experiment %s: recv(%0d) > send(%0d)",
                    tag, recv_cnt_total, send_cnt_total))
      end
      exp_active = 1'b0;
      adapter_exp_end_hook(tag);
      `uvm_info(get_type_name(),
        $sformatf("<< EXP END : %s @ %0d cycles  dur=%0d cycles >>",
                  tag, exp_t_end, dur_cycles),
        UVM_MEDIUM)
      `uvm_info("STATS",
        $sformatf("SCHEDULED=%0d SEND=%0d RECV=%0d LOSS=%.2f%% THR=%.4f pkts/cycle LAT=%.2f cycles",
                  scheduled_send_total, send_cnt_total, recv_cnt_total,
                  loss_rate, throughput, avg_latency),
        UVM_MEDIUM)
      if (csv_fd != 0) begin
        $fdisplay(csv_fd,
          "%s,%s,%0d,%0d,%0d,%0d,%0d,%0d,%.2f,%.4f,%.2f,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
          get_type_name(), tag, exp_t_begin, exp_t_end, dur_cycles,
          scheduled_send_total, send_cnt_total, recv_cnt_total,
          loss_rate, throughput, avg_latency,
          send_cnt_by_dst[0], send_cnt_by_dst[1], send_cnt_by_dst[2], send_cnt_by_dst[3], send_cnt_by_dst[4],
          recv_cnt_by_dst[0], recv_cnt_by_dst[1], recv_cnt_by_dst[2], recv_cnt_by_dst[3], recv_cnt_by_dst[4],
          stall_cnt_by_src[0], stall_cnt_by_src[1], stall_cnt_by_src[2], stall_cnt_by_src[3], stall_cnt_by_src[4]);
        $fflush(csv_fd);
      end

      if (latency_fd != 0) begin
        $fflush(latency_fd);
      end
    endtask

    task automatic wait_with_timeout(string tag);
      longint unsigned limit_cycles;
      longint unsigned waited;
      limit_cycles = cfg.max_cycles;
      if (scheduled_send_total > 0) begin
        longint unsigned scaled;
        scaled = longint'(scheduled_send_total) * 20;
        if (scaled > limit_cycles)
          limit_cycles = scaled;
      end
      waited = 0;
      while ((send_cnt_total != recv_cnt_total) && (waited < limit_cycles)) begin
        wait_cycles(1);
        waited++;
      end
      if (send_cnt_total != recv_cnt_total) begin
        `uvm_warning("DRAIN_TIMEOUT",
          $sformatf("Experiment %s timed out: send=%0d recv=%0d (limit=%0d cycles)",
                    tag, send_cnt_total, recv_cnt_total, limit_cycles))
      end
    endtask

    // -----------------------------------------------------------
    // Measurement window orchestration helpers
    // -----------------------------------------------------------
    task automatic run_pattern_job(traffic_pattern_e pattern,
                                   load_level_e      load,
                                   int               pkts_per_stream);
      stop_drivers = 1'b0;
      if (use_time_window) begin
        fork
          drive_pattern(pattern, load, pkts_per_stream);
        join_none
        wait_cycles(measure_cycles);
        request_stop_drivers();
        wait_for_drivers_idle();
        stop_drivers = 1'b0;
        settle_links();
        if (do_drain && drain_timeout_cycles > 0)
          drain_until_empty_or_timeout(drain_timeout_cycles);
      end else begin
        drive_pattern(pattern, load, pkts_per_stream);
        settle_links();
        if (do_drain)
          drain_all();
      end
    endtask

    task automatic run_hotspot_job(hotspot_pattern_e hotspot,
                                   load_level_e      load,
                                   int               pkts_per_stream);
      stop_drivers = 1'b0;
      if (use_time_window) begin
        fork
          drive_hotspot_subpattern(hotspot, load, pkts_per_stream);
        join_none
        wait_cycles(measure_cycles);
        request_stop_drivers();
        wait_for_drivers_idle();
        stop_drivers = 1'b0;
        settle_links();
        if (do_drain && drain_timeout_cycles > 0)
          drain_until_empty_or_timeout(drain_timeout_cycles);
      end else begin
        drive_hotspot_subpattern(hotspot, load, pkts_per_stream);
        settle_links();
        if (do_drain)
          drain_all();
      end
    endtask

    task automatic run_stream_job(port_type_e src,
                                  port_type_e dst,
                                  int          pkts,
                                  load_level_e load,
                                  int          payload_seed);
      stop_drivers = 1'b0;
      if (use_time_window) begin
        fork
          drive_stream_on_port(src, dst, pkts, load, payload_seed);
        join_none
        wait_cycles(measure_cycles);
        request_stop_drivers();
        wait_for_drivers_idle();
        stop_drivers = 1'b0;
        settle_links();
        if (do_drain && drain_timeout_cycles > 0)
          drain_until_empty_or_timeout(drain_timeout_cycles);
      end else begin
        drive_stream_on_port(src, dst, pkts, load, payload_seed);
        settle_links();
        if (do_drain)
          drain_all();
      end
    endtask

    task automatic request_stop_drivers();
      stop_drivers = 1'b1;
    endtask

    task automatic wait_for_drivers_idle();
      while (active_driver_count != 0)
        wait_cycles(1);
    endtask
    
    // Helper task for transfer_rate tests with path validation
    task automatic run_transfer_rate_if_valid(port_type_e src, port_type_e dst, int seed_offset);
      string tag;
      if (is_valid_transfer_path(src, dst)) begin
        tag = $sformatf("transfer_rate_%s_to_%s", port2enum_str(src), port2enum_str(dst));
        this.exp_begin(tag);
        this.cfg.load_level = LOAD_SATURATED;
        this.run_stream_job(src, dst, 100, this.cfg.load_level, 32'hB0_000 + seed_offset);
        this.exp_end(tag);
      end
    endtask

    // -----------------------------------------------------------
    // Traffic generators (router-agnostic topology)
    // -----------------------------------------------------------
    virtual task automatic drive_pattern(traffic_pattern_e pattern,
                                 load_level_e      load,
                                 int               pkts_per_stream);
      case (pattern)
        PATTERN_UNIFORM: begin
          fork
            drive_stream_on_port(PORT_EAST,   PORT_LOCAL, pkts_per_stream, load, 32'h10_000);
            drive_stream_on_port(PORT_LOCAL,  PORT_SOUTH, pkts_per_stream, load, 32'h20_000);
            drive_stream_on_port(PORT_SOUTH,  PORT_WEST,  pkts_per_stream, load, 32'h30_000);
            drive_stream_on_port(PORT_WEST,   PORT_NORTH, pkts_per_stream, load, 32'h40_000);
            drive_stream_on_port(PORT_NORTH,  PORT_EAST,  pkts_per_stream, load, 32'h50_000);
          join
        end
        PATTERN_HOTSPOT: begin
          fork
            drive_stream_on_port(PORT_EAST,   PORT_LOCAL, pkts_per_stream, load, 32'h60_000);
            drive_stream_on_port(PORT_WEST,   PORT_LOCAL, pkts_per_stream, load, 32'h61_000);
            drive_stream_on_port(PORT_NORTH,  PORT_LOCAL, pkts_per_stream, load, 32'h62_000);
            drive_stream_on_port(PORT_SOUTH,  PORT_LOCAL, pkts_per_stream, load, 32'h63_000);
          join
        end
        PATTERN_TRANSPOSE: begin
          fork
            // drive_stream_on_port(PORT_LOCAL,  PORT_LOCAL, pkts_per_stream, load, 32'h70_000);
            drive_stream_on_port(PORT_EAST,   PORT_WEST,  pkts_per_stream, load, 32'h71_000);
            drive_stream_on_port(PORT_WEST,   PORT_EAST,  pkts_per_stream, load, 32'h72_000);
            drive_stream_on_port(PORT_NORTH,  PORT_SOUTH, pkts_per_stream, load, 32'h73_000);
            drive_stream_on_port(PORT_SOUTH,  PORT_NORTH, pkts_per_stream, load, 32'h74_000);
          join
        end
        default: ;
      endcase
    endtask

    virtual task automatic drive_hotspot_subpattern(hotspot_pattern_e hotspot,
                                            load_level_e      load,
                                            int               pkts_per_stream);
      case (hotspot)
        HOTSPOT_1PORT: begin
          drive_stream_on_port(PORT_NORTH, PORT_LOCAL, pkts_per_stream, load, 32'h60_000);
        end
        HOTSPOT_2PORTS: begin
          fork
            drive_stream_on_port(PORT_NORTH, PORT_LOCAL, pkts_per_stream, load, 32'h60_000);
            drive_stream_on_port(PORT_SOUTH, PORT_LOCAL, pkts_per_stream, load, 32'h61_000);
          join
        end
        HOTSPOT_3PORTS: begin
          fork
            drive_stream_on_port(PORT_NORTH, PORT_LOCAL, pkts_per_stream, load, 32'h60_000);
            drive_stream_on_port(PORT_SOUTH, PORT_LOCAL, pkts_per_stream, load, 32'h61_000);
            drive_stream_on_port(PORT_EAST,  PORT_LOCAL, pkts_per_stream, load, 32'h62_000);
          join
        end
        default: begin
          fork
            drive_stream_on_port(PORT_NORTH, PORT_LOCAL, pkts_per_stream, load, 32'h60_000);
            drive_stream_on_port(PORT_SOUTH, PORT_LOCAL, pkts_per_stream, load, 32'h61_000);
            drive_stream_on_port(PORT_EAST,  PORT_LOCAL, pkts_per_stream, load, 32'h62_000);
            drive_stream_on_port(PORT_WEST,  PORT_LOCAL, pkts_per_stream, load, 32'h63_000);
          join
        end
      endcase
    endtask

    // -----------------------------------------------------------
    // Pure virtual tasks (must be implemented by derived classes)
    // -----------------------------------------------------------
    pure virtual task start_output_monitors();
    pure virtual task drive_stream_on_port(port_type_e in_port,
                                           port_type_e dst_port,
                                           int          n_pkts,
                                           load_level_e load,
                                           int          payload_seed = 0);
    pure virtual task wait_for_reset_release();
    pure virtual task wait_cycles(int cycles);
    
    // -----------------------------------------------------------
    // Virtual function for path validation (can be overridden)
    // -----------------------------------------------------------
    virtual function bit is_valid_transfer_path(port_type_e src, port_type_e dst);
      // Default: all paths valid except src==dst
      if (src == dst)
        return 0;
      return 1;
    endfunction

    // -----------------------------------------------------------
    // Optional virtual tasks with default implementations
    // -----------------------------------------------------------
    virtual task stop_output_monitors();
      // optional override
    endtask

    virtual task drain_all(int quiet_cycles = 4, int max_wait_cycles = 1000000);
      // optional override
    endtask

    virtual task drain_until_empty_or_timeout(int unsigned timeout_cycles);
      // optional override
    endtask

    virtual task settle_links();
      // optional override
    endtask

    // -----------------------------------------------------------
    // Plusarg parsing
    // -----------------------------------------------------------
    protected function void read_plusargs();
      int v;
      if ($value$plusargs("USE_WIN=%0d", v))
        use_time_window = (v != 0);
      if ($value$plusargs("MEAS_WIN=%0d", v))
        measure_cycles = v;
      if ($value$plusargs("NO_DRAIN=%0d", v)) begin
        if (v != 0) do_drain = 1'b0;
        else        do_drain = 1'b1;
      end
      if ($value$plusargs("DRAIN_TO=%0d", v))
        drain_timeout_cycles = v;
      if ($value$plusargs("PKTS_PER_STREAM=%0d", v))
        cfg.num_packets_per_stream = v;
    endfunction

  endclass // noc_bench_base_test

  // ---------------------------------------------------------------
  // Reusable benchmark scenarios (parameterized base class)
  // ---------------------------------------------------------------
  class noc_functional_test_base #(type BASE_T = noc_bench_base_test)
    extends BASE_T;

    `uvm_component_param_utils(noc_functional_test_base #(BASE_T))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      string tag;
      phase.raise_objection(this);
      // Functional test uses completion mode
      this.use_time_window = 1'b0;
      this.measure_cycles = 2000;
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

  class noc_system_benchmark_test_base #(type BASE_T = noc_bench_base_test)
    extends BASE_T;

    `uvm_component_param_utils(noc_system_benchmark_test_base #(BASE_T))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      int pattern, load;
      string tag;
      phase.raise_objection(this);
      this.start_output_monitors();
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
      phase.drop_objection(this);
    endtask
  endclass

  class noc_hotspot_analysis_test_base #(type BASE_T = noc_bench_base_test)
    extends BASE_T;

    `uvm_component_param_utils(noc_hotspot_analysis_test_base #(BASE_T))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      int hotspot, load;
      string tag;
      phase.raise_objection(this);
      this.start_output_monitors();
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

  class noc_transfer_rate_test_base #(type BASE_T = noc_bench_base_test)
    extends BASE_T;

    `uvm_component_param_utils(noc_transfer_rate_test_base #(BASE_T))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      int idx;
      string tag;
      phase.raise_objection(this);
      // Transfer rate test uses completion mode
      this.use_time_window = 1'b0;
      this.measure_cycles = 2000;
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

  class noc_all_in_one_test_base #(type BASE_T = noc_bench_base_test)
    extends BASE_T;

    `uvm_component_param_utils(noc_all_in_one_test_base #(BASE_T))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      int pattern, load, hotspot, idx;
      string tag;
      phase.raise_objection(this);
      this.start_output_monitors();

      // Functional basic (completion mode)
      this.use_time_window = 1'b0;
      this.measure_cycles = 2000;
      tag = "functional_basic";
      this.exp_begin(tag);
      this.cfg.traffic_pattern        = PATTERN_UNIFORM;
      this.cfg.load_level             = LOAD_LIGHT;
      this.cfg.num_packets_per_stream = 100;
      this.run_pattern_job(this.cfg.traffic_pattern,
                           this.cfg.load_level,
                           this.cfg.num_packets_per_stream);
      this.exp_end(tag);

      // Transfer rate (completion mode, 20 explicit paths, filtered by is_valid_transfer_path)
      this.use_time_window = 1'b0;
      this.measure_cycles = 2000;
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

      // System benchmark (3x4, actual time mode like old RANC)
      this.use_time_window = 1'b0;
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

      // Hotspot analysis (4x4, actual time mode like old RANC)
      this.use_time_window = 1'b0;
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

  class noc_simple_test_base #(type BASE_T = noc_bench_base_test)
    extends BASE_T;

    `uvm_component_param_utils(noc_simple_test_base #(BASE_T))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      `uvm_info("SIMPLE", "Running placeholder simple test", UVM_MEDIUM)
      this.wait_cycles(100);
      `uvm_info("SIMPLE", "Simple test finished", UVM_MEDIUM)
      phase.drop_objection(this);
    endtask
  endclass

endpackage


