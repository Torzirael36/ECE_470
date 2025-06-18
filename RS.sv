`timescale 1ns/1ps

module rs #(
    parameter RS_SIZE = 16,
    parameter TAG_WIDTH = 6,
    parameter DATA_WIDTH = 32,
    parameter OPCODE_WIDTH = 6,
    parameter ROB_IDX_WIDTH = 5,
    parameter WIDTH = 2
)(
    input logic                      clk,
    input logic                      reset,

    // Dispatch interface
    input  logic [WIDTH-1:0]                     dispatch_en,
    input  logic [WIDTH-1:0][OPCODE_WIDTH-1:0]   opcode_in,
    input  logic [WIDTH-1:0][TAG_WIDTH-1:0]      src1_tag_in,
    input  logic [WIDTH-1:0]                     src1_ready_in,
    input  logic [WIDTH-1:0][DATA_WIDTH-1:0]     src1_value_in,
    input  logic [WIDTH-1:0][TAG_WIDTH-1:0]      src2_tag_in,
    input  logic [WIDTH-1:0]                     src2_ready_in,
    input  logic [WIDTH-1:0][DATA_WIDTH-1:0]     src2_value_in,
    input  logic [WIDTH-1:0][TAG_WIDTH-1:0]      dest_tag_in,
    input  logic [WIDTH-1:0][ROB_IDX_WIDTH-1:0]  rob_idx_in,

    // Rollback support
    input logic rollback,

    // CDB broadcast
    input  logic [1:0][TAG_WIDTH-1:0]            cdb_tag,
    input  logic [1:0][DATA_WIDTH-1:0]           cdb_value,
    input  logic [1:0]                           cdb_valid,

    // Issue output
    output logic [WIDTH-1:0]                     issue_valid,
    output logic [WIDTH-1:0][OPCODE_WIDTH-1:0]   issue_opcode,
    output logic [WIDTH-1:0][DATA_WIDTH-1:0]     issue_src1,
    output logic [WIDTH-1:0][DATA_WIDTH-1:0]     issue_src2,
    output logic [WIDTH-1:0][TAG_WIDTH-1:0]      issue_dest_tag,
    output logic [WIDTH-1:0][ROB_IDX_WIDTH-1:0]  issue_rob_idx,

    // Full signal to dispatch unit
    output logic [WIDTH-1:0]                     full
);

typedef struct packed {
    logic                        valid;
    logic [OPCODE_WIDTH-1:0]    opcode;
    logic [TAG_WIDTH-1:0]       src1_tag;
    logic                       src1_ready;
    logic [DATA_WIDTH-1:0]      src1_value;
    logic [TAG_WIDTH-1:0]       src2_tag;
    logic                       src2_ready;
    logic [DATA_WIDTH-1:0]      src2_value;
    logic [TAG_WIDTH-1:0]       dest_tag;
    logic [ROB_IDX_WIDTH-1:0]   rob_idx;
} rs_entry_t;

rs_entry_t rs[RS_SIZE];

// Dispatch logic
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        foreach (rs[i]) rs[i].valid <= 0;
    end else begin
        for (int w = 0; w < WIDTH; w++) begin
            if (dispatch_en[w]) begin
                for (int i = 0; i < RS_SIZE; i++) begin
                    if (!rs[i].valid) begin
                        rs[i].valid        <= 1;
                        rs[i].opcode       <= opcode_in[w];
                        rs[i].src1_tag     <= src1_tag_in[w];
                        rs[i].src1_ready   <= src1_ready_in[w];
                        rs[i].src1_value   <= src1_value_in[w];
                        rs[i].src2_tag     <= src2_tag_in[w];
                        rs[i].src2_ready   <= src2_ready_in[w];
                        rs[i].src2_value   <= src2_value_in[w];
                        rs[i].dest_tag     <= dest_tag_in[w];
                        rs[i].rob_idx      <= rob_idx_in[w];
                        break;
                    end
                end
            end
        end
    end
end

// CDB update logic
always_ff @(posedge clk) begin
    for (int i = 0; i < RS_SIZE; i++) begin
        if (rs[i].valid) begin
            for (int c = 0; c < 2; c++) begin
                if (cdb_valid[c]) begin
                    if (!rs[i].src1_ready && rs[i].src1_tag == cdb_tag[c]) begin
                        rs[i].src1_ready <= 1;
                        rs[i].src1_value <= cdb_value[c];
                    end
                    if (!rs[i].src2_ready && rs[i].src2_tag == cdb_tag[c]) begin
                        rs[i].src2_ready <= 1;
                        rs[i].src2_value <= cdb_value[c];
                    end
                end
            end
        end
    end
end

// Issue logic
always_comb begin
    logic [$clog2(RS_SIZE+1)-1:0] issued;
    issued = '0;
    
    issue_valid     = '0;
    issue_opcode    = '0;
    issue_src1      = '0;
    issue_src2      = '0;
    issue_dest_tag  = '0;
    issue_rob_idx   = '0;
    
    
    for (int i = 0; i < RS_SIZE && issued < WIDTH; i++) begin
        if (rs[i].valid && rs[i].src1_ready && rs[i].src2_ready) begin
            issue_valid[issued]     = 1;
            issue_opcode[issued]    = rs[i].opcode;
            issue_src1[issued]      = rs[i].src1_value;
            issue_src2[issued]      = rs[i].src2_value;
            issue_dest_tag[issued]  = rs[i].dest_tag;
            issue_rob_idx[issued]   = rs[i].rob_idx;
            rs[i].valid             = 0;
            issued++;
        end
    end
end

// Full detection
always_comb begin
    int count = 0;
    foreach (rs[i]) if (rs[i].valid) count++;
    for (int w = 0; w < WIDTH; w++)
        full[w] = (count >= RS_SIZE - w);
end

// Rollback logic
always_ff @(posedge clk) begin
    if (rollback) begin
        foreach (rs[i]) rs[i].valid <= 0;
    end
end

endmodule
