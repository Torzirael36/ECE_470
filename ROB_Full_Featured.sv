
`timescale 1ns/100ps

module ROB_2 #(
    parameter ROB_SIZE = 32,
    parameter PRF_SIZE = 64,
    parameter RF_SIZE = 32,
    parameter WIDTH = 2,
    parameter XLEN = 32
)(
    input  logic                        clock,
    input  logic                        reset,
    input  logic [WIDTH-1:0]           dispatch_en,
    input  logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] destreg,
    input  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T_new,
    input  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T_old,
    input  logic [WIDTH-1:0][XLEN-1:0] pc_in,
    input  logic [WIDTH-1:0][XLEN-1:0] targetpc_in,
    input  logic [WIDTH-1:0]           is_branch_in,
    input  logic [WIDTH-1:0]           mispredict_in,

    input  logic [WIDTH-1:0]           complete_en,
    input  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] complete_tag,

    input  logic                       rollback_en,
    input  logic [$clog2(ROB_SIZE)-1:0] recover_head,

    output logic [WIDTH-1:0][$clog2(ROB_SIZE)-1:0] rob_indices,
    output logic [WIDTH-1:0]           retire_valid,
    output logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] retire_T,
    output logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] retire_T_old,
    output logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] retire_arch,

    output logic                       rollback_valid,
    output logic [$clog2(PRF_SIZE)-1:0] rollback_tag,
    output logic [$clog2(RF_SIZE)-1:0] rollback_rd,
    output logic [XLEN-1:0]            rollback_pc
);

    typedef struct packed {
        logic valid;
        logic complete;
        logic [$clog2(PRF_SIZE)-1:0] T;
        logic [$clog2(PRF_SIZE)-1:0] T_old;
        logic [$clog2(RF_SIZE)-1:0] rd;
        logic [XLEN-1:0] pc;
        logic [XLEN-1:0] targetpc;
        logic is_branch;
        logic mispredict;
    } ROBEntry;

    ROBEntry rob[ROB_SIZE];
    logic [$clog2(ROB_SIZE)-1:0] head, tail;
    logic [$clog2(ROB_SIZE):0] count;

    always_comb begin
        for (int i = 0; i < WIDTH; i++) begin
            rob_indices[i] = (tail + i) % ROB_SIZE;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < ROB_SIZE; i++) begin
                rob[i].valid <= 0;
                rob[i].complete <= 0;
            end
        end else begin
            for (int i = 0; i < WIDTH; i++) begin
                if (complete_en[i]) begin
                    for (int j = 0; j < ROB_SIZE; j++) begin
                        if (rob[j].valid && rob[j].T == complete_tag[i]) begin
                            rob[j].complete <= 1;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            tail <= 0;
            count <= 0;
        end else if (!rollback_en) begin
            for (int i = 0; i < WIDTH; i++) begin
                if (dispatch_en[i]) begin
                    rob[tail].valid      <= 1;
                    rob[tail].complete   <= 0;
                    rob[tail].T          <= T_new[i];
                    rob[tail].T_old      <= T_old[i];
                    rob[tail].rd         <= destreg[i];
                    rob[tail].pc         <= pc_in[i];
                    rob[tail].targetpc   <= targetpc_in[i];
                    rob[tail].is_branch  <= is_branch_in[i];
                    rob[tail].mispredict <= mispredict_in[i];
                    tail <= (tail + 1) % ROB_SIZE;
                    count <= count + 1;
                end
            end
        end
    end

    always_comb begin
        retire_valid   = 0;
        retire_T       = 0;
        retire_T_old   = 0;
        retire_arch    = 0;
        rollback_valid = 0;
        rollback_tag   = 0;
        rollback_rd    = 0;
        rollback_pc    = 0;

        for (int i = 0; i < WIDTH; i++) begin
            int idx = (head + i) % ROB_SIZE;
            if (rob[idx].valid && rob[idx].complete && count > 0) begin
                if (rob[idx].is_branch && rob[idx].mispredict) begin
                    rollback_valid = 1;
                    rollback_tag   = rob[idx].T_old;
                    rollback_rd    = rob[idx].rd;
                    rollback_pc    = rob[idx].targetpc;
                end else begin
                    retire_valid[i]   = 1;
                    retire_T[i]       = rob[idx].T;
                    retire_T_old[i]   = rob[idx].T_old;
                    retire_arch[i]    = rob[idx].rd;
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            head <= 0;
        end else if (rollback_en) begin
            tail <= recover_head;
            for (int i = 0; i < ROB_SIZE; i++) begin
                if (i != recover_head)
                    rob[i].valid <= 0;
            end
        end else begin
            for (int i = 0; i < WIDTH; i++) begin
                if (retire_valid[i]) begin
                    rob[head].valid <= 0;
                    head <= (head + 1) % ROB_SIZE;
                    count <= count - 1;
                end
            end
        end
    end

endmodule
