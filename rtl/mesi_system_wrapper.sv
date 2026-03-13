//==============================================================================
// MESI System Wrapper
// Uses generate blocks to instantiate L1 caches with flattened signals
// Avoids struct arrays in testbench scope for iverilog compatibility
//==============================================================================

module mesi_system_wrapper
  import mesi_types_pkg::*;
(
  input  logic                    clk,
  input  logic                    rst_n,
  
  // Core 0 Interface
  input  logic                    proc_req_0_valid,
  input  logic [1:0]              proc_req_0_type,
  input  logic [ADDR_WIDTH-1:0]   proc_req_0_addr,
  input  logic [DATA_WIDTH-1:0]   proc_req_0_wdata,
  output logic                    proc_resp_0_valid,
  output logic                    proc_resp_0_ready,
  output logic [DATA_WIDTH-1:0]   proc_resp_0_rdata,
  
  // Core 1 Interface
  input  logic                    proc_req_1_valid,
  input  logic [1:0]              proc_req_1_type,
  input  logic [ADDR_WIDTH-1:0]   proc_req_1_addr,
  input  logic [DATA_WIDTH-1:0]   proc_req_1_wdata,
  output logic                    proc_resp_1_valid,
  output logic                    proc_resp_1_ready,
  output logic [DATA_WIDTH-1:0]   proc_resp_1_rdata,
  
  // Core 2 Interface
  input  logic                    proc_req_2_valid,
  input  logic [1:0]              proc_req_2_type,
  input  logic [ADDR_WIDTH-1:0]   proc_req_2_addr,
  input  logic [DATA_WIDTH-1:0]   proc_req_2_wdata,
  output logic                    proc_resp_2_valid,
  output logic                    proc_resp_2_ready,
  output logic [DATA_WIDTH-1:0]   proc_resp_2_rdata,
  
  // Core 3 Interface
  input  logic                    proc_req_3_valid,
  input  logic [1:0]              proc_req_3_type,
  input  logic [ADDR_WIDTH-1:0]   proc_req_3_addr,
  input  logic [DATA_WIDTH-1:0]   proc_req_3_wdata,
  output logic                    proc_resp_3_valid,
  output logic                    proc_resp_3_ready,
  output logic [DATA_WIDTH-1:0]   proc_resp_3_rdata
);

  localparam int NUM_CORES_W = 4;
  
  //--------------------------------------------------------------------------
  // Internal signals - NOT using struct arrays
  //--------------------------------------------------------------------------
  
  // Bus request signals per core
  logic                       bus_req_valid    [NUM_CORES_W];
  logic [1:0]                 bus_req_core_id  [NUM_CORES_W];
  logic [2:0]                 bus_req_trans    [NUM_CORES_W];
  logic [ADDR_WIDTH-1:0]      bus_req_addr     [NUM_CORES_W];
  logic [DATA_WIDTH-1:0]      bus_req_data     [NUM_CORES_W];
  
  // Bus response signals per core
  logic                       bus_grant        [NUM_CORES_W];
  logic                       bus_resp_valid   [NUM_CORES_W];
  logic                       bus_resp_shared  [NUM_CORES_W];
  logic                       bus_resp_hitm    [NUM_CORES_W];
  logic [DATA_WIDTH-1:0]      bus_resp_data    [NUM_CORES_W];
  
  // Snoop signals per core
  logic                       snoop_valid      [NUM_CORES_W];
  logic [2:0]                 snoop_trans      [NUM_CORES_W];
  logic [ADDR_WIDTH-1:0]      snoop_addr       [NUM_CORES_W];
  logic [1:0]                 snoop_resp       [NUM_CORES_W];
  logic [DATA_WIDTH-1:0]      snoop_data       [NUM_CORES_W];
  
  // Memory signals
  logic                       mem_req_valid;
  logic                       mem_req_we;
  logic [ADDR_WIDTH-1:0]      mem_req_addr;
  logic [DATA_WIDTH-1:0]      mem_req_wdata;
  logic                       mem_resp_valid;
  logic [DATA_WIDTH-1:0]      mem_resp_rdata;
  
  // Processor response signals per core (from L1)
  logic                       l1_resp_valid    [NUM_CORES_W];
  logic                       l1_resp_ready    [NUM_CORES_W];
  logic [DATA_WIDTH-1:0]      l1_resp_rdata    [NUM_CORES_W];

  //--------------------------------------------------------------------------
  // Struct conversion for L1 cache interfaces
  //--------------------------------------------------------------------------
  proc_request_t   proc_req_s  [NUM_CORES_W];
  proc_response_t  proc_resp_s [NUM_CORES_W];
  bus_request_t    bus_req_s   [NUM_CORES_W];
  bus_response_t   bus_resp_s  [NUM_CORES_W];
  
  // Core 0 request assembly (in always_ff to avoid combinational assign issues)
  always_ff @(posedge clk) begin
    proc_request_t req0, req1, req2, req3;
    
    req0.valid    = proc_req_0_valid;
    req0.req_type = (proc_req_0_type);
    req0.addr     = proc_req_0_addr;
    req0.wdata    = proc_req_0_wdata;
    proc_req_s[0] <= req0;
    
    req1.valid    = proc_req_1_valid;
    req1.req_type = (proc_req_1_type);
    req1.addr     = proc_req_1_addr;
    req1.wdata    = proc_req_1_wdata;
    proc_req_s[1] <= req1;
    
    req2.valid    = proc_req_2_valid;
    req2.req_type = (proc_req_2_type);
    req2.addr     = proc_req_2_addr;
    req2.wdata    = proc_req_2_wdata;
    proc_req_s[2] <= req2;
    
    req3.valid    = proc_req_3_valid;
    req3.req_type = (proc_req_3_type);
    req3.addr     = proc_req_3_addr;
    req3.wdata    = proc_req_3_wdata;
    proc_req_s[3] <= req3;
  end
  
  // Response outputs - using intermediate structs to avoid iverilog parse bug
  proc_response_t tmp_resp_0, tmp_resp_1, tmp_resp_2, tmp_resp_3;
  
  assign tmp_resp_0 = proc_resp_s[0];
  assign proc_resp_0_valid = tmp_resp_0.valid;
  assign proc_resp_0_ready = tmp_resp_0.ready;
  assign proc_resp_0_rdata = tmp_resp_0.rdata;
  
  assign tmp_resp_1 = proc_resp_s[1];
  assign proc_resp_1_valid = tmp_resp_1.valid;
  assign proc_resp_1_ready = tmp_resp_1.ready;
  assign proc_resp_1_rdata = tmp_resp_1.rdata;
  
  assign tmp_resp_2 = proc_resp_s[2];
  assign proc_resp_2_valid = tmp_resp_2.valid;
  assign proc_resp_2_ready = tmp_resp_2.ready;
  assign proc_resp_2_rdata = tmp_resp_2.rdata;
  
  assign tmp_resp_3 = proc_resp_s[3];
  assign proc_resp_3_valid = tmp_resp_3.valid;
  assign proc_resp_3_ready = tmp_resp_3.ready;
  assign proc_resp_3_rdata = tmp_resp_3.rdata;
  
  //--------------------------------------------------------------------------
  // DUT Instantiation
  //--------------------------------------------------------------------------
  mesi_system_top #(
    .NUM_CORES_PARAM(NUM_CORES_W)
  ) u_mesi_system (
    .clk       (clk),
    .rst_n     (rst_n),
    .proc_req  (proc_req_s),
    .proc_resp (proc_resp_s)
  );

endmodule : mesi_system_wrapper
