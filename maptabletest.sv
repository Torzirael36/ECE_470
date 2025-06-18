`timescale 1ns/100ps

module Maptable_tb;

  // 参数
  localparam WIDTH = 2;
  localparam RF_SIZE = 32;
  localparam PRF_SIZE = 64;
  localparam XLEN = 32;
  localparam ZERO_REG = 0;

  logic clock = 0;
  logic reset;

  logic [WIDTH-1:0] write_en;
  logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] destreg;
  logic [WIDTH-1:0][$clog2(RF_SIZE)-1:0] reg1, reg2;
  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T;

  logic [WIDTH-1:0] cdb_complete;
  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] cdb_tag;

  logic [RF_SIZE-1:0][$clog2(PRF_SIZE)-1:0] rec_tag;
  logic rollback_en;
  logic [$clog2(RF_SIZE)-1:0] rollback_reg;
  logic [$clog2(PRF_SIZE)-1:0] rollback_tag;
  logic exception_en;

  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] T_hold;
  logic [WIDTH-1:0][$clog2(PRF_SIZE)-1:0] t1, t2;
  logic [WIDTH-1:0] t1_ready, t2_ready;

  // 实例化 DUT
  Maptable #(
    .WIDTH(WIDTH),
    .RF_SIZE(RF_SIZE),
    .PRF_SIZE(PRF_SIZE),
    .XLEN(XLEN),
    .ZERO_REG(ZERO_REG)
  ) dut (
    .reset(reset),
    .clock(clock),
    .write_en(write_en),
    .destreg(destreg),
    .reg1(reg1),
    .reg2(reg2),
    .T(T),
    .cdb_complete(cdb_complete),
    .cdb_tag(cdb_tag),
    .rec_tag(rec_tag),
    .rollback_en(rollback_en),
    .rollback_reg(rollback_reg),
    .rollback_tag(rollback_tag),
    .exception_en(exception_en),
    .T_hold(T_hold),
    .t1(t1),
    .t2(t2),
    .t1_ready(t1_ready),
    .t2_ready(t2_ready)
  );

  // 时钟生成
  always #5 clock = ~clock;

  initial begin
    $display("==== Maptable Test ====");
    reset = 1;
    write_en = 0;
    rollback_en = 0;
    exception_en = 0;
    #10;
    reset = 0;

    // STEP 1: dispatch两个指令 x1→p33, x2→p34
    write_en = 2'b11;
    destreg[0] = 5'd1;
    destreg[1] = 5'd2;
    T[0] = 6'd33;
    T[1] = 6'd34;

    // 设置源操作数为 x1 和 x2，确保它们的 tag 可从映射表读出
    reg1[0] = 5'd1;
    reg2[0] = 5'd2;
    reg1[1] = 5'd2;
    reg2[1] = 5'd1;
    #10;

    write_en = 0;
    #10;

    $display("T1[0]=%0d (should be 33), T2[0]=%0d (should be 34)", t1[0], t2[0]);
    $display("T1_ready[0]=%0d, T2_ready[0]=%0d", t1_ready[0], t2_ready[0]);

    // STEP 2: 模拟 CDB 返回 p33 完成
    cdb_complete = 2'b01;
    cdb_tag[0] = 6'd33;
    #10;

    cdb_complete = 0;
    #10;

    $display("After CDB complete p33 → t1_ready[0]=%0d (should be 1)", t1_ready[0]);

    // STEP 3: rollback 恢复所有 entry
    for (int i = 0; i < RF_SIZE; i++) begin
      rec_tag[i] = i + 10;
    end
    rollback_reg = 5'd2;
    rollback_tag = 6'd99;
    rollback_en = 1;
    exception_en = 0;
    #10;

    rollback_en = 0;
    #10;

    $display("After rollback: x1 tag=%0d, x2 tag=%0d", t1[0], t2[0]);

    $display("Test Complete.");
    $finish;
  end

endmodule
