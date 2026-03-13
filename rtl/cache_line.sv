//==============================================================================
// Cache Line Module
// Single cache line storage with tag, data, and MESI state
//==============================================================================

module cache_line
  import mesi_types_pkg::*;
(
  input  logic                    clk,
  input  logic                    rst_n,
  
  // Write interface
  input  logic                    we,           // Write enable
  input  mesi_state_t             state_in,     // New MESI state
  input  logic [TAG_WIDTH-1:0]    tag_in,       // New tag
  input  logic [DATA_WIDTH-1:0]   data_in,      // New data
  
  // State-only update (for snoops)
  input  logic                    state_we,     // State-only write enable
  input  mesi_state_t             state_only_in,
  
  // Read interface
  output mesi_state_t             state_out,    // Current MESI state
  output logic [TAG_WIDTH-1:0]    tag_out,      // Current tag
  output logic [DATA_WIDTH-1:0]   data_out,     // Current data
  
  // Tag comparison
  input  logic [TAG_WIDTH-1:0]    tag_cmp,      // Tag to compare
  output logic                    tag_match,    // Tag match result
  output logic                    is_valid      // Line is valid (not Invalid state)
);

  //----------------------------------------------------------------------------
  // Storage
  //----------------------------------------------------------------------------
  mesi_state_t            state_r;
  logic [TAG_WIDTH-1:0]   tag_r;
  logic [DATA_WIDTH-1:0]  data_r;

  //----------------------------------------------------------------------------
  // Sequential Logic
  //----------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r <= MESI_I;
      tag_r   <= '0;
      data_r  <= '0;
    end else if (we) begin
      state_r <= state_in;
      tag_r   <= tag_in;
      data_r  <= data_in;
    end else if (state_we) begin
      state_r <= state_only_in;
    end
  end

  //----------------------------------------------------------------------------
  // Output Assignments
  //----------------------------------------------------------------------------
  assign state_out = state_r;
  assign tag_out   = tag_r;
  assign data_out  = data_r;
  
  // Tag comparison and validity
  assign tag_match = (tag_r == tag_cmp);
  assign is_valid  = (state_r != MESI_I);

endmodule : cache_line
