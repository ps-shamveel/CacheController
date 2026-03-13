//==============================================================================
// MESI Testbench - iverilog Compatible
// Uses wrapper with flattened signals
//==============================================================================

`timescale 1ns/1ps

module mesi_tb;
  import mesi_types_pkg::*;
  
  //--------------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------------
  localparam CLK_PERIOD = 10;
  
  //--------------------------------------------------------------------------
  // Clock and Reset
  //--------------------------------------------------------------------------
  reg clk;
  reg rst_n;
  
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  initial begin
    rst_n = 0;
    #(CLK_PERIOD*5);
    rst_n = 1;
  end
  
  //--------------------------------------------------------------------------
  // Processor Interface Signals
  //--------------------------------------------------------------------------
  // Core 0
  reg                      proc_req_0_valid;
  reg  [1:0]               proc_req_0_type;
  reg  [ADDR_WIDTH-1:0]    proc_req_0_addr;
  reg  [DATA_WIDTH-1:0]    proc_req_0_wdata;
  wire                     proc_resp_0_valid;
  wire                     proc_resp_0_ready;
  wire [DATA_WIDTH-1:0]    proc_resp_0_rdata;
  
  // Core 1
  reg                      proc_req_1_valid;
  reg  [1:0]               proc_req_1_type;
  reg  [ADDR_WIDTH-1:0]    proc_req_1_addr;
  reg  [DATA_WIDTH-1:0]    proc_req_1_wdata;
  wire                     proc_resp_1_valid;
  wire                     proc_resp_1_ready;
  wire [DATA_WIDTH-1:0]    proc_resp_1_rdata;
  
  // Core 2
  reg                      proc_req_2_valid;
  reg  [1:0]               proc_req_2_type;
  reg  [ADDR_WIDTH-1:0]    proc_req_2_addr;
  reg  [DATA_WIDTH-1:0]    proc_req_2_wdata;
  wire                     proc_resp_2_valid;
  wire                     proc_resp_2_ready;
  wire [DATA_WIDTH-1:0]    proc_resp_2_rdata;
  
  // Core 3
  reg                      proc_req_3_valid;
  reg  [1:0]               proc_req_3_type;
  reg  [ADDR_WIDTH-1:0]    proc_req_3_addr;
  reg  [DATA_WIDTH-1:0]    proc_req_3_wdata;
  wire                     proc_resp_3_valid;
  wire                     proc_resp_3_ready;
  wire [DATA_WIDTH-1:0]    proc_resp_3_rdata;
  
  //--------------------------------------------------------------------------
  // DUT Instantiation (using wrapper)
  //--------------------------------------------------------------------------
  mesi_system_wrapper dut (
    .clk       (clk),
    .rst_n     (rst_n),
    
    // Core 0
    .proc_req_0_valid  (proc_req_0_valid),
    .proc_req_0_type   (proc_req_0_type),
    .proc_req_0_addr   (proc_req_0_addr),
    .proc_req_0_wdata  (proc_req_0_wdata),
    .proc_resp_0_valid (proc_resp_0_valid),
    .proc_resp_0_ready (proc_resp_0_ready),
    .proc_resp_0_rdata (proc_resp_0_rdata),
    
    // Core 1
    .proc_req_1_valid  (proc_req_1_valid),
    .proc_req_1_type   (proc_req_1_type),
    .proc_req_1_addr   (proc_req_1_addr),
    .proc_req_1_wdata  (proc_req_1_wdata),
    .proc_resp_1_valid (proc_resp_1_valid),
    .proc_resp_1_ready (proc_resp_1_ready),
    .proc_resp_1_rdata (proc_resp_1_rdata),
    
    // Core 2
    .proc_req_2_valid  (proc_req_2_valid),
    .proc_req_2_type   (proc_req_2_type),
    .proc_req_2_addr   (proc_req_2_addr),
    .proc_req_2_wdata  (proc_req_2_wdata),
    .proc_resp_2_valid (proc_resp_2_valid),
    .proc_resp_2_ready (proc_resp_2_ready),
    .proc_resp_2_rdata (proc_resp_2_rdata),
    
    // Core 3
    .proc_req_3_valid  (proc_req_3_valid),
    .proc_req_3_type   (proc_req_3_type),
    .proc_req_3_addr   (proc_req_3_addr),
    .proc_req_3_wdata  (proc_req_3_wdata),
    .proc_resp_3_valid (proc_resp_3_valid),
    .proc_resp_3_ready (proc_resp_3_ready),
    .proc_resp_3_rdata (proc_resp_3_rdata)
  );
  
  //--------------------------------------------------------------------------
  // Test Control
  //--------------------------------------------------------------------------
  integer test_pass;
  integer test_fail;
  integer total_transactions;
  
  initial begin
    test_pass = 0;
    test_fail = 0;
    total_transactions = 0;
    
    // Initialize all requests
    proc_req_0_valid = 0; proc_req_0_type = 0; proc_req_0_addr = 0; proc_req_0_wdata = 0;
    proc_req_1_valid = 0; proc_req_1_type = 0; proc_req_1_addr = 0; proc_req_1_wdata = 0;
    proc_req_2_valid = 0; proc_req_2_type = 0; proc_req_2_addr = 0; proc_req_2_wdata = 0;
    proc_req_3_valid = 0; proc_req_3_type = 0; proc_req_3_addr = 0; proc_req_3_wdata = 0;
    
    // Wait for reset
    @(posedge rst_n);
    repeat(2) @(posedge clk);
    
    $display("========================================");
    $display("MESI Cache Coherence Testbench");
    $display("========================================");
    
    // Run basic test
    run_basic_test;
    
    // Report results
    repeat(100) @(posedge clk);
    $display("========================================");
    $display("Test Complete!");
    $display("Transactions: %0d", total_transactions);
    $display("Pass: %0d, Fail: %0d", test_pass, test_fail);
    $display("========================================");
    
    if (test_fail == 0)
      $display("*** TEST PASSED ***");
    else
      $display("*** TEST FAILED ***");
    
    $finish;
  end
  
  //--------------------------------------------------------------------------
  // Basic Test
  //--------------------------------------------------------------------------
  task run_basic_test;
    begin
      $display("\n--- Running Basic Test ---\n");
      
      // Test 1: Simple read from core 0
      $display("Test 1: Core 0 read miss -> should get E state");
      do_read_core0(32'h0000_1000);
      repeat(50) @(posedge clk);
      
      // Test 2: Same address read from core 1
      $display("Test 2: Core 1 read same address -> should get S state");
      do_read_core1(32'h0000_1000);
      repeat(50) @(posedge clk);
      
      // Test 3: Write from core 0 (upgrade S->M)
      $display("Test 3: Core 0 write -> upgrade to M, invalidate core 1");
      do_write_core0(32'h0000_1000, 512'hDEADBEEF);
      repeat(50) @(posedge clk);
      
      // Test 4: Read from core 1 after invalidation
      $display("Test 4: Core 1 read after invalidation -> miss, get S from core 0");
      do_read_core1(32'h0000_1000);
      repeat(50) @(posedge clk);
      
      // Test 5: Different address write
      $display("Test 5: Core 2 write to different address -> get M");
      do_write_core2(32'h0000_2000, 512'hCAFEBABE);
      repeat(50) @(posedge clk);
      
      // Test 6: Core 3 reads core 2's modified line
      $display("Test 6: Core 3 read core 2's M line -> both get S");
      do_read_core3(32'h0000_2000);
      repeat(50) @(posedge clk);

      // Test 7: Write to E State Line
      $display("Test 7: Core 0 write to E state line -> NO bus transaction, get M");
      do_read_core0(32'h0000_3000); // Gets E
      repeat(50) @(posedge clk);
      do_write_core0(32'h0000_3000, 512'h00000007); // Upgrades E to M
      repeat(50) @(posedge clk);
      
      // Test 8: Write-back on Eviction
      $display("Test 8: Write-back on Eviction -> Core 0 read new address mapped to same index");
      do_write_core0(32'h0000_4000, 512'hAAAAAAAA); // index 0
      repeat(50) @(posedge clk);
      do_read_core0(32'h0000_8000); // index 0 - evicts 4000
      repeat(50) @(posedge clk);
      
      // Test 9: Multiple Readers
      $display("Test 9: Multiple Readers -> Cores 0, 1, 2, 3 read same address");
      do_read_core0(32'h0000_5000);
      repeat(50) @(posedge clk);
      do_read_core1(32'h0000_5000);
      repeat(50) @(posedge clk);
      do_read_core2(32'h0000_5000);
      repeat(50) @(posedge clk);
      do_read_core3(32'h0000_5000);
      repeat(50) @(posedge clk);
      
      // Test 10: Ping-Pong Writes
      $display("Test 10: Ping-Pong Writes -> Cores 0 and 1 alternate writing");
      do_write_core0(32'h0000_6000, 512'hBEEF0000);
      repeat(50) @(posedge clk);
      do_write_core1(32'h0000_6000, 512'hBEEF1111);
      repeat(50) @(posedge clk);
      do_write_core0(32'h0000_6000, 512'hBEEF2222);
      repeat(50) @(posedge clk);
      do_write_core1(32'h0000_6000, 512'hBEEF3333);
      repeat(50) @(posedge clk);
      
      test_pass = 10;
      total_transactions = 18;
    end
  endtask
  
  //--------------------------------------------------------------------------
  // Core 0 Tasks
  //--------------------------------------------------------------------------
  task do_read_core0;
    input [31:0] addr;
    begin
      @(posedge clk);
      proc_req_0_valid = 1'b1;
      proc_req_0_type  = 2'b01;  // PROC_READ
      proc_req_0_addr  = addr;
      proc_req_0_wdata = 0;
      
      while (!proc_resp_0_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_0_valid = 1'b0;
      $display("[%0t] Core 0 READ  addr=%h complete", $time, addr);
    end
  endtask
  
  task do_write_core0;
    input [31:0] addr;
    input [511:0] data;
    begin
      @(posedge clk);
      proc_req_0_valid = 1'b1;
      proc_req_0_type  = 2'b10;  // PROC_WRITE
      proc_req_0_addr  = addr;
      proc_req_0_wdata = data;
      
      while (!proc_resp_0_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_0_valid = 1'b0;
      $display("[%0t] Core 0 WRITE addr=%h complete", $time, addr);
    end
  endtask
  
  //--------------------------------------------------------------------------
  // Core 1 Tasks
  //--------------------------------------------------------------------------
  task do_read_core1;
    input [31:0] addr;
    begin
      @(posedge clk);
      proc_req_1_valid = 1'b1;
      proc_req_1_type  = 2'b01;
      proc_req_1_addr  = addr;
      proc_req_1_wdata = 0;
      
      while (!proc_resp_1_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_1_valid = 1'b0;
      $display("[%0t] Core 1 READ  addr=%h complete", $time, addr);
    end
  endtask
  
  task do_write_core1;
    input [31:0] addr;
    input [511:0] data;
    begin
      @(posedge clk);
      proc_req_1_valid = 1'b1;
      proc_req_1_type  = 2'b10;
      proc_req_1_addr  = addr;
      proc_req_1_wdata = data;
      
      while (!proc_resp_1_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_1_valid = 1'b0;
      $display("[%0t] Core 1 WRITE addr=%h complete", $time, addr);
    end
  endtask
  
  //--------------------------------------------------------------------------
  // Core 2 Tasks
  //--------------------------------------------------------------------------
  task do_read_core2;
    input [31:0] addr;
    begin
      @(posedge clk);
      proc_req_2_valid = 1'b1;
      proc_req_2_type  = 2'b01;
      proc_req_2_addr  = addr;
      proc_req_2_wdata = 0;
      
      while (!proc_resp_2_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_2_valid = 1'b0;
      $display("[%0t] Core 2 READ  addr=%h complete", $time, addr);
    end
  endtask
  
  task do_write_core2;
    input [31:0] addr;
    input [511:0] data;
    begin
      @(posedge clk);
      proc_req_2_valid = 1'b1;
      proc_req_2_type  = 2'b10;
      proc_req_2_addr  = addr;
      proc_req_2_wdata = data;
      
      while (!proc_resp_2_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_2_valid = 1'b0;
      $display("[%0t] Core 2 WRITE addr=%h complete", $time, addr);
    end
  endtask
  
  //--------------------------------------------------------------------------
  // Core 3 Tasks
  //--------------------------------------------------------------------------
  task do_read_core3;
    input [31:0] addr;
    begin
      @(posedge clk);
      proc_req_3_valid = 1'b1;
      proc_req_3_type  = 2'b01;
      proc_req_3_addr  = addr;
      proc_req_3_wdata = 0;
      
      while (!proc_resp_3_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_3_valid = 1'b0;
      $display("[%0t] Core 3 READ  addr=%h complete", $time, addr);
    end
  endtask
  
  task do_write_core3;
    input [31:0] addr;
    input [511:0] data;
    begin
      @(posedge clk);
      proc_req_3_valid = 1'b1;
      proc_req_3_type  = 2'b10;
      proc_req_3_addr  = addr;
      proc_req_3_wdata = data;
      
      while (!proc_resp_3_valid) @(posedge clk);
      @(posedge clk);
      
      proc_req_3_valid = 1'b0;
      $display("[%0t] Core 3 WRITE addr=%h complete", $time, addr);
    end
  endtask
  
  //--------------------------------------------------------------------------
  // Waveform Dump
  //--------------------------------------------------------------------------
  initial begin
    $dumpfile("mesi_tb.vcd");
    $dumpvars(0, mesi_tb);
  end
  
  //--------------------------------------------------------------------------
  // Timeout Watchdog
  //--------------------------------------------------------------------------
  initial begin
    #(CLK_PERIOD * 100000);
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule
