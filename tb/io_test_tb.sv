`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: system_tb
// Description: Generic Integration Testbench for Hack Computer
//              - Connects CPU, ROM, RAM, and Bridge.
//              - No automatic pass/fail check.
//              - Monitors RAM writes and prints final register states.
//////////////////////////////////////////////////////////////////////////////////

module io_test_tb;

    // ========================================================================
    // 0. 設定 (テストしたい .hack ファイル名をここで指定)
    // ========================================================================
    parameter string ROM_FILE = "io_test.hack"; // デフォルトのテストプログラム
    // parameter string ROM_FILE = "integration_test.hack"; // 切り替え例

    // ========================================================================
    // 1. 信号定義
    // ========================================================================
    logic        clk;
    logic        reset;
    
    // CPU Interface
    logic [14:0] pc;
    logic [15:0] instruction;
    logic [14:0] addressM;
    logic        writeM;
    logic [15:0] outM;
    logic [15:0] inM;

    // Bridge <-> RAM Interface
    logic [13:0] ram_addr;
    logic [15:0] ram_data_in;
    logic [15:0] ram_data_out;
    logic        ram_we;

    // Bridge <-> I/O Interface (Physical Ports)
    // 汎用性を高めるため、ワイヤで受ける
    logic [15:0] sw_data_dummy;  // Switch Input
    logic [4:0]  btn_data_dummy; // Button Input
    logic [15:0] led_data_out;   // LED Output (Observed via waveform)
    logic [15:0] seg_data_out;   // 7-Seg Output (Observed via waveform)

    // ========================================================================
    // 2. クロック生成 (10ns period = 100MHz)
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // 3. モジュール インスタンス化
    // ========================================================================

    // 3.1 Hack ROM (Instruction Memory)
    hack_rom #(
        .INIT_FILE(ROM_FILE) 
    ) u_rom (
        .clk         (clk),
        .addr        (pc),
        .instruction (instruction)
    );

    // 3.2 Hack CPU
    hack_cpu u_cpu (
        .clk         (clk),
        .reset       (reset),
        .instruction (instruction),
        .inM         (inM),
        .outM        (outM),
        .writeM      (writeM),
        .addressM    (addressM),
        .pc          (pc)
    );

    // 3.3 Memory I/O Bridge
    // 注意: ポート名は memory_io_bridge.sv の定義に合わせています。
    // もしコンパイルエラーが出る場合は、bridge側の定義を確認してください。
    memory_io_bridge u_bridge (
        // CPU Side
        .addressM    (addressM),
        .outM        (outM),
        .writeM      (writeM),
        .inM         (inM),
        
        // RAM Side
        .ram_addr    (ram_addr),
        .ram_data_in (ram_data_in),
        .ram_we      (ram_we),
        .ram_data_out(ram_data_out),
        
        // I/O Side
        .sw_data     (sw_data_dummy),  // Input from Switches
        .btn_data    (btn_data_dummy), // Input from Buttons
        .led_we    (led_data_out),   // Output to LEDs
        .seg_we    (seg_data_out)    // Output to 7-Seg
    );

    // 3.4 Hack RAM (Data Memory)
    hack_ram u_ram (
        .clk         (clk),
        .we          (ram_we),
        .addr        (ram_addr),
        .d_in        (ram_data_in),
        .d_out       (ram_data_out)
    );

    // ========================================================================
    // 4. 入力初期化
    // ========================================================================
    initial begin
        // スイッチ入力をエミュレートしたい場合はここで値を設定
        sw_data_dummy  = 16'h0000; 
        btn_data_dummy = 5'b00000;
    end

    // ========================================================================
    // 5. モニタリング (コンソール出力)
    // ========================================================================
    // メモリへの書き込みが発生した瞬間にログを表示
    always @(posedge clk) begin
        if (ram_we) begin
            $display("[Time %0t] Write RAM[%0d] <= %0d (0x%h)", 
                     $time, ram_addr, ram_data_in, ram_data_in);
        end
    end

    // ========================================================================
    // 6. テストシナリオ実行
    // ========================================================================
    initial begin
        $display("==================================================");
        $display(" Simulation Start: %s (I/O Test)", ROM_FILE);
        $display("==================================================");
        
        // 初期化
        reset = 1;
        sw_data_dummy  = 16'h0000;
        btn_data_dummy = 5'b00000;
        #50;
        reset = 0;
        $display("[Time %0t] Reset Released.", $time);

        // --- パターン1: スイッチ入力テスト ---
        #1000; // CPUがループに入るまで少し待つ
        
        $display("[Time %0t] Action: Toggle Switches to 0xAAAA", $time);
        sw_data_dummy = 16'hAAAA; // スイッチを 1010... に変更

        #2000; // CPUが読み取るのを待つ

        // RAM[16] が 0xAAAA になったかチェック
        if (u_ram.ram_array[16] === 16'hAAAA) begin
            $display("SUCCESS: CPU read Switches (0xAAAA) correctly.");
        end else begin
            $display("ERROR: CPU failed to read Switches. RAM[16] = 0x%4h", u_ram.ram_array[16]);
        end

        // --- パターン2: ボタン入力テスト ---
        $display("[Time %0t] Action: Press Button (Center/Left) -> 0x05", $time);
        btn_data_dummy = 5'b00101; // ボタンを変更

        #2000; // 待機

        // RAM[17] が 0x0005 になったかチェック
        if (u_ram.ram_array[17] === 16'h0005) begin
            $display("SUCCESS: CPU read Buttons (0x05) correctly.");
        end else begin
            $display("ERROR: CPU failed to read Buttons. RAM[17] = 0x%4h", u_ram.ram_array[17]);
        end

        $display("==================================================");
        $finish;
    end

endmodule