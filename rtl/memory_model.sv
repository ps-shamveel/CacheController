//==============================================================================
// Memory Model
// Behavioral main memory with configurable latency
//==============================================================================

module memory_model
  import mesi_types_pkg::*;
#(
  parameter int MEM_SIZE   = 65536,  // Memory size in cache lines
  parameter int LATENCY    = MEM_LATENCY
)(
  input  logic                    clk,
  input  logic                    rst_n,
  
  //--------------------------------------------------------------------------
  // Memory Interface
  //--------------------------------------------------------------------------
  input  logic                    req_valid,
  input  logic                    req_we,
  input  logic [ADDR_WIDTH-1:0]   req_addr,
  input  logic [DATA_WIDTH-1:0]   req_wdata,
  output logic                    resp_valid,
  output logic [DATA_WIDTH-1:0]   resp_rdata
);

  //--------------------------------------------------------------------------
  // Memory Storage
  //--------------------------------------------------------------------------
  logic [DATA_WIDTH-1:0] mem [MEM_SIZE];
  
  //--------------------------------------------------------------------------
  // Address Translation
  //--------------------------------------------------------------------------
  logic [$clog2(MEM_SIZE)-1:0] mem_index;
  assign mem_index = req_addr[OFFSET_WIDTH +: $clog2(MEM_SIZE)];
  
  //--------------------------------------------------------------------------
  // Latency Counter
  //--------------------------------------------------------------------------
  logic [3:0] latency_cnt_r;
  logic       busy_r;
  logic       is_write_r;
  logic [DATA_WIDTH-1:0] rdata_r;
  
  //--------------------------------------------------------------------------
  // Sequential Logic
  //--------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      resp_valid    <= 1'b0;
      resp_rdata    <= '0;
      latency_cnt_r <= '0;
      busy_r        <= 1'b0;
      is_write_r    <= 1'b0;
      rdata_r       <= '0;
      
      // Initialize memory to zero
      for (int i = 0; i < MEM_SIZE; i++) begin
        mem[i] <= '0;
      end
    end else begin
      resp_valid <= 1'b0;
      
      if (!busy_r && req_valid) begin
        // Start new request
        busy_r        <= 1'b1;
        latency_cnt_r <= LATENCY - 1;
        is_write_r    <= req_we;
        
        if (req_we) begin
          // Write request
          mem[mem_index] <= req_wdata;
        end else begin
          // Read request
          rdata_r <= mem[mem_index];
        end
      end else if (busy_r) begin
        if (latency_cnt_r == 0) begin
          // Request complete
          busy_r     <= 1'b0;
          resp_valid <= 1'b1;
          
          if (!is_write_r) begin
            resp_rdata <= rdata_r;
          end
        end else begin
          latency_cnt_r <= latency_cnt_r - 1;
        end
      end
    end
  end

endmodule : memory_model
