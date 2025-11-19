`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_rom
// Description: Instruction Memory for Hack CPU
//              - Asynchronous Read (Distributed RAM)
//              - Reduced size (4K words) to fit in Artix-7 LUTs
//////////////////////////////////////////////////////////////////////////////////

module hack_rom #(
    parameter string INIT_FILE = "calculator_lite.hack", 
    parameter int    ADDR_WIDTH = 12  // 12bit = 4096 words (容量削減)
) (
    input  logic                  clk, // 非同期なので内部では未使用
    input  logic [14:0]           addr, // CPUからの15bitアドレス
    output logic [15:0]           instruction
);

    // 分散RAM (Distributed RAM) として推論させるヒント
    (* rom_style = "distributed" *)
    logic [15:0] rom_array [0:(2**ADDR_WIDTH)-1];

    initial begin
        $readmemb(INIT_FILE, rom_array);
    end

    // 【重要】非同期読み出し (Combinational Read)
    // アドレスの下位ビットのみを使用
    assign instruction = rom_array[addr[ADDR_WIDTH-1:0]];

endmodule