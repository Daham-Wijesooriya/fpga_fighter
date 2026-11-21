// =============================================================================
// Module: hud_renderer
// Description:
//   Pure combinational arcade HUD renderer (640x480, 16-bit RGB565).
//   Draws:
//     - P1 & P2 yellow/red health bars with 2px white borders at the top
//       (HP range 0..100, draining toward the center timer like classic fighters)
//     - Centered timer box with 2-digit 7-segment countdown display (00..99)
//     - P1 & P2 bottom super-meter bars with 2px white borders
// Target: NI/Digilent DSDB (Xilinx Zynq-7020, xc7z020clg484-1)
// Standard: Synthesizable Verilog-2001
// =============================================================================

`timescale 1ns / 1ps

module hud_renderer (
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [7:0]  p1_hp,      // 0..100
    input  wire [7:0]  p2_hp,      // 0..100
    input  wire [6:0]  timer_sec,  // 0..99
    output reg         hud_active,
    output reg  [15:0] hud_rgb
);

    // -------------------------------------------------------------------------
    // RGB565 Color Palette
    // -------------------------------------------------------------------------
    localparam [15:0] COL_WHITE      = 16'hFFFF; // Borders & accents
    localparam [15:0] COL_HP_YELLOW  = 16'hFFE0; // Remaining HP fill
    localparam [15:0] COL_HP_RED     = 16'hC800; // Lost HP / damage background
    localparam [15:0] COL_TIMER_BG   = 16'h1084; // Dark navy timer box
    localparam [15:0] COL_TIMER_DIG  = 16'hFEA0; // Bright gold timer digits
    localparam [15:0] COL_SUPER_FILL = 16'h05FF; // Arcade cyan-blue super meter
    localparam [15:0] COL_SUPER_BG   = 16'h18E3; // Empty super meter background
    localparam [15:0] COL_SUPER_TICK = 16'h4A69; // Subtle meter segment divider

    // -------------------------------------------------------------------------
    // HUD Layout Coordinates (640x480)
    // -------------------------------------------------------------------------
    // Top Health Bars: outer width 204 (inner 200), outer height 24 (inner 20)
    localparam [9:0] HP_OUT_Y0     = 10'd24;
    localparam [9:0] HP_OUT_Y1     = 10'd48;
    localparam [9:0] HP_IN_Y0      = 10'd26;
    localparam [9:0] HP_IN_Y1      = 10'd46;

    localparam [9:0] P1_HP_OUT_X0  = 10'd40;
    localparam [9:0] P1_HP_OUT_X1  = 10'd244;
    localparam [9:0] P1_HP_IN_X0   = 10'd42;
    localparam [9:0] P1_HP_IN_X1   = 10'd242;

    localparam [9:0] P2_HP_OUT_X0  = 10'd396;
    localparam [9:0] P2_HP_OUT_X1  = 10'd600;
    localparam [9:0] P2_HP_IN_X0   = 10'd398;
    localparam [9:0] P2_HP_IN_X1   = 10'd598;

    // Centered Timer Box: x in [290..349] (60px), y in [18..53] (36px)
    localparam [9:0] TMR_OUT_X0    = 10'd290;
    localparam [9:0] TMR_OUT_X1    = 10'd350;
    localparam [9:0] TMR_OUT_Y0    = 10'd18;
    localparam [9:0] TMR_OUT_Y1    = 10'd54;
    localparam [9:0] TMR_IN_X0     = 10'd292;
    localparam [9:0] TMR_IN_X1     = 10'd348;
    localparam [9:0] TMR_IN_Y0     = 10'd20;
    localparam [9:0] TMR_IN_Y1     = 10'd52;

    // Timer 7-segment digit boxes (16x24 each)
    localparam [9:0] DIG_TENS_X0   = 10'd300;
    localparam [9:0] DIG_TENS_X1   = 10'd316;
    localparam [9:0] DIG_ONES_X0   = 10'd324;
    localparam [9:0] DIG_ONES_X1   = 10'd340;
    localparam [9:0] DIG_Y0        = 10'd24;
    localparam [9:0] DIG_Y1        = 10'd48;

    // Bottom Super-Meter Bars: outer width 164 (inner 160), outer height 18 (inner 14)
    localparam [9:0] SUP_OUT_Y0    = 10'd438;
    localparam [9:0] SUP_OUT_Y1    = 10'd456;
    localparam [9:0] SUP_IN_Y0     = 10'd440;
    localparam [9:0] SUP_IN_Y1     = 10'd454;

    localparam [9:0] P1_SUP_OUT_X0 = 10'd40;
    localparam [9:0] P1_SUP_OUT_X1 = 10'd204;
    localparam [9:0] P1_SUP_IN_X0  = 10'd42;
    localparam [9:0] P1_SUP_IN_X1  = 10'd202;

    localparam [9:0] P2_SUP_OUT_X0 = 10'd436;
    localparam [9:0] P2_SUP_OUT_X1 = 10'd600;
    localparam [9:0] P2_SUP_IN_X0  = 10'd438;
    localparam [9:0] P2_SUP_IN_X1  = 10'd598;

    // Phase 1 static placeholder super-meter fill widths (out of 160px)
    localparam [9:0] P1_SUP_FILL_W = 10'd112;
    localparam [9:0] P2_SUP_FILL_W = 10'd80;

    // -------------------------------------------------------------------------
    // Clamped HP -> pixel width (0..100 scaled by 2 => 0..200 px)
    // -------------------------------------------------------------------------
    wire [7:0] p1_hp_clamped = (p1_hp > 8'd100) ? 8'd100 : p1_hp;
    wire [7:0] p2_hp_clamped = (p2_hp > 8'd100) ? 8'd100 : p2_hp;
    wire [9:0] p1_fill_w     = {1'b0, p1_hp_clamped, 1'b0};
    wire [9:0] p2_fill_w     = {1'b0, p2_hp_clamped, 1'b0};

    // -------------------------------------------------------------------------
    // Combinational BCD split for timer_sec (0..99)
    // -------------------------------------------------------------------------
    wire [6:0] timer_clamped = (timer_sec > 7'd99) ? 7'd99 : timer_sec;
    reg  [3:0] timer_tens;
    reg  [6:0] timer_ones_full;
    wire [3:0] timer_ones = timer_ones_full[3:0];

    always @(*) begin
        if (timer_clamped >= 7'd90) begin
            timer_tens      = 4'd9;
            timer_ones_full = timer_clamped - 7'd90;
        end else if (timer_clamped >= 7'd80) begin
            timer_tens      = 4'd8;
            timer_ones_full = timer_clamped - 7'd80;
        end else if (timer_clamped >= 7'd70) begin
            timer_tens      = 4'd7;
            timer_ones_full = timer_clamped - 7'd70;
        end else if (timer_clamped >= 7'd60) begin
            timer_tens      = 4'd6;
            timer_ones_full = timer_clamped - 7'd60;
        end else if (timer_clamped >= 7'd50) begin
            timer_tens      = 4'd5;
            timer_ones_full = timer_clamped - 7'd50;
        end else if (timer_clamped >= 7'd40) begin
            timer_tens      = 4'd4;
            timer_ones_full = timer_clamped - 7'd40;
        end else if (timer_clamped >= 7'd30) begin
            timer_tens      = 4'd3;
            timer_ones_full = timer_clamped - 7'd30;
        end else if (timer_clamped >= 7'd20) begin
            timer_tens      = 4'd2;
            timer_ones_full = timer_clamped - 7'd20;
        end else if (timer_clamped >= 7'd10) begin
            timer_tens      = 4'd1;
            timer_ones_full = timer_clamped - 7'd10;
        end else begin
            timer_tens      = 4'd0;
            timer_ones_full = timer_clamped;
        end
    end

    // -------------------------------------------------------------------------
    // 7-Segment Digit Helper Functions (16x24 pixel glyph)
    // -------------------------------------------------------------------------
    // Returns {a, b, c, d, e, f, g} active-high segment mask
    function [6:0] seg7_mask;
        input [3:0] digit;
        begin
            case (digit)
                4'd0:    seg7_mask = 7'b1111110;
                4'd1:    seg7_mask = 7'b0110000;
                4'd2:    seg7_mask = 7'b1101101;
                4'd3:    seg7_mask = 7'b1111001;
                4'd4:    seg7_mask = 7'b0110011;
                4'd5:    seg7_mask = 7'b1011011;
                4'd6:    seg7_mask = 7'b1011111;
                4'd7:    seg7_mask = 7'b1110000;
                4'd8:    seg7_mask = 7'b1111111;
                4'd9:    seg7_mask = 7'b1111011;
                default: seg7_mask = 7'b0000000;
            endcase
        end
    endfunction

    function seg7_pixel_on;
        input [3:0] digit;
        input [4:0] lx; // 0..15
        input [4:0] ly; // 0..23
        reg   [6:0] m;
        begin
            m = seg7_mask(digit);
            seg7_pixel_on =
                (m[6] && (ly < 5'd4))                          || // a: top
                (m[5] && (lx >= 5'd12) && (ly < 5'd13))        || // b: top-right
                (m[4] && (lx >= 5'd12) && (ly >= 5'd11))       || // c: bottom-right
                (m[3] && (ly >= 5'd20))                        || // d: bottom
                (m[2] && (lx < 5'd4)   && (ly >= 5'd11))       || // e: bottom-left
                (m[1] && (lx < 5'd4)   && (ly < 5'd13))        || // f: top-left
                (m[0] && (ly >= 5'd10) && (ly < 5'd14));          // g: middle
        end
    endfunction

    // Local coordinates inside tens and ones digit boxes
    wire in_tens_dig = (pixel_x >= DIG_TENS_X0) && (pixel_x < DIG_TENS_X1) &&
                       (pixel_y >= DIG_Y0)      && (pixel_y < DIG_Y1);
    wire in_ones_dig = (pixel_x >= DIG_ONES_X0) && (pixel_x < DIG_ONES_X1) &&
                       (pixel_y >= DIG_Y0)      && (pixel_y < DIG_Y1);

    wire [9:0] tens_lx_full = pixel_x - DIG_TENS_X0;
    wire [9:0] ones_lx_full = pixel_x - DIG_ONES_X0;
    wire [9:0] dig_ly_full  = pixel_y - DIG_Y0;

    wire tens_px_on = in_tens_dig && seg7_pixel_on(timer_tens, tens_lx_full[4:0], dig_ly_full[4:0]);
    wire ones_px_on = in_ones_dig && seg7_pixel_on(timer_ones, ones_lx_full[4:0], dig_ly_full[4:0]);

    // -------------------------------------------------------------------------
    // Region Decode Wires
    // -------------------------------------------------------------------------
    wire in_p1_hp_out  = (pixel_x >= P1_HP_OUT_X0)  && (pixel_x < P1_HP_OUT_X1) &&
                         (pixel_y >= HP_OUT_Y0)     && (pixel_y < HP_OUT_Y1);
    wire in_p1_hp_in   = (pixel_x >= P1_HP_IN_X0)   && (pixel_x < P1_HP_IN_X1) &&
                         (pixel_y >= HP_IN_Y0)      && (pixel_y < HP_IN_Y1);

    wire in_p2_hp_out  = (pixel_x >= P2_HP_OUT_X0)  && (pixel_x < P2_HP_OUT_X1) &&
                         (pixel_y >= HP_OUT_Y0)     && (pixel_y < HP_OUT_Y1);
    wire in_p2_hp_in   = (pixel_x >= P2_HP_IN_X0)   && (pixel_x < P2_HP_IN_X1) &&
                         (pixel_y >= HP_IN_Y0)      && (pixel_y < HP_IN_Y1);

    wire in_tmr_out    = (pixel_x >= TMR_OUT_X0)    && (pixel_x < TMR_OUT_X1) &&
                         (pixel_y >= TMR_OUT_Y0)    && (pixel_y < TMR_OUT_Y1);
    wire in_tmr_in     = (pixel_x >= TMR_IN_X0)     && (pixel_x < TMR_IN_X1) &&
                         (pixel_y >= TMR_IN_Y0)     && (pixel_y < TMR_IN_Y1);

    wire in_p1_sup_out = (pixel_x >= P1_SUP_OUT_X0) && (pixel_x < P1_SUP_OUT_X1) &&
                         (pixel_y >= SUP_OUT_Y0)    && (pixel_y < SUP_OUT_Y1);
    wire in_p1_sup_in  = (pixel_x >= P1_SUP_IN_X0)  && (pixel_x < P1_SUP_IN_X1) &&
                         (pixel_y >= SUP_IN_Y0)     && (pixel_y < SUP_IN_Y1);

    wire in_p2_sup_out = (pixel_x >= P2_SUP_OUT_X0) && (pixel_x < P2_SUP_OUT_X1) &&
                         (pixel_y >= SUP_OUT_Y0)    && (pixel_y < SUP_OUT_Y1);
    wire in_p2_sup_in  = (pixel_x >= P2_SUP_IN_X0)  && (pixel_x < P2_SUP_IN_X1) &&
                         (pixel_y >= SUP_IN_Y0)     && (pixel_y < SUP_IN_Y1);

    // -------------------------------------------------------------------------
    // Combinational HUD Pixel Output
    // -------------------------------------------------------------------------
    always @(*) begin
        hud_active = 1'b0;
        hud_rgb    = 16'h0000;

        if (in_p1_hp_out) begin
            hud_active = 1'b1;
            if (!in_p1_hp_in) begin
                hud_rgb = COL_WHITE;
            end else if (pixel_x >= (P1_HP_IN_X1 - p1_fill_w)) begin
                // P1 health fills outward from center (right to left)
                hud_rgb = COL_HP_YELLOW;
            end else begin
                hud_rgb = COL_HP_RED;
            end
        end else if (in_p2_hp_out) begin
            hud_active = 1'b1;
            if (!in_p2_hp_in) begin
                hud_rgb = COL_WHITE;
            end else if (pixel_x < (P2_HP_IN_X0 + p2_fill_w)) begin
                // P2 health fills outward from center (left to right)
                hud_rgb = COL_HP_YELLOW;
            end else begin
                hud_rgb = COL_HP_RED;
            end
        end else if (in_tmr_out) begin
            hud_active = 1'b1;
            if (!in_tmr_in) begin
                hud_rgb = COL_WHITE;
            end else if (tens_px_on || ones_px_on) begin
                hud_rgb = COL_TIMER_DIG;
            end else begin
                hud_rgb = COL_TIMER_BG;
            end
        end else if (in_p1_sup_out) begin
            hud_active = 1'b1;
            if (!in_p1_sup_in) begin
                hud_rgb = COL_WHITE;
            end else if ((pixel_x == 10'd82) || (pixel_x == 10'd122) || (pixel_x == 10'd162)) begin
                hud_rgb = COL_SUPER_TICK;
            end else if (pixel_x < (P1_SUP_IN_X0 + P1_SUP_FILL_W)) begin
                hud_rgb = COL_SUPER_FILL;
            end else begin
                hud_rgb = COL_SUPER_BG;
            end
        end else if (in_p2_sup_out) begin
            hud_active = 1'b1;
            if (!in_p2_sup_in) begin
                hud_rgb = COL_WHITE;
            end else if ((pixel_x == 10'd478) || (pixel_x == 10'd518) || (pixel_x == 10'd558)) begin
                hud_rgb = COL_SUPER_TICK;
            end else if (pixel_x >= (P2_SUP_IN_X1 - P2_SUP_FILL_W)) begin
                hud_rgb = COL_SUPER_FILL;
            end else begin
                hud_rgb = COL_SUPER_BG;
            end
        end
    end

endmodule
