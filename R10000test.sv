`timescale 1ns/1ps

module ROB10000_tb;

  // Constants
  parameter ENTRY_NUM = 32;
  parameter REG_WIDTH = 5;
  parameter PHY_REG_WIDTH = 6;
  parameter XLEN = 32;
  parameter WIDTH = 2;

  // Clock and reset
  logic clock = 0;
  logic reset;

  // Dispatch inputs
  logic [WIDTH-1:0] dispatch_valid;
  logic [WIDTH-1:0][REG_WIDTH-1:0] dest_logical;
  logic [WIDTH-1:0][PHY_REG_WIDTH-1:0] dest_physical;
  logic [WIDTH-1:0][PHY_REG_WIDTH-1:0] old_physical;
  logic [WIDTH-1:0][XLEN-1:0] pc;
  logic [WIDTH-1:0] is_branch, is_store, is_load, is_halt, is_illegal;

  // Complete inputs
  logic [WIDTH-1:0] complete_valid;
  logic [WIDTH-1:0][PHY_REG_WIDTH-1:0] complete_tag;

  // Retire outputs
  logic [WIDTH-1:0] retire_valid;
  logic [WIDTH-1:0][REG_WIDTH-1:0] retire_logical;
  logic [WIDTH-1:0][PHY_REG_WIDTH-1:0] retire_physical;
  logic [WIDTH-1:0][PHY_REG_WIDTH-1:0] retire_old;

  // Instantiate DUT
  ROB10000 #(
    .ENTRY_NUM(ENTRY_NUM),
    .REG_WIDTH(REG_WIDTH),
    .PHY_REG_WIDTH(PHY_REG_WIDTH),
    .XLEN(XLEN),
    .WIDTH(WIDTH)
  ) dut (
    .clock(clock),
    .reset(reset),
    .dispatch_valid(dispatch_valid),
    .dest_logical(dest_logical),
    .dest_physical(dest_physical),
    .old_physical(old_physical),
    .pc(pc),
    .is_branch(is_branch),
    .is_store(is_store),
    .is_load(is_load),
    .is_halt(is_halt),
    .is_illegal(is_illegal),
    .complete_valid(complete_valid),
    .complete_tag(complete_tag),
    .retire_valid(retire_valid),
    .retire_logical(retire_logical),
    .retire_physical(retire_physical),
    .retire_old(retire_old)
  );

  // Clock generator
  always #5 clock = ~clock;

  initial begin
    // Reset
    reset = 1;
    dispatch_valid = 0;
    complete_valid = 0;
    #20;
    reset = 0;

    // Dispatch two instructions
    dispatch_valid = 2'b11;
    dest_logical[0] = 5'd1;
    dest_logical[1] = 5'd2;
    dest_physical[0] = 6'd10;
    dest_physical[1] = 6'd11;
    old_physical[0] = 6'd3;
    old_physical[1] = 6'd4;
    pc[0] = 32'h1000;
    pc[1] = 32'h1004;
    is_branch = 2'b00;
    is_store = 2'b00;
    is_load = 2'b00;
    is_halt = 2'b00;
    is_illegal = 2'b00;
    #10;

    // Disable dispatch
    dispatch_valid = 2'b00;
    #10;

    // Simulate CDB complete both
    complete_valid = 2'b11;
    complete_tag[0] = 6'd10;
    complete_tag[1] = 6'd11;
    #10;

    // Turn off complete signal
    complete_valid = 2'b00;
    #10;

    // Wait for retire
    repeat (3) begin
      #10;
      for (int i = 0; i < WIDTH; i++) begin
        if (retire_valid[i]) begin
          $display("RETIRE[%0d] -> logical: %0d, physical: %0d, old: %0d",
                   i, retire_logical[i], retire_physical[i], retire_old[i]);
        end
      end
    end

    $finish;
  end

endmodule
