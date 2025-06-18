
`timescale 1ns/1ps

module ROB #(
    parameter ENTRY_NUM = 32,
    parameter REG_WIDTH = 5,
    parameter PHY_REG_WIDTH = 6,
    parameter XLEN = 32
)(
    input logic clock,
    input logic reset,

    // Dispatch interface
    input logic dispatch_valid,
    input logic [REG_WIDTH-1:0] dest_logical,
    input logic [PHY_REG_WIDTH-1:0] dest_physical,
    input logic [PHY_REG_WIDTH-1:0] old_physical,
    input logic [XLEN-1:0] pc,

    // Complete interface (CDB)
    input logic complete_valid,
    input logic [PHY_REG_WIDTH-1:0] complete_tag,

    // Retire interface
    output logic retire_valid,
    output logic [REG_WIDTH-1:0] retire_logical,
    output logic [PHY_REG_WIDTH-1:0] retire_physical,
    output logic [PHY_REG_WIDTH-1:0] retire_old
);

    typedef struct packed {
        logic valid;
        logic [REG_WIDTH-1:0] dest_logical;
        logic [PHY_REG_WIDTH-1:0] dest_physical;
        logic [PHY_REG_WIDTH-1:0] old_physical;
        logic [XLEN-1:0] pc;
        logic complete;
    } rob_entry_t;

    rob_entry_t rob[ENTRY_NUM];
    logic [$clog2(ENTRY_NUM)-1:0] head, tail;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            for (int i = 0; i < ENTRY_NUM; i++) rob[i] <= '0;
        end else begin
            // Dispatch
            if (dispatch_valid && !rob[tail].valid) begin
                rob[tail].valid <= 1;
                rob[tail].dest_logical <= dest_logical;
                rob[tail].dest_physical <= dest_physical;
                rob[tail].old_physical <= old_physical;
                rob[tail].pc <= pc;
                rob[tail].complete <= 0;
                tail <= (tail + 1) % ENTRY_NUM;
            end

            // Complete
            if (complete_valid) begin
                for (int i = 0; i < ENTRY_NUM; i++) begin
                    if (rob[i].valid && rob[i].dest_physical == complete_tag) begin
                        rob[i].complete <= 1;
                    end
                end
            end

            // Retire
            if (rob[head].valid && rob[head].complete) begin
                retire_valid <= 1;
                retire_logical <= rob[head].dest_logical;
                retire_physical <= rob[head].dest_physical;
                retire_old <= rob[head].old_physical;
                rob[head].valid <= 0;
                head <= (head + 1) % ENTRY_NUM;
            end else begin
                retire_valid <= 0;
            end
        end
    end

endmodule
