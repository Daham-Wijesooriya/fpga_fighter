// =============================================================================
// Module: vga_sync
// Description:
//   Standard 640x480 @ 60Hz VGA timing generator driven by a 25 MHz pixel clock.
//   Total horizontal count = 800 pixels, total vertical count = 525 lines.
//   Generates active-low HSYNC/VSYNC, active-video mask, pixel coordinates,
//   and a single-cycle frame_tick pulse at the start of vertical blanking.
// Target: NI/Digilent DSDB (Xilinx Zynq-7020, xc7z020clg484-1)
// Standard: Synthesizable Verilog-2001
// =============================================================================

`timescale 1ns / 1ps

module vga_sync (
    input  wire       clk,
    input  wire       pix_ce,
    input  wire       rst_n,
    output wire       hsync,
    output wire       vsync,
    output wire       video_active,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y,
    output wire       frame_tick
);

    // -------------------------------------------------------------------------
    // Horizontal timing parameters (pixels)
    // -------------------------------------------------------------------------
    localparam [9:0] H_VISIBLE   = 10'd640;
    localparam [9:0] H_FRONT     = 10'd16;
    localparam [9:0] H_SYNC      = 10'd96;
    localparam [9:0] H_BACK      = 10'd48;
    localparam [9:0] H_TOTAL     = 10'd800; // 640 + 16 + 96 + 48

    localparam [9:0] H_SYNC_START = H_VISIBLE + H_FRONT;          // 656
    localparam [9:0] H_SYNC_END   = H_VISIBLE + H_FRONT + H_SYNC; // 752

    // -------------------------------------------------------------------------
    // Vertical timing parameters (lines)
    // -------------------------------------------------------------------------
    localparam [9:0] V_VISIBLE   = 10'd480;
    localparam [9:0] V_FRONT     = 10'd10;
    localparam [9:0] V_SYNC      = 10'd2;
    localparam [9:0] V_BACK      = 10'd33;
    localparam [9:0] V_TOTAL     = 10'd525; // 480 + 10 + 2 + 33

    localparam [9:0] V_SYNC_START = V_VISIBLE + V_FRONT;          // 490
    localparam [9:0] V_SYNC_END   = V_VISIBLE + V_FRONT + V_SYNC; // 492

    // -------------------------------------------------------------------------
    // Horizontal and vertical counters
    // -------------------------------------------------------------------------
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else if (pix_ce) begin
            if (h_cnt == (H_TOTAL - 10'd1)) begin
                h_cnt <= 10'd0;
                if (v_cnt == (V_TOTAL - 10'd1)) begin
                    v_cnt <= 10'd0;
                end else begin
                    v_cnt <= v_cnt + 10'd1;
                end
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Combinational VGA timing outputs (aligned to current h_cnt / v_cnt)
    // -------------------------------------------------------------------------
    // Active-low sync pulses per VESA 640x480 @ 60Hz specification
    assign hsync        = ~((h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END));
    assign vsync        = ~((v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END));

    // Active display region: x in [0..639], y in [0..479]
    assign video_active = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

    // Current pixel coordinates (valid during video_active == 1'b1)
    assign pixel_x      = h_cnt;
    assign pixel_y      = v_cnt;

    // Single-cycle 60 Hz pulse at the very first pixel of vertical blanking
    assign frame_tick   = pix_ce && (h_cnt == 10'd0) && (v_cnt == V_VISIBLE);

endmodule

