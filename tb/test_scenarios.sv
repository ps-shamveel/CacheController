//==============================================================================
// Test Scenarios
// Directed test cases for MESI protocol verification
//==============================================================================

module test_scenarios;
  import mesi_types_pkg::*;

  //--------------------------------------------------------------------------
  // Test Scenario Descriptions
  //--------------------------------------------------------------------------
  // These are reference scenarios implemented in mesi_tb.sv
  // This file documents the expected behavior for each scenario
  
  /*
  ============================================================================
  SCENARIO 1: Read Miss - No Sharers
  ============================================================================
  Initial State: All caches have line in I state
  Action: Core 0 reads address A
  Expected:
    - BusRd issued
    - Data fetched from memory
    - Core 0 enters E state
    - No other caches affected
  
  ============================================================================
  SCENARIO 2: Read Miss - With Sharers
  ============================================================================
  Initial State: Core 0 has line in E or S state
  Action: Core 1 reads same address
  Expected:
    - BusRd issued
    - Snoop hit from Core 0
    - Core 0 transitions to S (if was E)
    - Core 1 enters S state
    - Data provided from Core 0 or memory
  
  ============================================================================
  SCENARIO 3: Read Miss - Modified Owner
  ============================================================================
  Initial State: Core 0 has line in M state
  Action: Core 1 reads same address
  Expected:
    - BusRd issued
    - Snoop HITM from Core 0
    - Core 0 provides dirty data
    - Core 0 transitions to S
    - Core 1 enters S state
    - Memory is NOT updated (optimization)
  
  ============================================================================
  SCENARIO 4: Write Miss - No Sharers
  ============================================================================
  Initial State: All caches have line in I state
  Action: Core 0 writes address A
  Expected:
    - BusRdX issued
    - Data fetched from memory
    - Core 0 enters M state
    - No other caches affected
  
  ============================================================================
  SCENARIO 5: Write Miss - With Sharers
  ============================================================================
  Initial State: Cores 0, 1 have line in S state
  Action: Core 2 writes same address
  Expected:
    - BusRdX issued
    - Snoop hit from Cores 0, 1
    - Cores 0, 1 transition to I (invalidated)
    - Core 2 enters M state
  
  ============================================================================
  SCENARIO 6: Upgrade (S -> M)
  ============================================================================
  Initial State: Core 0 has line in S state, Core 1 also S
  Action: Core 0 writes to the line
  Expected:
    - BusUpgr issued (no data transfer)
    - Core 1 transitions to I
    - Core 0 enters M state
  
  ============================================================================
  SCENARIO 7: Write to E State Line
  ============================================================================
  Initial State: Core 0 has line in E state
  Action: Core 0 writes to the line
  Expected:
    - NO bus transaction (silent upgrade)
    - Core 0 transitions E -> M
  
  ============================================================================
  SCENARIO 8: Write-back on Eviction
  ============================================================================
  Initial State: Core 0 has line A in M state, cache is full
  Action: Core 0 reads address B that maps to same index
  Expected:
    - BusWB issued for line A
    - Data written to memory
    - Line A evicted
    - BusRd issued for line B
    - Line B loaded in E (or S)
  
  ============================================================================
  SCENARIO 9: Multiple Readers
  ============================================================================
  Initial State: Line in memory only
  Action: Cores 0, 1, 2, 3 all read same address (sequentially)
  Expected:
    - Core 0 gets E
    - After Core 1 reads: Cores 0, 1 in S
    - After Core 2 reads: Cores 0, 1, 2 in S
    - After Core 3 reads: All in S
  
  ============================================================================
  SCENARIO 10: Ping-Pong Writes
  ============================================================================
  Initial State: Line in Core 0 in M state
  Action: Cores 0 and 1 alternate writing to same line
  Expected:
    - Each write invalidates other core
    - Ownership bounces between cores
    - Each core gets M, other gets I
    - Verify no deadlock occurs
  
  ============================================================================
  */

endmodule : test_scenarios
