`timescale 1ns / 1ps

module hack_cpu (
    input  logic        clk,
    input  logic        reset,       // Active High
    input  logic [15:0] instruction, // ROMからの命令
    input  logic [15:0] inM,         // RAM[A]からのデータ
    output logic [15:0] outM,        // RAM[A]への書き込みデータ
    output logic        writeM,      // RAM[A]への書き込み許可
    output logic [14:0] addressM,    // RAM[A]のアドレス
    output logic [14:0] pc           // 次の命令アドレス
);

    // --- 内部信号定義 ---
    logic [15:0] a_reg;
    logic [15:0] d_reg;
    logic [14:0] pc_reg;
    
    logic [15:0] alu_out;
    logic        zr, ng; // ALU flags: Zero, Negative
    
    // --- 1. 命令デコード ---
    logic is_a_instr;
    logic is_c_instr;
    assign is_a_instr = (instruction[15] == 1'b0);
    assign is_c_instr = (instruction[15] == 1'b1);

    logic a_bit;
    assign a_bit = instruction[12];

    logic [5:0] comp_bits;
    assign comp_bits = instruction[11:6];

    logic d2, d1, d0; // dest: A, D, M
    assign d2 = instruction[5];
    assign d1 = instruction[4];
    assign d0 = instruction[3];

    logic [2:0] jump_bits;
    assign jump_bits = instruction[2:0]; // j3(MSB), j2, j1(LSB)

    // --- 2. 制御信号 ---
    logic load_a;
    assign load_a = is_a_instr | (is_c_instr & d2);

    logic load_d;
    assign load_d = is_c_instr & d1;

    assign writeM = is_c_instr & d0;
    assign addressM = a_reg[14:0];
    assign outM = alu_out;

    // --- 3. データパス & ALU ---
    logic [15:0] a_next;
    assign a_next = is_a_instr ? instruction : alu_out;

    always_ff @(posedge clk) begin
        if (reset) begin
            a_reg <= 16'd0;
            d_reg <= 16'd0;
        end else begin
            if (load_a) a_reg <= a_next;
            if (load_d) d_reg <= alu_out;
        end
    end

    logic [15:0] alu_y;
    assign alu_y = (a_bit == 1'b0) ? a_reg : inM;

    // ALU インスタンス化
    hack_alu u_alu (
        .x   (d_reg),
        .y   (alu_y),
        .zx  (comp_bits[5]),
        .nx  (comp_bits[4]),
        .zy  (comp_bits[3]),
        .ny  (comp_bits[2]),
        .f   (comp_bits[1]),
        .no  (comp_bits[0]),
        .out (alu_out),
        .zr  (zr),
        .ng  (ng)
    );

    // --- 4. プログラムカウンタ (PC) 制御  ---

    logic jump_enable;
    
    // jump_bits[2] (j3): Out < 0 (ng) ならジャンプ
    // jump_bits[1] (j2): Out = 0 (zr) ならジャンプ
    // jump_bits[0] (j1): Out > 0 (!ng && !zr) ならジャンプ
    
    logic j3, j2, j1;
    assign j3 = jump_bits[2];
    assign j2 = jump_bits[1];
    assign j1 = jump_bits[0];
    
    logic condition_met;
    always_comb begin
        condition_met = (j3 & ng) | (j2 & zr) | (j1 & (!ng & !zr));
    end

    assign jump_enable = is_c_instr & condition_met;

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_reg <= 15'd0;
        end else begin
            if (jump_enable) begin
                pc_reg <= a_reg[14:0];
            end else begin
                pc_reg <= pc_reg + 15'd1;
            end
        end
    end

    assign pc = pc_reg;

endmodule