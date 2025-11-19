`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: debouncer
// Description: Input Synchronizer and Debouncer
//              Delays signal update until stable for ~10ms.
//////////////////////////////////////////////////////////////////////////////////

module debouncer(
    input  logic clk,
    input  logic reset,
    input  logic btn_in,   // Raw input
    output logic btn_out   // Clean output
    );

    // 1. Synchronizer (2-stage FF for CDC)
    logic sync_0, sync_1;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            sync_0 <= 0;
            sync_1 <= 0;
        end else begin
            sync_0 <= btn_in;
            sync_1 <= sync_0;
        end
    end

    // 2. Debounce Counter
    // 10ms @ 100MHz = 1,000,000 cycles -> 20-bit counter (1,048,576)
    localparam int MAX_COUNT = 1_000_000;
    logic [19:0] counter;
    logic        stable_val; // 現在安定しているとみなしている値

    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            stable_val <= 0;
            btn_out <= 0;
        end else begin
            if (sync_1 != stable_val) begin
                // 入力が現在の安定値と異なる場合、カウント開始
                counter <= counter + 1;
                if (counter >= MAX_COUNT) begin
                    // 十分な時間安定して変化した -> 値を更新
                    stable_val <= sync_1;
                    counter <= 0;
                end
            end else begin
                // 入力が安定値と同じ -> カウンタリセット（ノイズだったと判断）
                counter <= 0;
            end
            
            // 出力更新
            btn_out <= stable_val;
        end
    end

endmodule