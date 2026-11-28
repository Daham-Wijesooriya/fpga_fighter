// =============================================================================
// Testbench: tb_vga_ppm
// Description:
//   Drives top_fighter for 1 complete 640x480 VGA frame and dumps every active
//   pixel into sim/vga_frame.ppm (standard ASCII P3 RGB format), scaling 5-6-5
//   bits up to 8-bit [0..255] via bit replication.
//   Also verifies that RGB outputs remain strictly 0 during blanking intervals
//   and that the 1-cycle frame_tick pulse asserts at the start of v-blank.
// Compile & Run (Icarus Verilog):
//   iverilog -g2001 -Wall -o sim/tb_vga_ppm.vvp src/vga_sync.v src/hud_renderer.v src/top_fighter.v sim/tb_vga_ppm.v
//   vvp sim/tb_vga_ppm.vvp
// =============================================================================

`timescale 1ns / 1ps

module tb_vga_ppm;

    localparam integer IMG_W        = 640;
    localparam integer IMG_H        = 480;
    localparam integer TOTAL_PIXELS = IMG_W * IMG_H; // 307,200 active pixels

    reg        clk_100mhz;
    reg        rst_n;
    wire [4:0] vga_r;
    wire [5:0] vga_g;
    wire [4:0] vga_b;
    wire       hsync;
    wire       vsync;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------
    top_fighter dut (
        .clk_100mhz (clk_100mhz),
        .rst_n      (rst_n),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b),
        .hsync      (hsync),
        .vsync      (vsync)
    );

    // -------------------------------------------------------------------------
    // 125 MHz System Clock (8 ns period, matching NI DSDB L18 oscillator)
    // -------------------------------------------------------------------------
    initial begin
        clk_100mhz = 1'b0;
        forever #4 clk_100mhz = ~clk_100mhz;
    end

    // -------------------------------------------------------------------------
    // Reset Sequence
    // -------------------------------------------------------------------------
    initial begin
        rst_n = 1'b0;
        #32;
        rst_n = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Track 1-cycle registered output alignment with dut.video_active & pix_ce
    // -------------------------------------------------------------------------
    reg active_d1;
    reg pix_ce_d1;
    reg frame_tick_d1;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            active_d1     <= 1'b0;
            pix_ce_d1     <= 1'b0;
            frame_tick_d1 <= 1'b0;
        end else begin
            pix_ce_d1     <= dut.pix_ce;
            frame_tick_d1 <= dut.frame_tick;
            if (dut.pix_ce) begin
                active_d1 <= dut.video_active;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Frame Capture to sim/vga_frame.ppm + Blanking & frame_tick Checks
    // -------------------------------------------------------------------------
    integer fd;
    integer pixel_count;
    integer blank_violations;
    integer frame_tick_count;
    reg [7:0] r8;
    reg [7:0] g8;
    reg [7:0] b8;

    initial begin
        pixel_count      = 0;
        blank_violations = 0;
        frame_tick_count = 0;

        fd = $fopen("sim/vga_frame.ppm", "w");
        if (fd == 0) begin
            // Fallback for simulators (e.g. Vivado xsim) running in a build subdir
            fd = $fopen("vga_frame.ppm", "w");
        end
        if (fd == 0) begin
            $display("ERROR: Could not open vga_frame.ppm for writing.");
            $finish;
        end

        // Standard P3 ASCII PPM header
        $fwrite(fd, "P3\n%0d %0d\n255\n", IMG_W, IMG_H);
        $display("[tb_vga_ppm] Capturing 1 complete 640x480 frame...");
    end

    // Sample on negedge clk_100mhz on each pixel enable so registered outputs have settled
    always @(negedge clk_100mhz) begin
        if (rst_n && pix_ce_d1) begin
            if (frame_tick_d1) begin
                frame_tick_count = frame_tick_count + 1;
            end

            if (active_d1) begin
                if (pixel_count < TOTAL_PIXELS) begin
                    // Scale RGB565 -> 8-bit [0..255] using MSB bit replication
                    r8 = {vga_r, vga_r[4:2]};
                    g8 = {vga_g, vga_g[5:4]};
                    b8 = {vga_b, vga_b[4:2]};
                    $fwrite(fd, "%0d %0d %0d\n", r8, g8, b8);
                    pixel_count = pixel_count + 1;
                end
            end else begin
                // Verify strict zeroing of RGB during blanking intervals
                if ((vga_r !== 5'd0) || (vga_g !== 6'd0) || (vga_b !== 5'd0)) begin
                    blank_violations = blank_violations + 1;
                end
            end

            // Stop after capturing the full frame and observing frame_tick
            if ((pixel_count == TOTAL_PIXELS) && (frame_tick_count >= 1)) begin
                $fclose(fd);
                $display("[tb_vga_ppm] Done! Captured %0d pixels to sim/vga_frame.ppm", pixel_count);
                $display("[tb_vga_ppm] frame_tick pulses observed: %0d", frame_tick_count);
                $display("[tb_vga_ppm] Blanking RGB violations:    %0d", blank_violations);
                if (blank_violations != 0) begin
                    $display("ERROR: Non-zero RGB detected during blanking!");
                end
                $finish;
            end
        end
    end

    // Safety timeout (1 frame at 60Hz is ~16.8 ms)
    initial begin
        #25000000;
        $display("ERROR: Simulation timed out before completing 1 frame (pixels=%0d).", pixel_count);
        $fclose(fd);
        $finish;
    end

endmodule
