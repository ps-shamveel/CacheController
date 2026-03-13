//==============================================================================
// MESI System Top Level
// Integrates all components for multi-core cache coherent system
//==============================================================================

module mesi_system_top
  import mesi_types_pkg::*;
#(
  parameter int NUM_CORES_PARAM = NUM_CORES
)(
  input  logic                    clk,
  input  logic                    rst_n,
  
  //--------------------------------------------------------------------------
  // Processor Interfaces
  //--------------------------------------------------------------------------
  input  proc_request_t           proc_req   [NUM_CORES_PARAM],
  output proc_response_t          proc_resp  [NUM_CORES_PARAM]
);

  //--------------------------------------------------------------------------
  // Internal Signals
  //--------------------------------------------------------------------------
  
  // Bus request/response
  bus_request_t            bus_req_int    [NUM_CORES_PARAM];
  logic                    bus_grant_int  [NUM_CORES_PARAM];
  bus_response_t           bus_resp_int   [NUM_CORES_PARAM];
  
  // Snoop signals
  logic                    snoop_valid_int [NUM_CORES_PARAM];
  bus_trans_t              snoop_trans_int [NUM_CORES_PARAM];
  logic [ADDR_WIDTH-1:0]   snoop_addr_int  [NUM_CORES_PARAM];
  snoop_resp_t             snoop_resp_int  [NUM_CORES_PARAM];
  logic [DATA_WIDTH-1:0]   snoop_data_int  [NUM_CORES_PARAM];
  
  // Memory signals
  logic                    mem_req_valid;
  logic                    mem_req_we;
  logic [ADDR_WIDTH-1:0]   mem_req_addr;
  logic [DATA_WIDTH-1:0]   mem_req_wdata;
  logic                    mem_resp_valid;
  logic [DATA_WIDTH-1:0]   mem_resp_rdata;
  
  //--------------------------------------------------------------------------
  // L1 Cache Controllers
  //--------------------------------------------------------------------------
  generate
    for (genvar i = 0; i < NUM_CORES_PARAM; i++) begin : gen_l1_cache
      l1_cache_controller #(
        .CORE_ID(i)
      ) u_l1_cache (
        .clk          (clk),
        .rst_n        (rst_n),
        
        // Processor interface
        .proc_req     (proc_req[i]),
        .proc_resp    (proc_resp[i]),
        
        // Bus interface
        .bus_req      (bus_req_int[i]),
        .bus_grant    (bus_grant_int[i]),
        .bus_resp     (bus_resp_int[i]),
        
        // Snoop interface
        .snoop_valid  (snoop_valid_int[i]),
        .snoop_trans  (snoop_trans_int[i]),
        .snoop_addr   (snoop_addr_int[i]),
        .snoop_resp   (snoop_resp_int[i]),
        .snoop_data   (snoop_data_int[i])
      );
    end
  endgenerate
  
  //--------------------------------------------------------------------------
  // Shared Bus with Coherence Controller
  //--------------------------------------------------------------------------
  shared_bus #(
    .NUM_CORES_PARAM(NUM_CORES_PARAM)
  ) u_shared_bus (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Core interfaces
    .core_req       (bus_req_int),
    .core_grant     (bus_grant_int),
    .core_resp      (bus_resp_int),
    
    // Snoop interfaces
    .snoop_valid    (snoop_valid_int),
    .snoop_trans    (snoop_trans_int),
    .snoop_addr     (snoop_addr_int),
    .snoop_resp     (snoop_resp_int),
    .snoop_data     (snoop_data_int),
    
    // Memory interface
    .mem_req_valid  (mem_req_valid),
    .mem_req_we     (mem_req_we),
    .mem_req_addr   (mem_req_addr),
    .mem_req_wdata  (mem_req_wdata),
    .mem_resp_valid (mem_resp_valid),
    .mem_resp_rdata (mem_resp_rdata)
  );
  
  //--------------------------------------------------------------------------
  // Main Memory
  //--------------------------------------------------------------------------
  memory_model #(
    .MEM_SIZE(65536),
    .LATENCY(MEM_LATENCY)
  ) u_memory (
    .clk        (clk),
    .rst_n      (rst_n),
    .req_valid  (mem_req_valid),
    .req_we     (mem_req_we),
    .req_addr   (mem_req_addr),
    .req_wdata  (mem_req_wdata),
    .resp_valid (mem_resp_valid),
    .resp_rdata (mem_resp_rdata)
  );

endmodule : mesi_system_top
