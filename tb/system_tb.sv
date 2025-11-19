`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: system_tb
// Description: Integration Testbench for Phase 2 Step 1
//              Connects CPU, ROM, RAM, and Bridge.
//////////////////////////////////////////////////////////////////////////////////

module system_tb;

    // 1. 信号定義
    logic        clk;
    logic        reset;
    
    // CPU Interface
    logic [14:0] pc;
    logic [15:0] instruction;
    logic [14:0] addressM;
    logic        writeM;
    logic [15:0] outM;
    logic [15:0] inM;

    // Bridge <-> RAM/IO Interface
    logic [13:0] ram_addr;
    logic [15:0] ram_data_in;
    logic [15:0] ram_data_out;
    logic        ram_we;

    logic [15:0] io_addr;
    logic [15:0] io_data_in;
    logic [15:0] io_data_out;
    logic        io_we;

    // 2. クロック生成 (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 3. モジュール インスタンス化

    // 3.1 Hack ROM (Instruction Memory)
    // パラメータで先ほど作成したファイルを指定
    hack_rom #(
        .INIT_FILE("integration_test.hack") 
    ) u_rom (
        .clk         (clk),
        .addr        (pc),
        .instruction (instruction)
    );

    // 3.2 Hack CPU (Phase 1で作成済みと仮定)
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
    memory_io_bridge u_bridge (
        .addressM    (addressM),
        .outM        (outM),
        .writeM      (writeM),
        .inM         (inM),
        
        .ram_addr    (ram_addr),
        .ram_data_in (ram_data_in),
        .ram_we      (ram_we),
        .ram_data_out(ram_data_out),
        
        .io_addr     (io_addr),
        .io_data_out (io_data_out),
        .io_we       (io_we),
        .io_data_in  (io_data_in)
    );

    // 3.4 Hack RAM (Data Memory)
    hack_ram u_ram (
        .clk         (clk),
        .we          (ram_we),
        .addr        (ram_addr),
        .d_in        (ram_data_in),
        .d_out       (ram_data_out)
    );

    // 3.5 Dummy I/O Input (Step 1では固定値)
    assign io_data_in = 16'h0000;

    // 4. テストシナリオ
    initial begin
        // 波形ダンプ用 (必要に応じて)
        // $dumpfile("system_tb.vcd");
        // $dumpvars(0, system_tb);

        $display("--- Simulation Start ---");
        
        // リセットシーケンス
        reset = 1;
        #20;
        reset = 0;
        $display("Time: %0t | Reset released", $time);

        // プログラム実行待ち (数サイクル)
        // 4命令実行 + ループに入るまで待機
        #200;

        // 5. 結果検証
        // RAM[100] に 12345 (0x3039) が書き込まれているかチェック
        // hack_ramモジュール内のメモリ配列に直接アクセスして検証 (Backdoor access)
        if (u_ram.ram_array[100] === 16'h3039) begin
            $display("SUCCESS: RAM[100] contains 0x3039 (12345). System Integration OK.");
        end else begin
            $display("ERROR: RAM[100] contains 0x%0h, expected 0x3039.", u_ram.ram_array[100]);
        end

        $display("--- Simulation End ---");
        $finish;
    end

endmodule