//==============================================================================
// MESI Assertions
// SystemVerilog assertions to verify MESI protocol invariants
//==============================================================================

module mesi_assertions
  import mesi_types_pkg::*;
#(
  parameter int NUM_CORES_PARAM = NUM_CORES
)(
  input logic clk,
  input logic rst_n,
  
  // Cache states from all cores (direct access for checking)
  input mesi_state_t cache_states [NUM_CORES_PARAM][NUM_CACHE_LINES],
  input logic [TAG_WIDTH-1:0] cache_tags [NUM_CORES_PARAM][NUM_CACHE_LINES]
);

  //--------------------------------------------------------------------------
  // Assertion: Only one cache may hold a line in Modified state
  //--------------------------------------------------------------------------
  // For each possible cache line address, at most one cache can have it in M
  
  genvar idx;
  generate
    for (idx = 0; idx < NUM_CACHE_LINES; idx++) begin : gen_m_check
      
      // Count how many caches have this index in M state with matching tag
      always @(posedge clk) begin
        if (rst_n) begin
          for (int tag = 0; tag < (1 << TAG_WIDTH); tag++) begin
            automatic int m_count = 0;
            for (int core = 0; core < NUM_CORES_PARAM; core++) begin
              if (cache_states[core][idx] == MESI_M && 
                  cache_tags[core][idx] == tag[TAG_WIDTH-1:0]) begin
                m_count++;
              end
            end
            // Use $error since iverilog may not support SVA fully
            if (m_count > 1) begin
              $error("MESI VIOLATION: Multiple caches (%0d) in M state for index %0d, tag %0h",
                     m_count, idx, tag);
            end
          end
        end
      end
      
    end
  endgenerate
  
  //--------------------------------------------------------------------------
  // Assertion: E state implies exclusive ownership
  //--------------------------------------------------------------------------
  generate
    for (idx = 0; idx < NUM_CACHE_LINES; idx++) begin : gen_e_check
      
      always @(posedge clk) begin
        if (rst_n) begin
          for (int core = 0; core < NUM_CORES_PARAM; core++) begin
            if (cache_states[core][idx] == MESI_E) begin
              // No other cache should have this line valid
              for (int other = 0; other < NUM_CORES_PARAM; other++) begin
                if (other != core && 
                    cache_states[other][idx] != MESI_I &&
                    cache_tags[other][idx] == cache_tags[core][idx]) begin
                  $error("MESI VIOLATION: Core %0d in E state but core %0d also has valid copy at index %0d",
                         core, other, idx);
                end
              end
            end
          end
        end
      end
      
    end
  endgenerate
  
  //--------------------------------------------------------------------------
  // Assertion: M implies no other valid copies
  //--------------------------------------------------------------------------
  generate
    for (idx = 0; idx < NUM_CACHE_LINES; idx++) begin : gen_m_exclusive
      
      always @(posedge clk) begin
        if (rst_n) begin
          for (int core = 0; core < NUM_CORES_PARAM; core++) begin
            if (cache_states[core][idx] == MESI_M) begin
              for (int other = 0; other < NUM_CORES_PARAM; other++) begin
                if (other != core && 
                    cache_states[other][idx] != MESI_I &&
                    cache_tags[other][idx] == cache_tags[core][idx]) begin
                  $error("MESI VIOLATION: Core %0d in M state but core %0d also has valid copy at index %0d",
                         core, other, idx);
                end
              end
            end
          end
        end
      end
      
    end
  endgenerate

endmodule : mesi_assertions
