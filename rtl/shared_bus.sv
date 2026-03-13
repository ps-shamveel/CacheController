//==============================================================================
// Shared Bus
// Interconnect for address, command, and data channels
//==============================================================================

module shared_bus
  import mesi_types_pkg::*;
#(
  parameter int NUM_CORES_PARAM = NUM_CORES
)(
  input  logic                    clk,
  input  logic                    rst_n,
  
  //--------------------------------------------------------------------------
  // Core Interfaces
  //--------------------------------------------------------------------------
  input  bus_request_t            core_req     [NUM_CORES_PARAM],
  output logic                    core_grant   [NUM_CORES_PARAM],
  output bus_response_t           core_resp    [NUM_CORES_PARAM],
  
  //--------------------------------------------------------------------------
  // Snoop Interfaces
  //--------------------------------------------------------------------------
  output logic                    snoop_valid  [NUM_CORES_PARAM],
  output bus_trans_t              snoop_trans  [NUM_CORES_PARAM],
  output logic [ADDR_WIDTH-1:0]   snoop_addr   [NUM_CORES_PARAM],
  input  snoop_resp_t             snoop_resp   [NUM_CORES_PARAM],
  input  logic [DATA_WIDTH-1:0]   snoop_data   [NUM_CORES_PARAM],
  
  //--------------------------------------------------------------------------
  // Memory Interface
  //--------------------------------------------------------------------------
  output logic                    mem_req_valid,
  output logic                    mem_req_we,
  output logic [ADDR_WIDTH-1:0]   mem_req_addr,
  output logic [DATA_WIDTH-1:0]   mem_req_wdata,
  input  logic                    mem_resp_valid,
  input  logic [DATA_WIDTH-1:0]   mem_resp_rdata
);

  //--------------------------------------------------------------------------
  // Coherence Controller Instance
  //--------------------------------------------------------------------------
  coherence_controller #(
    .NUM_CORES_PARAM(NUM_CORES_PARAM)
  ) u_coherence_ctrl (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // Bus request/response
    .bus_req_in     (core_req),
    .bus_grant      (core_grant),
    .bus_resp       (core_resp),
    
    // Snoop interface
    .snoop_valid    (snoop_valid),
    .snoop_trans    (snoop_trans),
    .snoop_addr     (snoop_addr),
    .snoop_resp     (snoop_resp),
    .snoop_data     (snoop_data),
    
    // Memory interface
    .mem_req_valid  (mem_req_valid),
    .mem_req_we     (mem_req_we),
    .mem_req_addr   (mem_req_addr),
    .mem_req_wdata  (mem_req_wdata),
    .mem_resp_valid (mem_resp_valid),
    .mem_resp_rdata (mem_resp_rdata)
  );

endmodule : shared_bus
