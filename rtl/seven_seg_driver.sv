`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: seven_seg_driver
// Description: 16-bit Binary to 4-digit Decimal Display Driver
//              Fixed logic placement for Synthesis compatibility.
//////////////////////////////////////////////////////////////////////////////////

module seven_seg_driver(
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] data_in,   // 表示したい数値 (Binary)
    output logic [6:0]  seg,       // セグメント信号 (Active Low: CA-CG)
    output logic [3:0]  an         // 桁選択信号 (Active Low: AN0-AN3)
    );

    // --- 1. Binary to BCD Conversion (Double Dabble) ---
    logic [3:0] bcd_thousands;
    logic [3:0] bcd_hundreds;
    logic [3:0] bcd_tens;
    logic [3:0] bcd_units;
    
    // logic変数をalways_combの外で宣言（合成ツール互換性のため）
    logic [19:0] scratch; 
    logic [15:0] bin;
    integer i;

    always_comb begin
        scratch = '0;
        bin = data_in;
        
        for (i = 0; i < 16; i = i + 1) begin
            // Shift Left
            scratch = {scratch[18:0], bin[15]};
            bin = {bin[14:0], 1'b0};
            
            // Add 3 condition (skip last shift)
            if (i < 15) begin
                if (scratch[3:0] > 4)   scratch[3:0]   = scratch[3:0] + 4'd3;
                if (scratch[7:4] > 4)   scratch[7:4]   = scratch[7:4] + 4'd3;
                if (scratch[11:8] > 4)  scratch[11:8]  = scratch[11:8] + 4'd3;
                if (scratch[15:12] > 4) scratch[15:12] = scratch[15:12] + 4'd3;
            end
        end
        
        bcd_units     = scratch[3:0];
        bcd_tens      = scratch[7:4];
        bcd_hundreds  = scratch[11:8];
        bcd_thousands = scratch[15:12];
    end

    // --- 2. Dynamic Refresh Controller ---
    logic [16:0] refresh_counter;
    logic [1:0]  digit_sel;
    
    always_ff @(posedge clk) begin
        if (reset) refresh_counter <= '0;
        else       refresh_counter <= refresh_counter + 1;
    end
    
    assign digit_sel = refresh_counter[16:15];

    // --- 3. Digit & Segment Control ---
    logic [3:0] current_bcd;
    
    // Anode & Data Selection
    always_comb begin
        an = 4'b1111; 
        current_bcd = 4'b0000; // Default assignment to prevent latch
        
        case (digit_sel)
            2'b00: begin
                an = 4'b1110; 
                current_bcd = bcd_units;
            end
            2'b01: begin
                an = 4'b1101;
                current_bcd = bcd_tens;
            end
            2'b10: begin
                an = 4'b1011;
                current_bcd = bcd_hundreds;
            end
            2'b11: begin
                an = 4'b0111;
                current_bcd = bcd_thousands;
            end
            default: begin
                an = 4'b1111;
                current_bcd = 4'b0000;
            end
        endcase
    end
    
    // Segment Decoder
    always_comb begin
        case (current_bcd)
            4'h0:    seg = 7'b1000000; 
            4'h1:    seg = 7'b1111001; 
            4'h2:    seg = 7'b0100100; 
            4'h3:    seg = 7'b0110000; 
            4'h4:    seg = 7'b0011001; 
            4'h5:    seg = 7'b0010010; 
            4'h6:    seg = 7'b0000010; 
            4'h7:    seg = 7'b1111000; 
            4'h8:    seg = 7'b0000000; 
            4'h9:    seg = 7'b0010000; 
            default: seg = 7'b1111111; 
        endcase
    end

endmodule