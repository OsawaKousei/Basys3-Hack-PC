`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_cpu_tb
// Description: 
//   Hack CPU (Standard Specification) の検証用テストベンチ。
//   以下の機能を確認する。
//   1. リセット動作
//   2. A命令 (定数ロード)
//   3. C命令 (ALU演算, レジスタ転送)
//   4. メモリ書き込み (writeM)
//   5. ジャンプ制御 (標準仕様のビット割り当て: JGT=001, JEQ=010, JMP=111等)
//////////////////////////////////////////////////////////////////////////////////

module hack_cpu_tb;

    // --- 信号定義 ---
    logic        clk;
    logic        reset;
    logic [15:0] instruction;
    logic [15:0] inM;
    logic [15:0] outM;
    logic        writeM;
    logic [14:0] addressM;
    logic [14:0] pc;

    // --- DUT (Device Under Test) インスタンス化 ---
    hack_cpu u_cpu (
        .clk        (clk),
        .reset      (reset),
        .instruction(instruction),
        .inM        (inM),
        .outM       (outM),
        .writeM     (writeM),
        .addressM   (addressM),
        .pc         (pc)
    );

    // --- クロック生成 (10ns周期 = 100MHz) ---
    always #5 clk = ~clk;

    // --- テストシナリオ実行 ---
    initial begin
        // 0. 初期化
        clk = 0;
        reset = 1;
        instruction = 0;
        inM = 0;

        // --- 1. リセット動作確認 ---
        #20;
        reset = 0;
        $display("\n--- Test Start: Hack CPU (Standard Spec) ---");
        
        // Check: PCは0であるべき
        if (pc !== 0) $error("[Reset] Error: PC is not 0. Got: %d", pc);
        else $display("[Reset] Pass: PC initialized to 0.");

        // --- 2. A命令実行 (@17) ---
        // Aレジスタに17をロード。
        // Binary: 0000 0000 0001 0001
        instruction = 16'b0000000000010001; 
        #10; 
        
        // Check: Aレジスタ(addressMに出力される)が17か
        if (addressM !== 17) $error("[A-Instr] Error: addressM is not 17. Got: %d", addressM);
        else $display("[A-Instr] Pass: A-Register loaded with 17.");

        // --- 3. C命令: D=A (Dレジスタへのロード) ---
        // dest=D(010), comp=A(0110000), jump=null(000)
        // Binary: 111 0 110000 010 000
        instruction = 16'b1110110000010000;
        #10;
        // Dレジスタは内部値なので直接見えないが、次の演算で確認する。
        $display("[C-Instr] Executed D=A. (Internal D should be 17)");

        // --- 4. C命令: D=D+A (演算確認) ---
        // D(17) + A(17) = 34
        // dest=D(010), comp=D+A(0000010)
        // Binary: 111 0 000010 010 000
        instruction = 16'b1110000010010000;
        #10;
        $display("[C-Instr] Executed D=D+A. (Internal D should be 34)");

        // --- 5. C命令: M=D (メモリ書き込みとALU出力確認) ---
        // dest=M(001), comp=D(0001100)
        // Binary: 111 0 001100 001 000
        instruction = 16'b1110001100001000;
        #10;
        
        // Check: outMが34, writeMが1
        if (outM !== 34) $error("[ALU/Write] Error: outM is not 34. Got: %d", outM);
        else if (writeM !== 1) $error("[ALU/Write] Error: writeM is not 1.");
        else $display("[ALU/Write] Pass: M=D executed correctly (Val=34).");

        // --- 6. ジャンプ制御テスト 1: JEQ (条件不成立) ---
        // 現在 D=34 (非ゼロ) なので、JEQ (Equal to 0) はジャンプしないはず。
        // comp=D, jump=JEQ(010)
        // Binary: 111 0 001100 000 010
        instruction = 16'b1110001100000010;
        
        // PCの値を確認するために1クロック進める
        // 現在のPCは命令フェッチごとに+1されている。
        // Reset(0) -> @17(1) -> D=A(2) -> D=D+A(3) -> M=D(4) -> JEQ(5)
        // ジャンプしなければ次は 6 になるはず。
        #10;
        if (pc !== 5) $error("[Jump-Fail] Error: PC jumped unexpectedly. PC=%d", pc); 
        else $display("[Jump-Fail] Pass: JEQ condition failed (34 != 0), PC incremented.");

        // --- 7. ジャンプ制御テスト 2: JGT (条件成立 - 標準仕様の確認) ---
        // 重要: ここで仕様書の誤り(100)ではなく、標準仕様(001)を使用する。
        // 現在 D=34 (>0) なので、JGT (Greater Than 0) はジャンプするはず。
        // ジャンプ先は Aレジスタ (17)。
        // comp=D, jump=JGT(001)
        // Binary: 111 0 001100 000 001
        instruction = 16'b1110001100000001;
        #10;
        
        // Check: PCが17になっているか
        if (pc !== 17) $error("[Jump-Success] Error: JGT did not jump. PC=%d (Expected 17)", pc);
        else $display("[Jump-Success] Pass: JGT condition met (34 > 0), PC jumped to 17.");

        // --- 8. ジャンプ制御テスト 3: JMP (無条件ジャンプ) ---
        // Aレジスタを 100 に変更
        instruction = 16'd100; // @100
        #10;
        
        // 0;JMP (無条件ジャンプ)
        // comp=0(101010), jump=JMP(111)
        // Binary: 111 0 101010 000 111
        instruction = 16'b1110101010000111;
        #10;

        // Check: PCが100になっているか
        if (pc !== 100) $error("[Unconditional Jump] Error: JMP did not jump. PC=%d", pc);
        else $display("[Unconditional Jump] Pass: JMP executed, PC jumped to 100.");

        $display("--- All Tests Finished ---");
        $finish;
    end

endmodule