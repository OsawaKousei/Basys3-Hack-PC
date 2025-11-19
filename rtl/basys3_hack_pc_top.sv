`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: basys3_hack_pc_top
// Description: Top Level Module for Basys3 Hack PC
//              Integrates CPU, Memories, and I/O Peripherals.
//////////////////////////////////////////////////////////////////////////////////

module basys3_hack_pc_top(
    input  logic        clk,    // 100MHz System Clock
    input  logic        btnC,   // Reset (Center Button)
    input  logic        btnU,
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnD,
    input  logic [15:0] sw,     // Slide Switches
    output logic [15:0] led,    // LEDs
    output logic [6:0]  seg,    // 7-Segment Segments
    output logic [3:0]  an,     // 7-Segment Anodes
    output logic        dp      // Decimal Point
    );

    // ---------------------------------------------------------
    // 1. Clock & Reset Generation
    // ---------------------------------------------------------
    // 今回は 100MHz をそのままシステムクロックとして使用します。
    // タイミング制約(XDC)で 100MHz (Period 10ns) を定義することを忘れずに。
    
    // 100MHz -> 12.5MHz 程度の生成
    logic [2:0] clk_cnt;
    always_ff @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
    end
    logic sys_clk;
    assign sys_clk = clk_cnt[2]; // 100MHz / 8 = 12.5MHz
    logic sys_reset;

    // リセット信号の同期化 (btnC -> sys_reset)
    // btnC は非同期入力なので、2段FFを通す
    logic reset_sync_0, reset_sync_1;
    always_ff @(posedge sys_clk) begin
        reset_sync_0 <= btnC;
        reset_sync_1 <= reset_sync_0;
    end
    assign sys_reset = reset_sync_1;


    // ---------------------------------------------------------
    // 2. Input Synchronization & Debouncing
    // ---------------------------------------------------------
    
    // --- Buttons ---
    logic [4:0] raw_btns;
    logic [4:0] clean_btns; // {btnD, btnR, btnL, btnU, btnC} (Order doesn't matter much here, mapping does)
    
    assign raw_btns = {btnD, btnR, btnL, btnU, btnC};
    
    // Debouncer Instances (for each button)
    // Center button is used for Reset, but we also map it to I/O for software use?
    // Usually Reset is hardware only, but here we map it to I/O space too if not pressed?
    // Note: If btnC is held for Reset, CPU is reset. Software won't see it until released.
    // Let's map U, L, R, D, C to bit 0-4.
    
    // Debouncer is instantiated 5 times
    genvar i;
    generate
        for (i = 0; i < 5; i = i + 1) begin : btn_debounce_gen
            debouncer u_db (
                .clk     (sys_clk),
                .reset   (sys_reset), // Debouncer itself needs reset?
                .btn_in  (raw_btns[i]),
                .btn_out (clean_btns[i])
            );
        end
    endgenerate

    // --- Switches ---
    // Switches are static, but crossing clock domains requires 2-FF synchronizer.
    logic [15:0] sw_sync_0, sw_sync_1;
    
    always_ff @(posedge sys_clk) begin
        sw_sync_0 <= sw;
        sw_sync_1 <= sw_sync_0;
    end
    
    logic [15:0] clean_sw;
    assign clean_sw = sw_sync_1;


    // ---------------------------------------------------------
    // 3. Internal Signals & Registers
    // ---------------------------------------------------------
    
    // CPU Bus
    logic [14:0] pc;
    logic [15:0] instruction;
    logic [14:0] addressM;
    logic        writeM;
    logic [15:0] outM;
    logic [15:0] inM;
    
    // RAM Interface
    logic [13:0] ram_addr;
    logic [15:0] ram_data_in;
    logic [15:0] ram_data_out;
    logic        ram_we;
    
    // I/O Interface Signals
    logic        led_we;
    logic        seg_we;
    logic [15:0] io_data_to_dev; // Data from CPU to IO
    
    // I/O Registers (Hardware registers to hold state)
    logic [15:0] led_reg;
    logic [15:0] seg_data_reg;

    // ---------------------------------------------------------
    // 4. I/O Register Logic
    // ---------------------------------------------------------

    // LED Register (0x6003)
    always_ff @(posedge sys_clk) begin
        if (sys_reset) begin
            led_reg <= 16'h0000;
        end else if (led_we) begin
            led_reg <= io_data_to_dev;
        end
    end
    assign led = led_reg;

    // 7-Segment Data Register (0x6002)
    always_ff @(posedge sys_clk) begin
        if (sys_reset) begin
            seg_data_reg <= 16'h0000;
        end else if (seg_we) begin
            seg_data_reg <= io_data_to_dev;
        end
    end
    
    assign dp = 1'b1; // Decimal point OFF (Active Low on some boards, check constraint. Usually 1=OFF for common anode? No, Common Anode: 0=ON. Basys3 DP is active low.)
    // Basys 3 Ref Man: "The anodes... are tied together... but the LED cathodes remain separate". 
    // "To illuminate a segment, the anode should be driven high while the cathode is driven low." -> But transistors invert anodes.
    // Result: Anodes: 0=ON. Segments (Cathodes): 0=ON.
    // So DP=1 means OFF.


    // ---------------------------------------------------------
    // 5. Module Instantiation
    // ---------------------------------------------------------

    // ROM (Instruction Memory)
    // Note: Point to your final .hack file here or use a default one.
    hack_rom #(
        .INIT_FILE("calculator.hack") // Change to your desired .hack file
    ) u_rom (
        .clk         (sys_clk),
        .addr        (pc),
        .instruction (instruction)
    );

    // CPU
    hack_cpu u_cpu (
        .clk         (sys_clk),
        .reset       (sys_reset),
        .instruction (instruction),
        .inM         (inM),
        .outM        (outM),
        .writeM      (writeM),
        .addressM    (addressM),
        .pc          (pc)
    );

    // RAM
    hack_ram u_ram (
        .clk         (sys_clk),
        .we          (ram_we),
        .addr        (ram_addr),
        .d_in        (ram_data_in),
        .d_out       (ram_data_out)
    );

    // Memory I/O Bridge
    memory_io_bridge u_bridge (
        .addressM    (addressM),
        .outM        (outM),
        .writeM      (writeM),
        .inM         (inM),
        
        .ram_addr    (ram_addr),
        .ram_data_in (ram_data_in),
        .ram_we      (ram_we),
        .ram_data_out(ram_data_out),
        
        .sw_data     (clean_sw),
        .btn_data    (clean_btns), // {D, R, L, U, C}
        .seg_we      (seg_we),
        .led_we      (led_we),
        .io_data_out (io_data_to_dev)
    );

    // 7-Segment Driver
    seven_seg_driver u_seg_driver (
        .clk         (sys_clk),
        .reset       (sys_reset),
        .data_in     (seg_data_reg), // Display content of the register
        .seg         (seg),
        .an          (an)
    );

endmodule