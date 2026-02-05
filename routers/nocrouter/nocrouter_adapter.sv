package router_uvm_pkg;

  import uvm_pkg::*;
  import noc_params::*;
  `include "uvm_macros.svh"

  // Enum definitions (consistent with legacy code)
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

  function automatic int load2gap(load_level_e l);
    case (l)
      LOAD_LIGHT:     return 8;
      LOAD_MEDIUM:    return 4;
      LOAD_HEAVY:     return 2;
      LOAD_SATURATED: return 1;
      default:        return 8;
    endcase
  endfunction

  function automatic int port2idx(port_t p);
    case (p)
      LOCAL: return 0;
      NORTH: return 1;
      SOUTH: return 2;
      WEST:  return 3;
      EAST:  return 4;
      default: return 0;
    endcase
  endfunction

  function automatic string port_name(port_t p);
    case (p)
      LOCAL: return "LOCAL";
      NORTH: return "NORTH";
      SOUTH: return "SOUTH";
      WEST:  return "WEST";
      EAST:  return "EAST";
      default: return "UNKNOWN";
    endcase
  endfunction

  function automatic void dest_coords_from_port(
    port_t dst,
    input int x_current,
    input int y_current,
    output logic [DEST_ADDR_SIZE_X-1:0] x_dest,
    output logic [DEST_ADDR_SIZE_Y-1:0] y_dest
  );
    int x_val;
    int y_val;
    x_val = x_current;
    y_val = y_current;
    unique case (dst)
      EAST: begin
        x_val = (x_current < MESH_SIZE_X-1) ? (x_current + 1) : x_current;
      end
      WEST: begin
        x_val = (x_current > 0) ? (x_current - 1) : x_current;
      end
      NORTH: begin
        y_val = (y_current > 0) ? (y_current - 1) : y_current;
      end
      SOUTH: begin
        y_val = (y_current < MESH_SIZE_Y-1) ? (y_current + 1) : y_current;
      end
      default: begin
        x_val = x_current;
        y_val = y_current;
      end
    endcase
    x_dest = x_val[DEST_ADDR_SIZE_X-1:0];
    y_dest = y_val[DEST_ADDR_SIZE_Y-1:0];
  endfunction

  function automatic int unsigned make_payload_key(logic [HEAD_PAYLOAD_SIZE-1:0] payload);
    return int'(payload);
  endfunction

  function automatic string pattern2str(traffic_pattern_e pat);
    case (pat)
      PATTERN_UNIFORM:   return "uniform";
      PATTERN_HOTSPOT:   return "hotspot";
      PATTERN_TRANSPOSE: return "transpose";
      default:           return "unknown";
    endcase
  endfunction

  function automatic string load2str(load_level_e l);
    case (l)
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

  // Router config (full version, consistent with legacy code)
  class router_config extends uvm_object;
    traffic_pattern_e traffic_pattern;
    load_level_e      load_level;
    hotspot_pattern_e hotspot_pattern;
    int               num_packets_per_stream = 500;
    int               max_cycles             = 2000;
    int               x_current              = MESH_SIZE_X/2;
    int               y_current              = MESH_SIZE_Y/2;
    
    `uvm_object_utils_begin(router_config)
      `uvm_field_enum(traffic_pattern_e, traffic_pattern, UVM_ALL_ON)
      `uvm_field_enum(load_level_e,      load_level,      UVM_ALL_ON)
      `uvm_field_enum(hotspot_pattern_e, hotspot_pattern, UVM_ALL_ON)
      `uvm_field_int (num_packets_per_stream,             UVM_ALL_ON)
      `uvm_field_int (max_cycles,                         UVM_ALL_ON)
      `uvm_field_int (x_current,                          UVM_ALL_ON)
      `uvm_field_int (y_current,                          UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name="router_config");
      super.new(name);
      traffic_pattern = PATTERN_UNIFORM;
      load_level      = LOAD_LIGHT;
      hotspot_pattern = HOTSPOT_4PORTS;
    endfunction
  endclass

endpackage


import noc_params::*;

interface router_tb_if (
    input logic clk,
    input logic rst
);

    router2router ingress_if [PORT_NUM-1:0] ();
    router2router egress_if  [PORT_NUM-1:0] ();

    function automatic void init_links();
        ingress_if[LOCAL].data      = '0;
        ingress_if[LOCAL].is_valid  = 1'b0;
        ingress_if[NORTH].data      = '0;
        ingress_if[NORTH].is_valid  = 1'b0;
        ingress_if[SOUTH].data      = '0;
        ingress_if[SOUTH].is_valid  = 1'b0;
        ingress_if[WEST ].data      = '0;
        ingress_if[WEST ].is_valid  = 1'b0;
        ingress_if[EAST ].data      = '0;
        ingress_if[EAST ].is_valid  = 1'b0;

        egress_if[LOCAL].is_on_off      = {VC_NUM{1'b1}};
        egress_if[LOCAL].is_allocatable = {VC_NUM{1'b1}};
        egress_if[NORTH].is_on_off      = {VC_NUM{1'b1}};
        egress_if[NORTH].is_allocatable = {VC_NUM{1'b1}};
        egress_if[SOUTH].is_on_off      = {VC_NUM{1'b1}};
        egress_if[SOUTH].is_allocatable = {VC_NUM{1'b1}};
        egress_if[WEST ].is_on_off      = {VC_NUM{1'b1}};
        egress_if[WEST ].is_allocatable = {VC_NUM{1'b1}};
        egress_if[EAST ].is_on_off      = {VC_NUM{1'b1}};
        egress_if[EAST ].is_allocatable = {VC_NUM{1'b1}};
    endfunction

    function automatic logic get_ingress_valid(port_t port_sel);
        unique case (port_sel)
            LOCAL: get_ingress_valid = ingress_if[LOCAL].is_valid;
            NORTH: get_ingress_valid = ingress_if[NORTH].is_valid;
            SOUTH: get_ingress_valid = ingress_if[SOUTH].is_valid;
            WEST : get_ingress_valid = ingress_if[WEST ].is_valid;
            EAST : get_ingress_valid = ingress_if[EAST ].is_valid;
            default: get_ingress_valid = 1'b0;
        endcase
    endfunction

    function automatic logic get_egress_valid(port_t port_sel);
        unique case (port_sel)
            LOCAL: get_egress_valid = egress_if[LOCAL].is_valid;
            NORTH: get_egress_valid = egress_if[NORTH].is_valid;
            SOUTH: get_egress_valid = egress_if[SOUTH].is_valid;
            WEST : get_egress_valid = egress_if[WEST ].is_valid;
            EAST : get_egress_valid = egress_if[EAST ].is_valid;
            default: get_egress_valid = 1'b0;
        endcase
    endfunction

    function automatic flit_t get_egress_data(port_t port_sel);
        flit_t tmp;
        tmp = '0;
        unique case (port_sel)
            LOCAL: tmp = egress_if[LOCAL].data;
            NORTH: tmp = egress_if[NORTH].data;
            SOUTH: tmp = egress_if[SOUTH].data;
            WEST : tmp = egress_if[WEST ].data;
            EAST : tmp = egress_if[EAST ].data;
            default: tmp = '0;
        endcase
        return tmp;
    endfunction

    function automatic logic [VC_NUM-1:0] get_ingress_on_off(port_t port_sel);
        unique case (port_sel)
            LOCAL: return ingress_if[LOCAL].is_on_off;
            NORTH: return ingress_if[NORTH].is_on_off;
            SOUTH: return ingress_if[SOUTH].is_on_off;
            WEST : return ingress_if[WEST ].is_on_off;
            EAST : return ingress_if[EAST ].is_on_off;
            default: return '0;
        endcase
    endfunction

    function automatic logic [VC_NUM-1:0] get_ingress_allocatable(port_t port_sel);
        unique case (port_sel)
            LOCAL: return ingress_if[LOCAL].is_allocatable;
            NORTH: return ingress_if[NORTH].is_allocatable;
            SOUTH: return ingress_if[SOUTH].is_allocatable;
            WEST : return ingress_if[WEST ].is_allocatable;
            EAST : return ingress_if[EAST ].is_allocatable;
            default: return '0;
        endcase
    endfunction

    task automatic set_ingress_data(port_t port_sel, flit_t value);
        unique case (port_sel)
            LOCAL: ingress_if[LOCAL].data = value;
            NORTH: ingress_if[NORTH].data = value;
            SOUTH: ingress_if[SOUTH].data = value;
            WEST : ingress_if[WEST ].data = value;
            EAST : ingress_if[EAST ].data = value;
            default: ;
        endcase
    endtask

    task automatic set_ingress_valid(port_t port_sel, logic value);
        unique case (port_sel)
            LOCAL: ingress_if[LOCAL].is_valid = value;
            NORTH: ingress_if[NORTH].is_valid = value;
            SOUTH: ingress_if[SOUTH].is_valid = value;
            WEST : ingress_if[WEST ].is_valid = value;
            EAST : ingress_if[EAST ].is_valid = value;
            default: ;
        endcase
    endtask

endinterface


//==================================================================
// nocrouter_adapter_pkg.sv - Adapter for NoCRouter benchmark
//==================================================================
package nocrouter_adapter_pkg;

  import uvm_pkg::*;
  import noc_bench_core_pkg::*;
  import router_uvm_pkg::*;
  import noc_params::*;

  `include "uvm_macros.svh"

  class nocrouter_bench_base extends noc_bench_base_test;
    `uvm_component_utils(nocrouter_bench_base)

    virtual router_tb_if vif;
    
    // Router coordinates
    int x_current;
    int y_current;

    // Use payload as key (cycle-based timestamps)
    longint unsigned t_send_by_key [int unsigned];
    bit last_payload_valid[PORT_NUM];
    logic [HEAD_PAYLOAD_SIZE-1:0] last_payload_by_port[PORT_NUM];

    // Track busy status of each VC
    bit vc_busy[PORT_NUM][VC_NUM];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual router_tb_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF","router_tb_if virtual interface missing")
      
      // Initialize coordinates
      x_current = MESH_SIZE_X/2;
      y_current = MESH_SIZE_Y/2;
      
      // ========== Force override base class settings ==========
      this.do_drain = 1'b0;             
      this.drain_timeout_cycles = 0;    
      // ======================================================
    endfunction

    virtual function string get_default_csv_path();
      return "router_results.csv";
    endfunction

    virtual function void adapter_exp_begin_hook(string tag);
      int i;
      t_send_by_key.delete();
      for (i = 0; i < PORT_NUM; i++) begin
        last_payload_valid[i] = 1'b0;
        last_payload_by_port[i] = '0;
        // Reset VC busy status at start of experiment
        for (int v = 0; v < VC_NUM; v++) begin
            vc_busy[i][v] = 0;
        end
      end
    endfunction

    task automatic wait_for_reset_release();
      wait(!vif.rst);
    endtask

    task automatic wait_cycles(int cycles);
      repeat (cycles) @(posedge vif.clk);
    endtask

    function automatic noc_bench_core_pkg::port_type_e to_core_port(port_t p);
      case (p)
        LOCAL: return noc_bench_core_pkg::PORT_LOCAL;
        NORTH: return noc_bench_core_pkg::PORT_NORTH;
        SOUTH: return noc_bench_core_pkg::PORT_SOUTH;
        WEST:  return noc_bench_core_pkg::PORT_WEST;
        EAST:  return noc_bench_core_pkg::PORT_EAST;
        default: return noc_bench_core_pkg::PORT_LOCAL;
      endcase
    endfunction

    function automatic port_t to_router_port(noc_bench_core_pkg::port_type_e p);
      case (p)
        noc_bench_core_pkg::PORT_LOCAL: return LOCAL;
        noc_bench_core_pkg::PORT_NORTH: return NORTH;
        noc_bench_core_pkg::PORT_SOUTH: return SOUTH;
        noc_bench_core_pkg::PORT_WEST:  return WEST;
        noc_bench_core_pkg::PORT_EAST:  return EAST;
        default:                        return LOCAL;
      endcase
    endfunction

    function bit all_links_idle();
      int p;
      bit idle;
      port_t port_sel;
      idle = 1'b1;
      for (p = 0; p < PORT_NUM; p++) begin
        port_sel = port_t'(p);
        if (vif.get_egress_valid(port_sel))
          idle = 1'b0;
        if (vif.get_ingress_valid(port_sel))
          idle = 1'b0;
      end
      return idle;
    endfunction

    task automatic drain_all(int quiet_cycles = 8, int max_wait_cycles = 1_000_000);
      int quiet = 0;
      int waited = 0;
      while (waited < max_wait_cycles) begin
        @(posedge vif.clk);
        waited++;
        if (all_links_idle())
          quiet++;
        else
          quiet = 0;
        if (quiet >= quiet_cycles) begin
          `uvm_info("DRAIN", $sformatf("Links idle after %0d cycles", waited), UVM_LOW)
          break;
        end
      end
      if (waited >= max_wait_cycles)
        `uvm_warning("DRAIN_TIMEOUT", $sformatf("drain_all timed out after %0d cycles", max_wait_cycles))
    endtask

    task automatic drain_until_empty_or_timeout(int unsigned timeout_cycles);
      int unsigned k = 0;
      while (k < timeout_cycles) begin
        @(posedge vif.clk);
        if (all_links_idle())
          break;
        k++;
      end
    endtask

    task automatic settle_links();
      int unsigned waited = 0;
      while (waited < 2048) begin
        if (all_links_idle())
          return;
        @(posedge vif.clk);
        waited++;
      end
    endtask

    virtual task drive_pattern(noc_bench_core_pkg::traffic_pattern_e pattern,
                               noc_bench_core_pkg::load_level_e      load,
                               int                                   pkts_per_stream);
      case (pattern)
        noc_bench_core_pkg::PATTERN_UNIFORM: begin
          fork
            drive_stream_on_port(noc_bench_core_pkg::PORT_EAST,  noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h1000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_LOCAL, noc_bench_core_pkg::PORT_SOUTH, pkts_per_stream, load, 16'h2000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_SOUTH, noc_bench_core_pkg::PORT_WEST,  pkts_per_stream, load, 16'h3000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_WEST,  noc_bench_core_pkg::PORT_NORTH, pkts_per_stream, load, 16'h4000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_EAST,  pkts_per_stream, load, 16'h5000);
          join
        end
        noc_bench_core_pkg::PATTERN_HOTSPOT: begin
          fork
            drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h6000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_SOUTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h7000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_EAST,  noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h8000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_WEST,  noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h9000);
          join
        end
        noc_bench_core_pkg::PATTERN_TRANSPOSE: begin
          fork
            drive_stream_on_port(noc_bench_core_pkg::PORT_EAST,  noc_bench_core_pkg::PORT_WEST,  pkts_per_stream, load, 16'hB000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_WEST,  noc_bench_core_pkg::PORT_EAST,  pkts_per_stream, load, 16'hC000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_SOUTH, pkts_per_stream, load, 16'hD000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_SOUTH, noc_bench_core_pkg::PORT_NORTH, pkts_per_stream, load, 16'hE000);
          join
        end
        default: ;
      endcase
    endtask

    virtual task drive_hotspot_subpattern(noc_bench_core_pkg::hotspot_pattern_e hotspot,
                                         noc_bench_core_pkg::load_level_e      load,
                                         int                                   pkts_per_stream);
      case (hotspot)
        noc_bench_core_pkg::HOTSPOT_1PORT: begin
          drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h6000);
        end
        noc_bench_core_pkg::HOTSPOT_2PORTS: begin
          fork
            drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h6000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_SOUTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h7000);
          join
        end
        noc_bench_core_pkg::HOTSPOT_3PORTS: begin
          fork
            drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h6000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_SOUTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h7000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_EAST,  noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h8000);
          join
        end
        default: begin  // HOTSPOT_4PORTS
          fork
            drive_stream_on_port(noc_bench_core_pkg::PORT_NORTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h6000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_SOUTH, noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h7000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_EAST,  noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h8000);
            drive_stream_on_port(noc_bench_core_pkg::PORT_WEST,  noc_bench_core_pkg::PORT_LOCAL, pkts_per_stream, load, 16'h9000);
          join
        end
      endcase
    endtask

    function void record_send(port_t dst_port, flit_t flit);
      int unsigned key;
      logic [HEAD_PAYLOAD_SIZE-1:0] payload;
      payload = flit.data.head_data.head_pl;
      key = router_uvm_pkg::make_payload_key(payload);
      note_send(to_core_port(dst_port));
      t_send_by_key[key] = cycle_count;
    endfunction

    function void record_recv(port_t egress_port, flit_t flit);
      int unsigned key;
      longint unsigned cycle0;
      logic [HEAD_PAYLOAD_SIZE-1:0] payload;
      payload = flit.data.head_data.head_pl;
      key = router_uvm_pkg::make_payload_key(payload);
      if (!t_send_by_key.exists(key)) begin
        `uvm_warning("UNMATCHED_RECV",
          $sformatf("Port %s received payload 0x%0h with no matching send record",
                    router_uvm_pkg::port_name(egress_port), payload))
        return;
      end
      cycle0 = t_send_by_key[key];
      note_recv(to_core_port(egress_port), cycle_count - cycle0);
      t_send_by_key.delete(key);
    endfunction

    virtual task start_output_monitors();
      fork
        // Cycle counter
        forever begin
          @(posedge vif.clk);
          cycle_count++;
        end
        monitor_egress(LOCAL);
        monitor_egress(NORTH);
        monitor_egress(SOUTH);
        monitor_egress(WEST);
        monitor_egress(EAST);
        // Monitor allocatable signals to release VCs
        monitor_allocatable(LOCAL);
        monitor_allocatable(NORTH);
        monitor_allocatable(SOUTH);
        monitor_allocatable(WEST);
        monitor_allocatable(EAST);
      join_none
    endtask

    // Task to monitor release of VCs
    task automatic monitor_allocatable(port_t port);
      int idx;
      logic [VC_NUM-1:0] alloc;
      idx = router_uvm_pkg::port2idx(port);
      forever begin
        @(posedge vif.clk);
        alloc = vif.get_ingress_allocatable(port);
        for (int i=0; i<VC_NUM; i++) begin
          if (alloc[i]) vc_busy[idx][i] = 0;
        end
      end
    endtask

    task automatic monitor_egress(port_t port);
      int idx;
      bit curr_valid;
      idx = router_uvm_pkg::port2idx(port);
      forever begin
        @(posedge vif.clk);
        curr_valid = vif.get_egress_valid(port);
        
        if (exp_active && curr_valid) begin
          flit_t flit;
          logic [HEAD_PAYLOAD_SIZE-1:0] payload;
          
          flit = vif.get_egress_data(port);
          if (flit.flit_label == HEAD || flit.flit_label == HEADTAIL) begin
            payload = flit.data.head_data.head_pl;
            // Payload deduplication: record only if different from last
            if (!last_payload_valid[idx] || payload != last_payload_by_port[idx]) begin
              last_payload_by_port[idx] = payload;
              last_payload_valid[idx] = 1'b1;
              record_recv(port, flit);
            end
          end
        end
      end
    endtask

    task automatic wait_vc_ready(port_t in_port, logic [VC_SIZE-1:0] vc_sel);
      int vc_idx = int'(vc_sel);
      int port_idx = router_uvm_pkg::port2idx(in_port);
      logic [VC_NUM-1:0] on_off_vec;
      
      wait_for_reset_release();
      forever begin
        if (should_stop_drivers())
          return;
          
        on_off_vec = vif.get_ingress_on_off(in_port);
        // Wait for BOTH buffer space (on_off) AND VC availability (!vc_busy)
        if (on_off_vec[vc_idx] && !vc_busy[port_idx][vc_idx]) begin
           vc_busy[port_idx][vc_idx] = 1; // Mark VC as busy
           return;
        end

        note_stall(to_core_port(in_port), 1);
          
        @(posedge vif.clk);
      end
    endtask

    virtual task drive_stream_on_port(noc_bench_core_pkg::port_type_e in_port,
                                      noc_bench_core_pkg::port_type_e dst_port,
                                      int          n_pkts,
                                      noc_bench_core_pkg::load_level_e load,
                                      int          payload_seed = 16'h1000);
      port_t in_port_router;
      port_t dst_port_router;
      int gap;
      int i;
      logic [DEST_ADDR_SIZE_X-1:0] x_dest;
      logic [DEST_ADDR_SIZE_Y-1:0] y_dest;
      flit_t flit;
      logic [VC_SIZE-1:0] vc_sel;
      logic [HEAD_PAYLOAD_SIZE-1:0] payload;
      
      in_port_router = to_router_port(in_port);
      dst_port_router = to_router_port(dst_port);
      gap = noc_bench_core_pkg::load2gap(load);
      
      router_uvm_pkg::dest_coords_from_port(dst_port_router,
                                            x_current,
                                            y_current,
                                            x_dest,
                                            y_dest);
                                            
      // Account for all scheduled packets upfront
      account_scheduled_packets(n_pkts);
      
      wait_for_reset_release();
      repeat (2) @(posedge vif.clk);
      
      driver_enter();
      for (i = 0; i < n_pkts; i++) begin
        if (should_stop_drivers())
          break;
        vc_sel  = i % VC_NUM;
        payload = payload_seed + i;
        
        if (i > 0) begin
          repeat (gap) begin
            @(posedge vif.clk);
            if (should_stop_drivers())
              break;
          end
          if (should_stop_drivers())
            break;
        end
        
        // Block until ready
        wait_vc_ready(in_port_router, vc_sel);
        if (should_stop_drivers())
          break;
        
        flit = '0;
        flit.flit_label             = HEADTAIL;
        flit.vc_id                  = vc_sel;
        flit.data.head_data.x_dest  = x_dest;
        flit.data.head_data.y_dest  = y_dest;
        flit.data.head_data.head_pl = payload;
        
        vif.set_ingress_data(in_port_router, flit);
        vif.set_ingress_valid(in_port_router, 1'b1);
        record_send(dst_port_router, flit);
        
        @(posedge vif.clk);
        vif.set_ingress_valid(in_port_router, 1'b0);
      end
      driver_exit();
    endtask

  endclass

  class router_functional_test extends noc_functional_test_base#(nocrouter_bench_base);
    `uvm_component_utils(router_functional_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class router_system_benchmark_test extends noc_system_benchmark_test_base#(nocrouter_bench_base);
    `uvm_component_utils(router_system_benchmark_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class router_hotspot_analysis_test extends noc_hotspot_analysis_test_base#(nocrouter_bench_base);
    `uvm_component_utils(router_hotspot_analysis_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class router_transfer_rate_test extends noc_transfer_rate_test_base#(nocrouter_bench_base);
    `uvm_component_utils(router_transfer_rate_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class router_all_in_one_test extends noc_all_in_one_test_base#(nocrouter_bench_base);
    `uvm_component_utils(router_all_in_one_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class router_simple_test extends noc_simple_test_base#(nocrouter_bench_base);
    `uvm_component_utils(router_simple_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

endpackage
