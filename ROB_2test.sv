`timescale 1ns/100ps

module ROB_2_tb;

    parameter ROB_SIZE = 32;
    parameter PRF_SIZE = 64;
    parameter RF_SIZE  = 32;
    parameter WIDTH    = 2;
    parameter XLEN     = 32;

    logic clock, reset;
    logic [WIDTH-1:0] dispatch_en;
    logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] destreg;
    logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T_new, T_old;
    logic [WIDTH-1:0][XLEN-1:0] pc_in, targetpc_in;
    logic [WIDTH-1:0] is_branch_in, mispredict_in;
    logic [WIDTH-1:0] complete_en;
    logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] complete_tag;
    logic rollback_en;
    logic [$clog2(ROB_SIZE)-1:0] recover_head;

    logic [WIDTH-1:0][$clog2(ROB_SIZE)-1:0] rob_indices;
    logic [WIDTH-1:0] retire_valid;
    logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] retire_T, retire_T_old;
    logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] retire_arch;
    logic rollback_valid;
    logic [$clog2(PRF_SIZE)-1:0] rollback_tag;
    logic [$clog2(RF_SIZE)-1:0] rollback_rd;
    logic [XLEN-1:0] rollback_pc;

    ROB_2 #(
        .ROB_SIZE(ROB_SIZE), .PRF_SIZE(PRF_SIZE), .RF_SIZE(RF_SIZE),
        .WIDTH(WIDTH), .XLEN(XLEN)
    ) dut (
        .clock(clock), .reset(reset),
        .dispatch_en(dispatch_en),
        .destreg(destreg), .T_new(T_new), .T_old(T_old),
        .pc_in(pc_in), .targetpc_in(targetpc_in),
        .is_branch_in(is_branch_in), .mispredict_in(mispredict_in),
        .complete_en(complete_en), .complete_tag(complete_tag),
        .rollback_en(rollback_en), .recover_head(recover_head),
        .rob_indices(rob_indices), .retire_valid(retire_valid),
        .retire_T(retire_T), .retire_T_old(retire_T_old), .retire_arch(retire_arch),
        .rollback_valid(rollback_valid), .rollback_tag(rollback_tag),
        .rollback_rd(rollback_rd), .rollback_pc(rollback_pc)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Test procedure
    initial begin
        // Init
        reset = 1;
        dispatch_en = 0; complete_en = 0;
        rollback_en = 0;
        #10;

        // Release reset
        reset = 0;

        // Dispatch 2 instructions
        dispatch_en = 2'b11;
        destreg = {5'd6, 5'd5};  // x6, x5
        T_new = {6'd42, 6'd41};
        T_old = {6'd12, 6'd11};
        pc_in = {32'h00000010, 32'h00000008};
        targetpc_in = {32'h00000020, 32'h00000018};
        is_branch_in = 2'b01;
        mispredict_in = 2'b00;
        #10;

        // Dispatch ends
        dispatch_en = 2'b00;
        #10;

        // Mark instruction complete via CDB (only first)
        complete_en = 2'b01;
        complete_tag = {6'd0, 6'd41};  // Complete first one
        #10;

        // Complete second instruction
        complete_en = 2'b10;
        complete_tag = {6'd42, 6'd0};
        #10;

        complete_en = 2'b00;
        #10;

        // Retire happens automatically in ROB
        #20;

        // Dispatch one branch with mispredict
        dispatch_en = 2'b01;
        destreg[0] = 5'd7;
        T_new[0] = 6'd43;
        T_old[0] = 6'd13;
        pc_in[0] = 32'h00000030;
        targetpc_in[0] = 32'h00000040;
        is_branch_in[0] = 1;
        mispredict_in[0] = 1;
        #10;

        dispatch_en = 2'b00;
        #10;

        complete_en[0] = 1;
        complete_tag[0] = 6'd43;
        #10;

        complete_en = 0;
        #10;

        // Observe rollback
        #20;

        $display("Test completed");
        $finish;
    end

endmodule
