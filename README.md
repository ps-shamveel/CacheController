# MESI Cache Coherence Controller

This project implements a hardware-based, snoop-driven MESI cache coherence controller designed for multicore systems (2-4 cores). It provides a complete RTL implementation in SystemVerilog, including L1 cache controllers, a centralized coherence controller, a shared bus interconnect, and a behavioral memory model.

## Overview

In a multicore system, maintaining data consistency across private caches is critical. This implementation utilizes the MESI (Modified, Exclusive, Shared, Invalid) protocol to ensure that all processors see a consistent view of memory. The system employs a snooping mechanism where each cache controller monitors bus transactions to update its local state accordingly.

## Directory Structure

*   `rtl/`: SystemVerilog source files for the coherence system.
    *   `mesi_types_pkg.sv`: Definitions for system-wide types, parameters, and constants.
    *   `cache_line.sv`: Storage module for individual cache lines.
    *   `l1_cache_controller.sv`: Finite State Machine (FSM) implementing the local MESI protocol logic.
    *   `coherence_controller.sv`: Centralized logic for managing bus requests and maintaining global coherence.
    *   `shared_bus.sv`: Interconnect module facilitating communication between cores and memory.
    *   `memory_model.sv`: Behavioral model for the main system memory.
    *   `mesi_system_top.sv`: Top-level integration of all system components.
    *   `mesi_system_wrapper.sv`: Interface wrapper for simplified integration.
*   `tb/`: Testbench and verification environment.
    *   `mesi_tb.sv`: Primary testbench for system-level verification.
    *   `mesi_assertions.sv`: SystemVerilog Assertions (SVA) to verify MESI invariant properties.
    *   `test_scenarios.sv`: Predefined test cases for directed verification.
*   `Cache.pdf`: Detailed design specification and architectural documentation.

## Key Features

*   **MESI Protocol Implementation**: Full support for Modified, Exclusive, Shared, and Invalid states.
*   **Scalable Architecture**: Parameterized design supporting 2 to 4 processor cores.
*   **Cache Policy**: Implements Write-back and Write-allocate policies.
*   **Memory Specifications**: 64-byte cache lines (512-bit data width) with 256 lines per direct-mapped cache.
*   **Bus Arbitration**: Centralized round-robin arbitration ensures fair access to the shared bus.
*   **Snooping Logic**: Integrated snooping logic for all cache-to-cache and cache-to-memory transactions.

## Technical Specifications

### MESI State Definitions

| State | Description |
| :--- | :--- |
| **Modified (M)** | The line is present only in the current cache and is "dirty" (different from memory). |
| **Exclusive (E)** | The line is present only in the current cache and is "clean" (matches memory). |
| **Shared (S)** | The line may be present in other caches and is "clean". |
| **Invalid (I)** | The line is not valid in the current cache. |

### Bus Transactions

| Transaction | Description |
| :--- | :--- |
| **BusRd** | Signals a read miss; the processor intends to read the data. |
| **BusRdX** | Signals a write miss (Read-for-Ownership); the processor intends to modify the data. |
| **BusUpgr** | Signals an upgrade from Shared to Modified state for an existing line. |
| **BusWB** | Indicates a write-back of modified data to main memory. |

## Verification Environment

The verification suite includes directed tests, random traffic generation, and stress tests to ensure protocol correctness under various contention scenarios.

### System Requirements

The implementation utilizes SystemVerilog-2012 features. For simulation, the following tools are recommended:
*   Cadence Xcelium
*   Synopsys VCS
*   Mentor Questa/ModelSim
*   Verilator (Version 4.0+ with `--language 1800-2017`)

### Running Simulations (Example: VCS)

```bash
vcs -full64 -sverilog +v2k \
    -timescale=1ns/1ps \
    rtl/*.sv tb/*.sv \
    -o sim/mesi_sim

./sim/mesi_sim
```

## License

This project is intended for educational and research purposes.
