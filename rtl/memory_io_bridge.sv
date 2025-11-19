`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: memory_io_bridge
// Description: Address Decoder & Data Router for Hack Computer
//              (Step 3 Updated Version)
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

    // I/O Interface (Updated Ports)
    input  logic [15:0] sw_data,   // 0x6000
    input  logic [4:0]  btn_data,  // 0x6001
    output logic        seg_we,    // 0x6002 Write Enable
    output logic        led_we,    // 0x6003 Write Enable
    output logic [15:0] io_data_out // Data to be written
);

    // アドレスデコード
    logic is_ram;
    logic is_io_sw;
    logic is_io_btn;
    logic is_io_seg;
    logic is_io_led;

    always_comb begin
        // RAM: 0x0000 - 0x3FFF (MSB bit 14 is 0)
        is_ram = (addressM[14] == 1'b0);
        
        // I/O: 0x6000 - 0x7FFF (Upper 2 bits are 11)
        // 具体的なアドレスマッチング
        if (addressM == 15'h6000) is_io_sw  = 1'b1; else is_io_sw  = 1'b0;
        if (addressM == 15'h6001) is_io_btn = 1'b1; else is_io_btn = 1'b0;
        if (addressM == 15'h6002) is_io_seg = 1'b1; else is_io_seg = 1'b0;
        if (addressM == 15'h6003) is_io_led = 1'b1; else is_io_led = 1'b0;
    end

    // --- Output Logic (CPU -> Devices) ---
    
    // RAM制御
    assign ram_addr    = addressM[13:0];
    assign ram_data_in = outM;
    assign ram_we      = writeM & is_ram;

    // I/O制御 (書き込み信号生成)
    assign io_data_out = outM; // データは共通
    assign seg_we      = writeM & is_io_seg;
    assign led_we      = writeM & is_io_led;

    // --- Input Logic (Devices -> CPU) ---
    
    // マルチプレクサ: アドレスに応じて CPU に返すデータを選択
    always_comb begin
        inM = 16'h0000; // Default

        if (is_ram) begin
            inM = ram_data_out;
        end else if (is_io_sw) begin
            inM = sw_data;
        end else if (is_io_btn) begin
            inM = {11'd0, btn_data}; // 5bit button data -> 16bit padding
        end
        // Write-only registers (LED, SEG) usually return 0
    end

endmodule