
`timescale 1ns/1ps

module ROB_tb;

    logic clock = 0;
    logic reset;

    logic dispatch_valid;
    logic [4:0] dest_logical;
    logic [5:0] dest_physical;
    logic [5:0] old_physical;
    logic [31:0] pc;

    logic complete_valid;
    logic [5:0] complete_tag;

    logic retire_valid;
    logic [4:0] retire_logical;
    logic [5:0] retire_physical;
    logic [5:0] retire_old;

    ROB dut (
        .clock(clock),
        .reset(reset),
        .dispatch_valid(dispatch_valid),
        .dest_logical(dest_logical),
        .dest_physical(dest_physical),
        .old_physical(old_physical),
        .pc(pc),
        .complete_valid(complete_valid),
        .complete_tag(complete_tag),
        .retire_valid(retire_valid),
        .retire_logical(retire_logical),
        .retire_physical(retire_physical),
        .retire_old(retire_old)
    );

    always #5 clock = ~clock;

    initial begin
        reset = 1;
        dispatch_valid = 0;
        complete_valid = 0;
        #10;
        reset = 0;

        // Dispatch one instruction
        dispatch_valid = 1;
        dest_logical = 5'd3;
        dest_physical = 6'd10;
        old_physical = 6'd5;
        pc = 32'h1000;
        #10;

        dispatch_valid = 0;
        #10;

        // Complete the instruction (simulate CDB)
        complete_valid = 1;
        complete_tag = 6'd10;
        #10;

        complete_valid = 0;
        #10;

        // Wait for retirement
        #20;

        if (retire_valid)
            $display("RETIRE: logical=%0d, physical=%0d, old=%0d", retire_logical, retire_physical, retire_old);
        else
            $display("NO RETIRE");

        $finish;
    end

endmodule
