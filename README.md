# NoC Router Benchmarking Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

## Overview

This project provides a systematic UVM verification framework for evaluating and comparing the performance of NoC routers. The framework features a router-agnostic core design that supports different routers through an adapter pattern, enabling unified test scenarios and metric collection.

### Key Features

- **Unified UVM Verification Architecture**: Built on SystemVerilog UVM methodology, providing reusable test infrastructure.
- **Router-agnostic**: Integrate routers to test by implementing a thin adapter layer. Currently, examples the routers found in [RANC](https://github.com/UA-RCL/RANC), [RaveNoC](https://github.com/aignacio/ravenoc) and [NoCRouter](https://github.com/agalimberti/NoCRouter) are provided.
- **Systematic Benchmarking**: Covers multiple metrics such as transfer rates, latencies and port stalling.
- **Evaluation Flow**: Tools and projects provided from simulation to result analysis.

## Project Structure

```
NoC-Router-Benchmarking-main/
│
├── framework/                          # Core verification framework
│   └── noc_bench_core_pkg.sv           # Router-agnostic UVM benchmark core package
│
├── routers/                            # Router sources and adapters
│   ├── ranc/                           # RANC Router
│   │   ├── src/                        # RANC router RTL sources (Git submodule)
│   │   └── ranc_adapter.sv             # RANC-specific adapter
│   │
│   ├── nocrouter/                      # NoCRouter
│   │   ├── src/                        # NoCRouter RTL sources (Git submodule)
│   │   └── nocrouter_adapter.sv        # NoCRouter-specific adapter
│   │
│   └── ravenoc/                        # RaveNoC Router
│       ├── src/                        # RaveNoC RTL sources (Git submodule)
│       ├── ravenoc_adapter.sv          # RaveNoC-specific adapter
│       └── apply-patch.sh              # Script to apply compatibility patch
│
├── testbenches/                        # Top-level testbenches for each router
│   ├── ranc/
│   │   └── ranc_testbench.sv           # RANC testbench
│   │
│   ├── nocrouter/
│   │   └── nocrouter_testbench.sv      # NoCRouter testbench
│   │
│   └── ravenoc/
│       └── ravenoc_testbench.sv        # RaveNoC testbench
│
├── projects/                           # Vivado project files
│   ├── benchmark_ranc/
│   │   └── benchmark_ranc.xpr          # RANC router Vivado project
│   ├── benchmark_nocrouter/
│   │   └── benchmark_nocrouter.xpr     # NoCRouter Vivado project
│   └── benchmark_ravenoc/
│       └── benchmark_ravenoc.xpr       # RaveNoC Vivado project
│
├── evaluation/                         # Evaluation results and analysis tools
│   ├── ranc_results.csv                # RANC test results data
│   ├── nocrouter_results.csv           # NoCRouter test results data
│   ├── ravenoc_results.csv             # RaveNoC test results data
│   ├── plots.py                        # Python plotting script
│   └── combined_results.png            # Generated comprehensive comparison charts
│
├── patches/                            # Source code compatibility patches
│   └── ravenoc.patch                   # RaveNoC router patch
│                                       # - Mesh size configuration (2x2→3x3)
│                                       # - Signal type compatibility fixes
│
├── LICENSE.md                          # MIT Open Source License
└── README.md                           # This document
```

## Current Test Scenarios

The framework implements four major categories of benchmark tests.

### 1. Functional Test
- **Purpose**: Verify basic router functionality
- **Scenario**: Uniform traffic pattern under light load
- **Packet Count**: 100 packets per stream

### 2. Transfer Rate Test
- **Purpose**: Measure point-to-point transfer performance between all port pairs
- **Test Paths**:
  - LOCAL → NORTH/EAST/SOUTH/WEST
  - NORTH → LOCAL/EAST/SOUTH/WEST
  - SOUTH → LOCAL/NORTH/EAST/WEST
  - EAST → LOCAL/NORTH/SOUTH/WEST
  - WEST → LOCAL/NORTH/SOUTH/EAST
- **Load**: Saturated (injection every cycle)
- **Packet Count**: 100 packets per path

### 3. System Benchmark Test

#### Traffic Patterns
1. **Uniform**: Simulates random connection patterns in neural networks
   - EAST → LOCAL
   - LOCAL → SOUTH
   - SOUTH → WEST
   - WEST → NORTH
   - NORTH → EAST

2. **Hotspot**: Simulates concentrated processing unit scenarios
   - NORTH/SOUTH/EAST/WEST → LOCAL (4 input ports sending to LOCAL simultaneously)

3. **Transpose**: Simulates symmetric topology communication
   - EAST ↔ WEST
   - NORTH ↔ SOUTH

#### Load Levels
- **Light**: Inject one packet every 8 clock cycles
- **Medium**: Inject one packet every 4 clock cycles
- **Heavy**: Inject one packet every 2 clock cycles
- **Saturated**: Inject one packet every cycle

**Packet Count**: 500 packets per stream

### 4. Hotspot Analysis Test
**Number of Experiments**: 16 (4 hotspot degrees × 4 load levels)

#### Hotspot Degrees
- **Degree 1**: 1 port → LOCAL (NORTH → LOCAL)
- **Degree 2**: 2 ports → LOCAL (NORTH, SOUTH → LOCAL)
- **Degree 3**: 3 ports → LOCAL (NORTH, SOUTH, EAST → LOCAL)
- **Degree 4**: 4 ports → LOCAL (NORTH, SOUTH, EAST, WEST → LOCAL)

**Packet Count**: 100 packets per stream

## Main Performance Metrics

The framework collects the following key performance metrics:

| Metric | Description | Unit |
|--------|-------------|------|
| **Throughput** | Number of packets successfully received per clock cycle | packets/cycle |
| **Latency** | Average clock cycles from packet transmission to reception | cycles |
| **Loss Rate** | Percentage of packets that did not reach destination | % |
| **Stall Cycles** | Cumulative cycles each port waited due to backpressure | cycles |
| **Duration** | Total clock cycles from experiment start to end | cycles |

All metrics are broken down by destination port for multi-dimensional performance analysis.

## CSV Output Format

Each test experiment generates one CSV record line with the following fields:

| Field | Description |
|-------|-------------|
| `test` | Test class name |
| `tag` | Experiment tag (e.g., `benchmark_uniform_light`) |
| `start_cycles` | Experiment start clock cycle |
| `end_cycles` | Experiment end clock cycle |
| `duration_cycles` | Experiment duration in clock cycles |
| `scheduled_send` | Total number of packets scheduled to send |
| `send` | Actual number of packets sent |
| `recv` | Number of packets successfully received |
| `loss_percent` | Packet loss rate percentage |
| `throughput_packets_per_cycle` | Throughput |
| `avg_latency_cycles` | Average latency |
| `dest_local/east/west/north/south` | Packets sent to each destination port |
| `egress_local/east/west/north/south` | Packets received from each egress port |
| `stall_local/east/west/north/south` | Cumulative stall cycles for each source port |

## Related Projects

### Current Example Routers Under Test

- **RANC**: [Reconfigurable Architecture for Neuromorphic Computing](https://github.com/UA-RCL/RANC)
- **NoCRouter**: [NoCRouter - RTL Router Design in SystemVerilog](https://github.com/agalimberti/NoCRouter)
- **RaveNoC**: [RaveNoC - configurable Network-on-Chip](https://github.com/aignacio/ravenoc)

## Contributors

- Hanlin Shi
- Brian Pachideh
