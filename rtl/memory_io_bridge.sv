`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: memory_io_bridge
// Description: Maps CPU addressM to RAM or I/O devices.
//              Address Map:
//              0x0000 - 0x3FFF : RAM (16K)
//              0x4000 - 0x5FFF : Screen (Reserved/Unused)
//              0x6000 - 0x7FFF : Memory Mapped I/O
//////////////////////////////////////////////////////////////////////////////////

module memory_io_bridge (
    // CPU Interface
    input  logic [14:0] addressM,
    input  logic [15:0] outM,
    input  logic        writeM,
    output logic [15:0] inM,

    // RAM Interface
    output logic [13:0] ram_addr,
    output logic [15:0] ram_data_in,
    output logic        ram_we,
    input  logic [15:0] ram_data_out,

    // I/O Interface (Step 2で使用予定)
    output logic [15:0] io_addr,     // 下位ビットを使用
    output logic [15:0] io_data_out,
    output logic        io_we,
    input  logic [15:0] io_data_in
);

    // アドレスデコード用定数
    localparam logic [1:0] SEL_RAM    = 2'b00; // 0x0000 - 0x3FFF (top 2 bits 00)
    localparam logic [1:0] SEL_SCREEN = 2'b01; // 0x4000 - 0x5FFF (top 2 bits 01)
    localparam logic [1:0] SEL_IO     = 2'b11; // 0x6000 - 0x7FFF (starts with 11 in binary for 15bit addr? No.)
    
    // Hack Address is 15-bit.
    // 0x0000 - 0x3FFF: 00xx_xxxx_xxxx_xxxx (RAM)
    // 0x4000 - 0x5FFF: 01xx_xxxx_xxxx_xxxx (Screen)
    // 0x6000 - 0x7FFF: 11xx_xxxx_xxxx_xxxx (Keyboard/IO in standard Hack is 0x6000=24576)
    // Wait, 0x6000 (Hex) = 0110_0000... in 16bit.
    // Let's look at bit 14 and 13 of addressM (15-bit width: [14:0]).
    // 0x0000-0x3FFF: 00... -> bits[14:13] = 00
    // 0x4000-0x5FFF: 01... -> bits[14:13] = 01
    // 0x6000-0x7FFF: 11... -> bits[14:13] = 11 (Wait, 0x6000 is 110... in 15-bit? No.)
    
    // Correct decoding for 15-bit address:
    // 0x0000 (0)     -> 000 0000 0000 0000
    // 0x3FFF (16383) -> 011 1111 1111 1111
    // 0x4000 (16384) -> 100 0000 0000 0000
    // 0x6000 (24576) -> 110 0000 0000 0000
    
    logic is_ram;
    logic is_io;

    always_comb begin
        is_ram = (addressM[14] == 1'b0);      // 0x0000 - 0x3FFF
        is_io  = (addressM[14:13] == 2'b11);  // 0x6000 - 0x7FFF
    end

    // RAM Outputs
    always_comb begin
        ram_addr    = addressM[13:0]; // RAMは14bitアドレス
        ram_data_in = outM;
        ram_we      = writeM & is_ram;
    end

    // I/O Outputs (Pass-through)
    always_comb begin
        io_addr     = {2'b00, addressM[13:0]}; // 拡張用
        io_data_out = outM;
        io_we       = writeM & is_io;
    end

    // CPU Input MUX (inM)
    // 組み合わせ回路でのマルチプレクサ [cite: 1707]
    always_comb begin
        // デフォルト値 (ラッチ防止) [cite: 1712]
        inM = 16'h0000;

        if (is_ram) begin
            inM = ram_data_out;
        end else if (is_io) begin
            inM = io_data_in;
        end else begin
            inM = 16'h0000; // Screen領域など
        end
    end

endmodule