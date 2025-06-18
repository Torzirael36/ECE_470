`timescale 1ns/100ps

module Maptable #(
    parameter WIDTH = 2,
    parameter RF_SIZE = 32,
    parameter PRF_SIZE = 64,
    parameter XLEN = 32,
    parameter ZERO_REG = 0
)(
    input logic reset,
    input logic clock,

    // From decoder
    input logic [WIDTH-1:0] write_en,
    input logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] destreg,

    // From RS
    input logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] reg1,
    input logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] reg2,

    // From Free List
    input logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T,

    // From CDB
    input logic [WIDTH-1:0] cdb_complete,
    input logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] cdb_tag,

    // From ROB (rollback and recovery)
    input logic [RF_SIZE-1:0][$clog2(PRF_SIZE)-1:0] rec_tag,
    input logic rollback_en,
    input logic [$clog2(RF_SIZE)-1:0] rollback_reg,
    input logic [$clog2(PRF_SIZE)-1:0] rollback_tag,
    input logic exception_en,

    // To ROB
    output logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T_hold,

    // To RS
    output logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] t1,
    output logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] t2,
    output logic [WIDTH-1:0] t1_ready,
    output logic [WIDTH-1:0] t2_ready
);

    typedef struct packed {
        logic [$clog2(PRF_SIZE)-1:0] tag;
        logic ready;
    } MaptableEntry;

    MaptableEntry entry[RF_SIZE];
    MaptableEntry nentry[RF_SIZE];

    // === Output: T_hold to ROB ===
    always_comb begin
        for (int i = 0; i < WIDTH; i++) begin
            if (write_en[i])
                T_hold[i] = (i > 0 && write_en[0] && destreg[i] == destreg[0]) ? T[0] : entry[destreg[i]].tag;
            else
                T_hold[i] = 0;
        end
    end

    // === Output: RS operands ===
    always_comb begin
        for (int i = 0; i < WIDTH; i++) begin
            // T1
            if (write_en[0] && reg1[i] == destreg[0])
                t1[i] = T[0];
            else if (write_en[1] && reg1[i] == destreg[1])
                t1[i] = T[1];
            else
                t1[i] = entry[reg1[i]].tag;

            // T1 Ready
            if (reg1[i] == ZERO_REG)
                t1_ready[i] = 1;
            else if ((cdb_complete[0] && cdb_tag[0] == t1[i]) || (cdb_complete[1] && cdb_tag[1] == t1[i]))
                t1_ready[i] = 1;
            else
                t1_ready[i] = entry[reg1[i]].ready;

            // T2
            if (write_en[0] && reg2[i] == destreg[0])
                t2[i] = T[0];
            else if (write_en[1] && reg2[i] == destreg[1])
                t2[i] = T[1];
            else
                t2[i] = entry[reg2[i]].tag;

            // T2 Ready
            if (reg2[i] == ZERO_REG)
                t2_ready[i] = 1;
            else if ((cdb_complete[0] && cdb_tag[0] == t2[i]) || (cdb_complete[1] && cdb_tag[1] == t2[i]))
                t2_ready[i] = 1;
            else
                t2_ready[i] = entry[reg2[i]].ready;
        end
    end

    // === Update logic ===
    always_comb begin
        nentry = entry;

        // Rename update
        for (int i = 0; i < WIDTH; i++) begin
            if (write_en[i]) begin
                nentry[destreg[i]].tag = T[i];
                nentry[destreg[i]].ready = (destreg[i] == ZERO_REG) ? 1 : 0;
            end
        end

        // CDB update
        for (int k = 0; k < WIDTH; k++) begin
            if (cdb_complete[k]) begin
                for (int q = 0; q < RF_SIZE; q++) begin
                    if (nentry[q].tag == cdb_tag[k]) begin
                        nentry[q].ready = 1;
                    end
                end
            end
        end
    end

    // === Writeback stage ===
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < RF_SIZE; i++) begin
                entry[i].tag <= i;
                entry[i].ready <= 1;
            end
        end else if (rollback_en) begin
            if (exception_en) begin
                for (int i = 0; i < RF_SIZE; i++) begin
                    entry[i].tag <= rec_tag[i];
                    entry[i].ready <= 1;
                end
            end else begin
                for (int i = 0; i < RF_SIZE; i++) begin
                    if (i != rollback_reg)
                        entry[i].tag <= rec_tag[i];
                    else
                        entry[i].tag <= rollback_tag;
                    entry[i].ready <= 1;
                end
            end
        end else begin
            entry <= nentry;
        end
    end

endmodule
