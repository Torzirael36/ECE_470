`timescale 1ns/100ps

module FreeList #(
    parameter PRF_SIZE = 64,                // 物理寄存器总数
    parameter FL_SIZE = 32,                 // Free List 大小
    parameter WIDTH = 2,                    // 每周期最多发射多少指令
    parameter ROB_SIZE = 32                 // 用于 rollback head
)(
    input  logic clock,
    input  logic reset,

    // 从 Dispatch 阶段来的申请信号
    input  logic [WIDTH-1:0] dispatch_en,    // 是否申请物理寄存器
    output logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] free_phys_regs, // 发配出去的PRF编号

    // 从 ROB (retire) 回收 T_old
    input  logic [WIDTH-1:0] retire_en,
    input  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] retired_tags,

    // 回滚支持
    input  logic rollback_en,
    input  logic [$clog2(FL_SIZE)-1:0] recover_head
);

    // ========================
    // 数据结构
    // ========================
    logic [$clog2(PRF_SIZE)-1:0] freelist[FL_SIZE-1:0];
    logic [$clog2(FL_SIZE)-1:0] head, tail;
    logic [$clog2(FL_SIZE)-1:0] next_head, next_tail;
    logic [$clog2(PRF_SIZE)-1:0] temp_list[FL_SIZE-1:0];

    // ========================
    // 发射阶段：从 freelist 分配新物理寄存器
    // ========================
    always_comb begin
        next_head = head;
        for (int i = 0; i < WIDTH; i++) begin
            if (dispatch_en[i]) begin
                free_phys_regs[i] = freelist[next_head];
                next_head = (next_head + 1) % FL_SIZE;
            end else begin
                free_phys_regs[i] = '0;
            end
        end
    end

    // ========================
    // 提交阶段：从 ROB 回收 T_old
    // ========================
    always_comb begin
        next_tail = tail;
        temp_list = freelist;
        for (int i = 0; i < WIDTH; i++) begin
            if (retire_en[i]) begin
                temp_list[next_tail] = retired_tags[i];
                next_tail = (next_tail + 1) % FL_SIZE;
            end
        end
    end

    // ========================
    // 时序更新逻辑
    // ========================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            // 初始化 freelist
            for (int i = 0; i < FL_SIZE; i++) begin
                freelist[i] <= i + FL_SIZE; // 假设前面部分保留给 ARF
            end
            head <= 0;
            tail <= 0;
        end else if (rollback_en) begin
            // 回滚时恢复分配指针
            head <= recover_head;
        end else begin
            head <= next_head;
            tail <= next_tail;
            freelist <= temp_list;
        end
    end

endmodule
