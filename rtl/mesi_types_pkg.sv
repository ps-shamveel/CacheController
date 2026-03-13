//==============================================================================
// MESI Cache Coherence Types Package
// Defines all types, parameters, and constants for the MESI protocol
//==============================================================================

package mesi_types_pkg;

  //----------------------------------------------------------------------------
  // System Parameters
  //----------------------------------------------------------------------------
  parameter int NUM_CORES       = 4;           // Number of processor cores
  parameter int ADDR_WIDTH      = 32;          // Address width in bits
  parameter int CACHE_LINE_SIZE = 64;          // Cache line size in bytes
  parameter int DATA_WIDTH      = 512;         // Data width (64 bytes = 512 bits)
  
  // Cache organization (Direct-mapped)
  parameter int NUM_CACHE_LINES = 256;         // Number of cache lines per cache
  parameter int INDEX_WIDTH     = $clog2(NUM_CACHE_LINES);  // 8 bits for 256 lines
  parameter int OFFSET_WIDTH    = $clog2(CACHE_LINE_SIZE);  // 6 bits for 64 bytes
  parameter int TAG_WIDTH       = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;  // 18 bits
  
  // Timing parameters
  parameter int MEM_LATENCY     = 10;          // Memory access latency in cycles
  
  //----------------------------------------------------------------------------
  // MESI States
  //----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    MESI_I = 2'b00,  // Invalid
    MESI_S = 2'b01,  // Shared
    MESI_E = 2'b10,  // Exclusive
    MESI_M = 2'b11   // Modified
  } mesi_state_t;
  
  //----------------------------------------------------------------------------
  // Bus Transaction Types
  //----------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BUS_NONE  = 3'b000,  // No transaction
    BUS_RD    = 3'b001,  // Read miss request
    BUS_RDX   = 3'b010,  // Read-for-ownership (write miss)
    BUS_UPGR  = 3'b011,  // Upgrade shared to modified
    BUS_WB    = 3'b100   // Write-back to memory
  } bus_trans_t;
  
  //----------------------------------------------------------------------------
  // Processor Request Types
  //----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    PROC_NONE  = 2'b00,  // No request
    PROC_READ  = 2'b01,  // Processor read
    PROC_WRITE = 2'b10   // Processor write
  } proc_req_t;
  
  //----------------------------------------------------------------------------
  // L1 Cache Controller States
  //----------------------------------------------------------------------------
  typedef enum logic [2:0] {
    L1_IDLE       = 3'b000,  // Waiting for processor request
    L1_TAG_CHECK  = 3'b001,  // Checking tag for hit/miss
    L1_BUS_REQ    = 3'b010,  // Requesting bus access
    L1_WAIT_BUS   = 3'b011,  // Waiting for bus transaction
    L1_WRITEBACK  = 3'b100,  // Writing back dirty line
    L1_UPDATE     = 3'b101   // Updating cache line
  } l1_state_t;
  
  //----------------------------------------------------------------------------
  // Snoop Response Types
  //----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    SNOOP_NONE    = 2'b00,  // No response (line not present)
    SNOOP_HIT     = 2'b01,  // Line present (shared)
    SNOOP_HITM    = 2'b10   // Line present and modified
  } snoop_resp_t;
  
  //----------------------------------------------------------------------------
  // Cache Line Structure
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic                   valid;
    mesi_state_t            state;
    logic [TAG_WIDTH-1:0]   tag;
    logic [DATA_WIDTH-1:0]  data;
  } cache_line_t;
  
  //----------------------------------------------------------------------------
  // Bus Request Structure
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic                       valid;
    logic [$clog2(NUM_CORES)-1:0] core_id;
    bus_trans_t                 trans_type;
    logic [ADDR_WIDTH-1:0]      addr;
    logic [DATA_WIDTH-1:0]      data;  // For write-back
  } bus_request_t;
  
  //----------------------------------------------------------------------------
  // Bus Response Structure
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic                       valid;
    logic                       shared;      // Other caches have copy
    logic                       hitm;        // Hit to modified in other cache
    logic [DATA_WIDTH-1:0]      data;
  } bus_response_t;
  
  //----------------------------------------------------------------------------
  // Processor Interface
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic                       valid;
    proc_req_t                  req_type;
    logic [ADDR_WIDTH-1:0]      addr;
    logic [DATA_WIDTH-1:0]      wdata;       // Write data
  } proc_request_t;
  
  typedef struct packed {
    logic                       valid;
    logic                       ready;
    logic [DATA_WIDTH-1:0]      rdata;       // Read data
  } proc_response_t;
  
  //----------------------------------------------------------------------------
  // Address Decomposition Functions
  //----------------------------------------------------------------------------
  function automatic logic [TAG_WIDTH-1:0] get_tag(input logic [ADDR_WIDTH-1:0] addr);
    return addr[ADDR_WIDTH-1 : INDEX_WIDTH+OFFSET_WIDTH];
  endfunction
  
  function automatic logic [INDEX_WIDTH-1:0] get_index(input logic [ADDR_WIDTH-1:0] addr);
    return addr[INDEX_WIDTH+OFFSET_WIDTH-1 : OFFSET_WIDTH];
  endfunction
  
  function automatic logic [OFFSET_WIDTH-1:0] get_offset(input logic [ADDR_WIDTH-1:0] addr);
    return addr[OFFSET_WIDTH-1 : 0];
  endfunction
  
  function automatic logic [ADDR_WIDTH-1:0] make_addr(
    input logic [TAG_WIDTH-1:0]   tag,
    input logic [INDEX_WIDTH-1:0] index
  );
    return {tag, index, {OFFSET_WIDTH{1'b0}}};
  endfunction

endpackage : mesi_types_pkg
