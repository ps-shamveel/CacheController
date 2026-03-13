//==============================================================================
// L1 Cache Controller
// Per-core L1 data cache with MESI coherence support
//==============================================================================

module l1_cache_controller
  import mesi_types_pkg::*;
#(
  parameter int CORE_ID = 0
)(
  input  logic                    clk,
  input  logic                    rst_n,
  
  //--------------------------------------------------------------------------
  // Processor Interface
  //--------------------------------------------------------------------------
  input  proc_request_t           proc_req,
  output proc_response_t          proc_resp,
  
  //--------------------------------------------------------------------------
  // Bus Interface (to Coherence Controller)
  //--------------------------------------------------------------------------
  output bus_request_t            bus_req,
  input  logic                    bus_grant,
  input  bus_response_t           bus_resp,
  
  //--------------------------------------------------------------------------
  // Snoop Interface (from Coherence Controller)
  //--------------------------------------------------------------------------
  input  logic                    snoop_valid,
  input  bus_trans_t              snoop_trans,
  input  logic [ADDR_WIDTH-1:0]   snoop_addr,
  output snoop_resp_t             snoop_resp,
  output logic [DATA_WIDTH-1:0]   snoop_data
);

  //--------------------------------------------------------------------------
  // Cache Storage - Direct Mapped
  //--------------------------------------------------------------------------
  mesi_state_t            cache_state [NUM_CACHE_LINES];
  logic [TAG_WIDTH-1:0]   cache_tag   [NUM_CACHE_LINES];
  logic [DATA_WIDTH-1:0]  cache_data  [NUM_CACHE_LINES];

  //--------------------------------------------------------------------------
  // FSM State
  //--------------------------------------------------------------------------
  l1_state_t state_r, state_next;
  
  //--------------------------------------------------------------------------
  // Internal Registers
  //--------------------------------------------------------------------------
  logic [ADDR_WIDTH-1:0]  req_addr_r;
  logic [DATA_WIDTH-1:0]  req_wdata_r;
  proc_req_t              req_type_r;
  logic [DATA_WIDTH-1:0]  wb_data_r;       // Data for write-back
  logic [TAG_WIDTH-1:0]   wb_tag_r;        // Tag for write-back address
  
  //--------------------------------------------------------------------------
  // Address Decomposition
  //--------------------------------------------------------------------------
  logic [TAG_WIDTH-1:0]   req_tag;
  logic [INDEX_WIDTH-1:0] req_index;
  
  assign req_tag   = get_tag(req_addr_r);
  assign req_index = get_index(req_addr_r);
  
  // Current line state
  mesi_state_t  cur_state;
  logic [TAG_WIDTH-1:0] cur_tag;
  logic [DATA_WIDTH-1:0] cur_data;
  logic tag_match;
  logic is_hit;
  
  assign cur_state = cache_state[req_index];
  assign cur_tag   = cache_tag[req_index];
  assign cur_data  = cache_data[req_index];
  assign tag_match = (cur_tag == req_tag);
  assign is_hit    = (cur_state != MESI_I) && tag_match;
  
  //--------------------------------------------------------------------------
  // Snoop Address Decomposition
  //--------------------------------------------------------------------------
  logic [TAG_WIDTH-1:0]   snoop_tag;
  logic [INDEX_WIDTH-1:0] snoop_index;
  mesi_state_t            snoop_line_state;
  logic [TAG_WIDTH-1:0]   snoop_line_tag;
  logic                   snoop_hit;
  
  assign snoop_tag   = get_tag(snoop_addr);
  assign snoop_index = get_index(snoop_addr);
  assign snoop_line_state = cache_state[snoop_index];
  assign snoop_line_tag   = cache_tag[snoop_index];
  assign snoop_hit  = (snoop_line_state != MESI_I) && (snoop_line_tag == snoop_tag);
  
  //--------------------------------------------------------------------------
  // Snoop Response Logic
  //--------------------------------------------------------------------------
  always_comb begin
    snoop_resp = SNOOP_NONE;
    snoop_data = '0;
    
    if (snoop_valid && snoop_hit) begin
      if (snoop_line_state == MESI_M) begin
        snoop_resp = SNOOP_HITM;
        snoop_data = cache_data[snoop_index];
      end else begin
        snoop_resp = SNOOP_HIT;
        snoop_data = cache_data[snoop_index];
      end
    end
  end
  
  //--------------------------------------------------------------------------
  // FSM Next State Logic
  //--------------------------------------------------------------------------
  always_comb begin
    state_next = state_r;
    
    case (state_r)
      L1_IDLE: begin
        if (proc_req.valid) begin
          state_next = L1_TAG_CHECK;
        end
      end
      
      L1_TAG_CHECK: begin
        if (is_hit) begin
          // Hit - check if we can complete immediately
          if (req_type_r == PROC_READ) begin
            state_next = L1_IDLE;
          end else begin // PROC_WRITE
            if (cur_state == MESI_M || cur_state == MESI_E) begin
              state_next = L1_IDLE;  // Can write directly
            end else begin // MESI_S - need upgrade
              state_next = L1_BUS_REQ;
            end
          end
        end else begin
          // Miss
          if (cur_state == MESI_M) begin
            // Need to write back dirty line first
            state_next = L1_WRITEBACK;
          end else begin
            state_next = L1_BUS_REQ;
          end
        end
      end
      
      L1_WRITEBACK: begin
        if (bus_grant) begin
          state_next = L1_BUS_REQ;
        end
      end
      
      L1_BUS_REQ: begin
        if (bus_grant) begin
          state_next = L1_WAIT_BUS;
        end
      end
      
      L1_WAIT_BUS: begin
        if (bus_resp.valid) begin
          state_next = L1_UPDATE;
        end
      end
      
      L1_UPDATE: begin
        state_next = L1_IDLE;
      end
      
      default: state_next = L1_IDLE;
    endcase
  end
  
  //--------------------------------------------------------------------------
  // FSM Sequential Logic
  //--------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r    <= L1_IDLE;
      req_addr_r <= '0;
      req_wdata_r <= '0;
      req_type_r <= PROC_NONE;
      wb_data_r  <= '0;
      wb_tag_r   <= '0;
    end else begin
      state_r <= state_next;
      
      // Capture request on valid
      if (state_r == L1_IDLE && proc_req.valid) begin
        req_addr_r  <= proc_req.addr;
        req_wdata_r <= proc_req.wdata;
        req_type_r  <= proc_req.req_type;
      end
      
      // Save write-back data before miss
      if (state_r == L1_TAG_CHECK && !is_hit && cur_state == MESI_M) begin
        wb_data_r <= cur_data;
        wb_tag_r  <= cur_tag;
      end
    end
  end
  
  //--------------------------------------------------------------------------
  // Cache Update Logic  
  //--------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_CACHE_LINES; i++) begin
        cache_state[i] <= MESI_I;
        cache_tag[i]   <= '0;
        cache_data[i]  <= '0;
      end
    end else begin
      // Snoop-induced state changes (highest priority)
      if (snoop_valid && snoop_hit) begin
        case (snoop_trans)
          BUS_RD: begin
            // Another core reading - downgrade to S if E/M
            if (snoop_line_state == MESI_M || snoop_line_state == MESI_E) begin
              cache_state[snoop_index] <= MESI_S;
            end
          end
          BUS_RDX, BUS_UPGR: begin
            // Another core wants exclusive - invalidate
            cache_state[snoop_index] <= MESI_I;
          end
          default: ;
        endcase
      end
      
      // Local cache updates
      case (state_r)
        L1_TAG_CHECK: begin
          if (is_hit && req_type_r == PROC_WRITE) begin
            if (cur_state == MESI_M || cur_state == MESI_E) begin
              // Write hit to M/E - update data, go to M
              cache_data[req_index]  <= req_wdata_r;
              cache_state[req_index] <= MESI_M;
            end
          end
        end
        
        L1_UPDATE: begin
          // Fill cache line after bus response
          cache_tag[req_index] <= req_tag;
          
          if (req_type_r == PROC_READ) begin
            cache_data[req_index] <= bus_resp.data;
            cache_state[req_index] <= bus_resp.shared ? MESI_S : MESI_E;
          end else begin // PROC_WRITE
            if (is_hit && cur_state == MESI_S) begin
              // Upgrade from S to M
              cache_data[req_index]  <= req_wdata_r;
              cache_state[req_index] <= MESI_M;
            end else begin
              // Write miss - get line then write
              cache_data[req_index]  <= req_wdata_r;
              cache_state[req_index] <= MESI_M;
            end
          end
        end
        
        default: ;
      endcase
    end
  end
  
  //--------------------------------------------------------------------------
  // Bus Request Output
  //--------------------------------------------------------------------------
  always_comb begin
    bus_req = '0;
    
    case (state_r)
      L1_WRITEBACK: begin
        bus_req.valid      = 1'b1;
        bus_req.core_id    = CORE_ID[$clog2(NUM_CORES)-1:0];
        bus_req.trans_type = BUS_WB;
        bus_req.addr       = make_addr(wb_tag_r, req_index);
        bus_req.data       = wb_data_r;
      end
      
      L1_BUS_REQ: begin
        bus_req.valid   = 1'b1;
        bus_req.core_id = CORE_ID[$clog2(NUM_CORES)-1:0];
        bus_req.addr    = req_addr_r;
        
        if (req_type_r == PROC_READ) begin
          bus_req.trans_type = BUS_RD;
        end else begin
          // Write request
          if (is_hit && cur_state == MESI_S) begin
            bus_req.trans_type = BUS_UPGR;  // Upgrade S->M
          end else begin
            bus_req.trans_type = BUS_RDX;   // Read exclusive
          end
        end
      end
      
      default: ;
    endcase
  end
  
  //--------------------------------------------------------------------------
  // Processor Response Output
  //--------------------------------------------------------------------------
  always_comb begin
    proc_resp = '0;
    
    // Ready when idle
    proc_resp.ready = (state_r == L1_IDLE);
    
    // Valid response on hit completion or after bus update
    if (state_r == L1_TAG_CHECK && is_hit) begin
      proc_resp.valid = 1'b1;
      proc_resp.rdata = cur_data;
    end else if (state_r == L1_UPDATE) begin
      proc_resp.valid = 1'b1;
      proc_resp.rdata = (req_type_r == PROC_READ) ? bus_resp.data : req_wdata_r;
    end
  end

endmodule : l1_cache_controller
