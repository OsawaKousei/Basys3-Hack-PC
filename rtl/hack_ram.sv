`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_ram
// Description: Data Memory for Hack Computer
//              - Asynchronous Read (Combinational) implementation
//              - Required for single-cycle Hack CPU architecture
//////////////////////////////////////////////////////////////////////////////////

module hack_ram #(
    parameter int DEPTH = 16384, // 16K words
    parameter int WIDTH = 16
)(
    input  logic             clk,
    input  logic             we,    // Write Enable
    input  logic [13:0]      addr,  // Address (14-bit for 16K)
    input  logic [WIDTH-1:0] d_in,  // Data In
    output logic [WIDTH-1:0] d_out  // Data Out
);

    // メモリ配列の定義
    // simulationでは初期値を0にするため bit ではなく logic を推奨
    logic [WIDTH-1:0] ram_array [0:DEPTH-1];

    // 初期化 (Simulation用: x を防ぐため全て0クリア)
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            ram_array[i] = '0;
        end
    end

    // 書き込み: クロック同期 (Synchronous Write)
    always_ff @(posedge clk) begin
        if (we) begin
            ram_array[addr] <= d_in;
        end
    end

    // 読み出し: 非同期 (Asynchronous Read)
    // アドレスが変化したら即座にデータを出力する
    assign d_out = ram_array[addr];

endmodule