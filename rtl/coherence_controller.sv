//==============================================================================
// Coherence Controller
// Centralized MESI coherence controller with bus snooping
//==============================================================================

module coherence_controller
  import mesi_types_pkg::*;
#(
  parameter int NUM_CORES_PARAM = NUM_CORES
)(
  input  logic                    clk,
  input  logic                    rst_n,
  
  //--------------------------------------------------------------------------
  // Bus Request Interface (from L1 Caches)
  //--------------------------------------------------------------------------
  input  bus_request_t            bus_req_in  [NUM_CORES_PARAM],
  output logic                    bus_grant   [NUM_CORES_PARAM],
  output bus_response_t           bus_resp    [NUM_CORES_PARAM],
  
  //--------------------------------------------------------------------------
  // Snoop Interface (to L1 Caches)
  //--------------------------------------------------------------------------
  output logic                    snoop_valid [NUM_CORES_PARAM],
  output bus_trans_t              snoop_trans [NUM_CORES_PARAM],
  output logic [ADDR_WIDTH-1:0]   snoop_addr  [NUM_CORES_PARAM],
  input  snoop_resp_t             snoop_resp  [NUM_CORES_PARAM],
  input  logic [DATA_WIDTH-1:0]   snoop_data  [NUM_CORES_PARAM],
  
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
  // Arbitration State
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    ARB_IDLE,
    ARB_SNOOP,
    ARB_WAIT_SNOOP,
    ARB_MEM_REQ,
    ARB_WAIT_MEM,
    ARB_RESPOND
  } arb_state_t;
  
  arb_state_t arb_state_r, arb_state_next;
  
  //--------------------------------------------------------------------------
  // Internal Registers
  //--------------------------------------------------------------------------
  logic [$clog2(NUM_CORES_PARAM)-1:0] granted_core_r;
  logic [$clog2(NUM_CORES_PARAM)-1:0] rr_priority_r;  // Round-robin priority
  bus_request_t                       active_req_r;
  logic [DATA_WIDTH-1:0]              resp_data_r;
  logic                               resp_shared_r;
  logic                               snoop_done_r;
  logic [1:0]                         snoop_wait_cnt_r;
  
  //--------------------------------------------------------------------------
  // Request Detection
  //--------------------------------------------------------------------------
  logic [NUM_CORES_PARAM-1:0] req_pending;
  logic any_req;
  logic [$clog2(NUM_CORES_PARAM)-1:0] selected_core;
  
  generate
    for (genvar i = 0; i < NUM_CORES_PARAM; i++) begin : gen_req_pending
      bus_request_t tmp_req;
      assign tmp_req = bus_req_in[i];
      assign req_pending[i] = tmp_req.valid;
    end
  endgenerate
  
  assign any_req = |req_pending;
  
  // Round-robin arbitration
  always_comb begin
    logic found;
    selected_core = '0;
    found = 1'b0;
    for (int i = 0; i < NUM_CORES_PARAM; i++) begin
      if (!found) begin
        if (req_pending[(rr_priority_r + i) % NUM_CORES_PARAM]) begin
          selected_core = ((rr_priority_r + i) % NUM_CORES_PARAM);
          found = 1'b1;
        end
      end
    end
  end
  
  //--------------------------------------------------------------------------
  // Snoop Result Aggregation
  //--------------------------------------------------------------------------
  logic any_snoop_hit;
  logic any_snoop_hitm;
  logic [DATA_WIDTH-1:0] hitm_data;
  logic [$clog2(NUM_CORES_PARAM)-1:0] hitm_core;
  
  always_comb begin
    any_snoop_hit  = 1'b0;
    any_snoop_hitm = 1'b0;
    hitm_data      = '0;
    hitm_core      = '0;
    
    for (int i = 0; i < NUM_CORES_PARAM; i++) begin
      if (i != granted_core_r) begin
        if (snoop_resp[i] == SNOOP_HIT) begin
          any_snoop_hit = 1'b1;
        end else if (snoop_resp[i] == SNOOP_HITM) begin
          any_snoop_hit  = 1'b1;
          any_snoop_hitm = 1'b1;
          hitm_data      = snoop_data[i];
          hitm_core      = i[$clog2(NUM_CORES_PARAM)-1:0];
        end
      end
    end
  end
  
  //--------------------------------------------------------------------------
  // FSM Next State Logic
  //--------------------------------------------------------------------------
  always_comb begin
    arb_state_next = arb_state_r;
    
    case (arb_state_r)
      ARB_IDLE: begin
        if (any_req) begin
          arb_state_next = ARB_SNOOP;
        end
      end
      
      ARB_SNOOP: begin
        arb_state_next = ARB_WAIT_SNOOP;
      end
      
      ARB_WAIT_SNOOP: begin
        if (snoop_done_r) begin
          if (active_req_r.trans_type == BUS_WB) begin
            // Write-back goes directly to memory
            arb_state_next = ARB_MEM_REQ;
          end else if (active_req_r.trans_type == BUS_UPGR) begin
            // Upgrade doesn't need memory
            arb_state_next = ARB_RESPOND;
          end else if (any_snoop_hitm) begin
            // Modified data from another cache - use it
            arb_state_next = ARB_RESPOND;
          end else begin
            // Need to go to memory
            arb_state_next = ARB_MEM_REQ;
          end
        end
      end
      
      ARB_MEM_REQ: begin
        arb_state_next = ARB_WAIT_MEM;
      end
      
      ARB_WAIT_MEM: begin
        if (mem_resp_valid) begin
          arb_state_next = ARB_RESPOND;
        end
      end
      
      ARB_RESPOND: begin
        arb_state_next = ARB_IDLE;
      end
      
      default: arb_state_next = ARB_IDLE;
    endcase
  end
  
  //--------------------------------------------------------------------------
  // FSM Sequential Logic
  //--------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arb_state_r     <= ARB_IDLE;
      granted_core_r  <= '0;
      rr_priority_r   <= '0;
      active_req_r    <= '0;
      resp_data_r     <= '0;
      resp_shared_r   <= 1'b0;
      snoop_done_r    <= 1'b0;
      snoop_wait_cnt_r <= '0;
    end else begin
      arb_state_r <= arb_state_next;
      
      case (arb_state_r)
        ARB_IDLE: begin
          if (any_req) begin
            granted_core_r <= selected_core;
            active_req_r   <= bus_req_in[selected_core];
            snoop_done_r   <= 1'b0;
            snoop_wait_cnt_r <= '0;
          end
        end
        
        ARB_SNOOP: begin
          snoop_wait_cnt_r <= 2'd1;
        end
        
        ARB_WAIT_SNOOP: begin
          // Wait a couple cycles for snoop responses
          if (snoop_wait_cnt_r < 2'd2) begin
            snoop_wait_cnt_r <= snoop_wait_cnt_r + 1'b1;
          end else begin
            snoop_done_r <= 1'b1;
            // Capture snoop results
            if (any_snoop_hitm) begin
              resp_data_r   <= hitm_data;
              resp_shared_r <= 1'b1;  // Was modified elsewhere, now shared
            end else begin
              resp_shared_r <= any_snoop_hit;
            end
          end
        end
        
        ARB_WAIT_MEM: begin
          if (mem_resp_valid) begin
            if (active_req_r.trans_type != BUS_WB) begin
              resp_data_r <= mem_resp_rdata;
            end
          end
        end
        
        ARB_RESPOND: begin
          // Update round-robin priority
          rr_priority_r <= (granted_core_r + 1) % NUM_CORES_PARAM;
        end
        
        default: ;
      endcase
    end
  end
  
  //--------------------------------------------------------------------------
  // Output Generation
  //--------------------------------------------------------------------------
  
  // Bus grants
  generate
    for (genvar i = 0; i < NUM_CORES_PARAM; i++) begin : gen_grants
      assign bus_grant[i] = (arb_state_r == ARB_RESPOND) && (granted_core_r == i);
    end
  endgenerate
  
  // Bus responses
  generate
    for (genvar i = 0; i < NUM_CORES_PARAM; i++) begin : gen_resp
      always_comb begin
        bus_response_t tmp_resp;
        tmp_resp = '0;
        if ((arb_state_r == ARB_RESPOND) && (granted_core_r == i)) begin
          tmp_resp.valid  = 1'b1;
          tmp_resp.data   = resp_data_r;
          tmp_resp.shared = resp_shared_r;
          tmp_resp.hitm   = any_snoop_hitm;
        end
        bus_resp[i] = tmp_resp;
      end
    end
  endgenerate
  
  // Snoop signals (broadcast to all caches except requester)
  generate
    for (genvar i = 0; i < NUM_CORES_PARAM; i++) begin : gen_snoop
      always_comb begin
        snoop_valid[i] = 1'b0;
        snoop_trans[i] = BUS_NONE;
        snoop_addr[i]  = '0;
        
        if ((arb_state_r == ARB_SNOOP || arb_state_r == ARB_WAIT_SNOOP) && 
            (i != granted_core_r)) begin
          snoop_valid[i] = 1'b1;
          snoop_trans[i] = active_req_r.trans_type;
          snoop_addr[i]  = active_req_r.addr;
        end
      end
    end
  endgenerate
  
  // Memory interface
  always_comb begin
    mem_req_valid = 1'b0;
    mem_req_we    = 1'b0;
    mem_req_addr  = '0;
    mem_req_wdata = '0;
    
    if (arb_state_r == ARB_MEM_REQ) begin
      mem_req_valid = 1'b1;
      mem_req_addr  = active_req_r.addr;
      
      if (active_req_r.trans_type == BUS_WB) begin
        mem_req_we    = 1'b1;
        mem_req_wdata = active_req_r.data;
      end
    end
  end

endmodule : coherence_controller
