`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_alu
// Project: Hack Computer ALU Implementation
// Description: 
//   Hackコンピュータ仕様に基づく16ビットALU。
//   算術演算(+)と論理演算(&)を行い、入力制御ビットにより様々な関数を実現する。
// 
// Inputs:
//   x, y: 16-bit data inputs
//   zx, nx, zy, ny, f, no: Control bits
// Outputs:
//   out: 16-bit data output
//   zr: Zero flag (1 if out == 0)
//   ng: Negative flag (1 if out < 0)
//////////////////////////////////////////////////////////////////////////////////

module hack_alu (
    input  logic [15:0] x,   // Data input x
    input  logic [15:0] y,   // Data input y
    input  logic        zx,  // Zero the x input
    input  logic        nx,  // Negate the x input
    input  logic        zy,  // Zero the y input
    input  logic        ny,  // Negate the y input
    input  logic        f,   // Function code: 1 for Add, 0 for And
    input  logic        no,  // Negate the out output
    output logic [15:0] out, // 16-bit output
    output logic        zr,  // 1 if (out == 0), 0 otherwise
    output logic        ng   // 1 if (out < 0),  0 otherwise
);

    // 内部信号の定義 (デバッグと可読性のため段階的に定義)
    logic [15:0] x_z, x_n;     // Xの前処理後信号
    logic [15:0] y_z, y_n;     // Yの前処理後信号
    logic [15:0] result_f;     // 関数演算(f)の結果
    logic [15:0] result_final; // 出力否定(no)後の最終結果

    // 組み合わせ回路ブロック 
    always_comb begin
        // 1. Xの前処理 (Zero / Negate)
        // zxが1なら0、そうでなければx
        x_z = zx ? 16'h0000 : x;
        // nxが1ならビット反転(Not)、そうでなければそのまま
        x_n = nx ? ~x_z     : x_z;

        // 2. Yの前処理 (Zero / Negate)
        // zyが1なら0、そうでなければy
        y_z = zy ? 16'h0000 : y;
        // nyが1ならビット反転(Not)、そうでなければそのまま
        y_n = ny ? ~y_z     : y_z;

        // 3. 演算の実行 (Function)
        // f=1: 加算 (+), f=0: 論理積 (&)
        if (f) begin
            result_f = x_n + y_n;
        end else begin
            result_f = x_n & y_n;
        end

        // 4. 出力の否定 (Negate Output)
        // no=1: 結果をビット反転
        result_final = no ? ~result_f : result_f;

        // 5. 出力とフラグの確定
        out = result_final;

        // zrフラグ: 結果が0なら1
        zr = (result_final == 16'h0000);

        // ngフラグ: 結果が負(MSBが1)なら1
        ng = result_final[15];
    end

endmodule
