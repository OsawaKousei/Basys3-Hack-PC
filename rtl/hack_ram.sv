`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_ram
// Description: Data Memory for Hack CPU (16K Words)
//////////////////////////////////////////////////////////////////////////////////

module hack_ram #(
    parameter int ADDR_WIDTH = 14 // 16K words (0x0000 - 0x3FFF)
) (
    input  logic                  clk,
    input  logic                  we,       // Write Enable
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [15:0]           d_in,
    output logic [15:0]           d_out
);

    // メモリ配列定義 (16K x 16bit)
    // Vivado will infer Block RAM here 
    (* ram_style = "block" *)
    logic [15:0] ram_array [0:(2**ADDR_WIDTH)-1];

    // 同期書き込み・読み出し
    always_ff @(posedge clk) begin
        if (we) begin
            ram_array[addr] <= d_in;
        end
        d_out <= ram_array[addr]; // Read-First mode usually implied
    end

endmodule