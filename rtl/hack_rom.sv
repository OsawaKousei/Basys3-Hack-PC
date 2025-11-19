`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_rom
// Description: Instruction Memory for Hack CPU
//              Infer Block RAM using synchronous read.
//////////////////////////////////////////////////////////////////////////////////

module hack_rom #(
    parameter string INIT_FILE = "prog.hack", // 初期化ファイル名
    parameter int    ADDR_WIDTH = 15          // 32K words max
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [15:0]           instruction
);

    // メモリ配列定義 (32K x 16bit)
    // Vivado will infer Block RAM here 
    (* rom_style = "block" *)
    logic [15:0] rom_array [0:(2**ADDR_WIDTH)-1];

    // 初期値ロード
    initial begin
        $readmemb(INIT_FILE, rom_array);
    end

    // 同期読み出し (always_ff) [cite: 1702]
    always_ff @(posedge clk) begin
        instruction <= rom_array[addr];
    end

endmodule