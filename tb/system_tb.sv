`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: system_tb
// Description: Generic Integration Testbench for Hack Computer
//              - Connects CPU, ROM, RAM, and Bridge.
//              - No automatic pass/fail check.
//              - Monitors RAM writes and prints final register states.
//////////////////////////////////////////////////////////////////////////////////

module system_tb;

    // ========================================================================
    // 0. 設定 (テストしたい .hack ファイル名をここで指定)
    // ========================================================================
    parameter string ROM_FILE = "math.hack"; 
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
        $display(" Simulation Start: %s", ROM_FILE);
        $display("==================================================");
        
        // リセットシーケンス
        reset = 1;
        #50;       // 少し長めにリセット
        reset = 0;
        $display("[Time %0t] Reset Released. CPU Running...", $time);

        // プログラム実行
        // Math.asmのようなループ処理は時間がかかるため長めに設定 (200us)
        // 必要に応じて調整してください
        #200000; 

        $display("");
        $display("==================================================");
        $display(" Simulation Finished (Timeout)");
        $display("==================================================");
        
        // 最終的なレジスタ値(R0-R15)をダンプ
        // ※ u_ram.ram_array は hack_ram 内部の実装に依存します。
        //   もしアクセスできない場合は、波形ビューアで確認してください。
        $display("--- Final Register Values (R0 - R15) ---");
        for (int i = 0; i <= 15; i++) begin
            $display("RAM[%2d] = %5d (0x%4h)", i, u_ram.ram_array[i], u_ram.ram_array[i]);
        end
        $display("----------------------------------------");

        // 結果確認用 (R0, R1, R2)
        $display("Check for Math.hack (R0 * R1 = R2):");
        $display("R0 (Input A) = %0d", u_ram.ram_array[0]);
        $display("R1 (Input B) = %0d", u_ram.ram_array[1]);
        $display("R2 (Result ) = %0d", u_ram.ram_array[2]);

        $finish;
    end

endmodule