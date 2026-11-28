// =============================================================================
// Module: top_fighter
// Description:
//   Top-level RTL module for Phase 1 ("White-Box First") of the 2-player 2D
//   arcade fighting game on the NI/Digilent DSDB (Zynq-7020).
//   - Divides 100 MHz board clock to 25 MHz VGA pixel clock
//   - Instantiates vga_sync and hud_renderer
//   - Implements a 3-layer priority compositor:
//       Layer 1: Arcade HUD (health bars, centered timer, super meters)
//       Layer 2: Placeholder P1 (blue) & P2 (red) fighter rectangles standing
//                on floor y = 380, each with a 2px cyan hurtbox outline
//       Layer 3: Stepped 16-bit RGB565 dusk sky gradient + dark tiled floor
//   - Forces RGB outputs to 0 during horizontal and vertical blanking
// Target: NI/Digilent DSDB (Xilinx Zynq-7020, xc7z020clg484-1)
// Standard: Synthesizable Verilog-2001
// =============================================================================

`timescale 1ns / 1ps

module top_fighter (
    input  wire       clk_100mhz,
    input  wire       rst_n,
    output reg  [4:0] vga_r,
    output reg  [5:0] vga_g,
    output reg  [4:0] vga_b,
    output reg        hsync,
    output reg        vsync
);

    // -------------------------------------------------------------------------
    // Pixel Clock Enable: 125 MHz (NI DSDB L18) -> 25 MHz (divide-by-5)
    // Uses a synchronous clock enable on the single 125 MHz clock domain so
    // Vivado sees zero derived/gated clocks and exact 25.000 MHz VGA timing.
    // -------------------------------------------------------------------------
    reg [2:0] clk_div_cnt;
    reg       pix_ce;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= 3'd0;
            pix_ce      <= 1'b0;
        end else if (clk_div_cnt == 3'd4) begin
            clk_div_cnt <= 3'd0;
            pix_ce      <= 1'b1;
        end else begin
            clk_div_cnt <= clk_div_cnt + 3'd1;
            pix_ce      <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // VGA Timing Generator (640x480 @ 60Hz)
    // -------------------------------------------------------------------------
    wire       hsync_raw;
    wire       vsync_raw;
    wire       video_active;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       frame_tick; // 1-cycle 60 Hz pulse for future Phase 2 physics

    vga_sync u_vga_sync (
        .clk          (clk_100mhz),
        .pix_ce       (pix_ce),
        .rst_n        (rst_n),
        .hsync        (hsync_raw),
        .vsync        (vsync_raw),
        .video_active (video_active),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .frame_tick   (frame_tick)
    );

    // -------------------------------------------------------------------------
    // Layer 1: Arcade HUD Renderer
    // -------------------------------------------------------------------------
    // Phase 1 placeholder values to demonstrate yellow/red bars & timer digits
    localparam [7:0] INIT_P1_HP = 8'd85;
    localparam [7:0] INIT_P2_HP = 8'd65;
    localparam [6:0] INIT_TIMER = 7'd99;

    wire        hud_active;
    wire [15:0] hud_rgb;

    hud_renderer u_hud_renderer (
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .p1_hp      (INIT_P1_HP),
        .p2_hp      (INIT_P2_HP),
        .timer_sec  (INIT_TIMER),
        .hud_active (hud_active),
        .hud_rgb    (hud_rgb)
    );

    // -------------------------------------------------------------------------
    // Layer 2: Placeholder Fighters (standing on floor y = 380)
    // -------------------------------------------------------------------------
    localparam [9:0] FLOOR_Y     = 10'd380;

    // Fighter dimensions: 64px wide x 128px tall (y = 252..379)
    localparam [9:0] FIGHTER_Y0  = 10'd252;
    localparam [9:0] FIGHTER_Y1  = FLOOR_Y;

    localparam [9:0] P1_X0       = 10'd140;
    localparam [9:0] P1_X1       = 10'd204;

    localparam [9:0] P2_X0       = 10'd436;
    localparam [9:0] P2_X1       = 10'd500;

    localparam [15:0] COL_P1_BODY = 16'h129F; // Solid arcade blue
    localparam [15:0] COL_P2_BODY = 16'hD8E3; // Solid arcade red
    localparam [15:0] COL_HURTBOX = 16'h07FF; // 2-pixel cyan hurtbox outline

    wire in_p1 = (pixel_x >= P1_X0) && (pixel_x < P1_X1) &&
                 (pixel_y >= FIGHTER_Y0) && (pixel_y < FIGHTER_Y1);
    wire in_p1_outline = in_p1 && (
        (pixel_x < (P1_X0 + 10'd2)) || (pixel_x >= (P1_X1 - 10'd2)) ||
        (pixel_y < (FIGHTER_Y0 + 10'd2)) || (pixel_y >= (FIGHTER_Y1 - 10'd2))
    );

    wire in_p2 = (pixel_x >= P2_X0) && (pixel_x < P2_X1) &&
                 (pixel_y >= FIGHTER_Y0) && (pixel_y < FIGHTER_Y1);
    wire in_p2_outline = in_p2 && (
        (pixel_x < (P2_X0 + 10'd2)) || (pixel_x >= (P2_X1 - 10'd2)) ||
        (pixel_y < (FIGHTER_Y0 + 10'd2)) || (pixel_y >= (FIGHTER_Y1 - 10'd2))
    );

    // -------------------------------------------------------------------------
    // Layer 3: Stepped Dusk Sky Gradient & Dark Tiled Floor
    // -------------------------------------------------------------------------
    // RGB565 stepped dusk sky palette (top to horizon)
    localparam [15:0] SKY_BAND_0  = 16'h0845; // Deep midnight indigo
    localparam [15:0] SKY_BAND_1  = 16'h1867; // Dark twilight blue-violet
    localparam [15:0] SKY_BAND_2  = 16'h28A9; // Twilight violet
    localparam [15:0] SKY_BAND_3  = 16'h40EB; // Dusk purple
    localparam [15:0] SKY_BAND_4  = 16'h612B; // Plum dusk
    localparam [15:0] SKY_BAND_5  = 16'h8969; // Dusty rose
    localparam [15:0] SKY_BAND_6  = 16'hB207; // Burnt dusk coral
    localparam [15:0] SKY_BAND_7  = 16'hD325; // Warm sunset orange
    localparam [15:0] SKY_BAND_8  = 16'hEC64; // Horizon amber glow

    // Floor colors
    localparam [15:0] COL_FLOOR_LINE   = 16'h5ACB; // Subtle horizon/floor edge
    localparam [15:0] COL_FLOOR_TILE_A = 16'h2125; // Dark slate tile A
    localparam [15:0] COL_FLOOR_TILE_B = 16'h18C3; // Darker slate tile B

    reg [15:0] bg_rgb;

    always @(*) begin
        if (pixel_y < FLOOR_Y) begin
            // Stepped dusk sky gradient above floor line (y = 0..379)
            if      (pixel_y < 10'd48)  bg_rgb = SKY_BAND_0;
            else if (pixel_y < 10'd96)  bg_rgb = SKY_BAND_1;
            else if (pixel_y < 10'd144) bg_rgb = SKY_BAND_2;
            else if (pixel_y < 10'd192) bg_rgb = SKY_BAND_3;
            else if (pixel_y < 10'd240) bg_rgb = SKY_BAND_4;
            else if (pixel_y < 10'd280) bg_rgb = SKY_BAND_5;
            else if (pixel_y < 10'd316) bg_rgb = SKY_BAND_6;
            else if (pixel_y < 10'd350) bg_rgb = SKY_BAND_7;
            else                        bg_rgb = SKY_BAND_8;
        end else if (pixel_y < (FLOOR_Y + 10'd2)) begin
            // 2-pixel floor horizon trim at y = 380..381
            bg_rgb = COL_FLOOR_LINE;
        end else begin
            // Dark tiled floor (32x16 checkerboard pattern) below y = 380
            if (pixel_x[5] ^ pixel_y[4]) begin
                bg_rgb = COL_FLOOR_TILE_A;
            end else begin
                bg_rgb = COL_FLOOR_TILE_B;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Multi-Layer Priority Compositor
    // -------------------------------------------------------------------------
    reg [15:0] comp_rgb;

    always @(*) begin
        if (hud_active) begin
            // Layer 1: Arcade HUD
            comp_rgb = hud_rgb;
        end else if (in_p1) begin
            // Layer 2: Player 1 placeholder fighter + cyan hurtbox outline
            comp_rgb = in_p1_outline ? COL_HURTBOX : COL_P1_BODY;
        end else if (in_p2) begin
            // Layer 2: Player 2 placeholder fighter + cyan hurtbox outline
            comp_rgb = in_p2_outline ? COL_HURTBOX : COL_P2_BODY;
        end else begin
            // Layer 3: Dusk sky & tiled floor background
            comp_rgb = bg_rgb;
        end
    end

    // -------------------------------------------------------------------------
    // Registered VGA Outputs (RGB strictly forced to 0 during blanking)
    // -------------------------------------------------------------------------
    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 5'd0;
            vga_g <= 6'd0;
            vga_b <= 5'd0;
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (pix_ce) begin
            hsync <= hsync_raw;
            vsync <= vsync_raw;
            if (video_active) begin
                vga_r <= comp_rgb[15:11];
                vga_g <= comp_rgb[10:5];
                vga_b <= comp_rgb[4:0];
            end else begin
                vga_r <= 5'd0;
                vga_g <= 6'd0;
                vga_b <= 5'd0;
            end
        end
    end

endmodule

