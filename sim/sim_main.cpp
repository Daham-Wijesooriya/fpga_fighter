#include "Vtop_fighter.h"
#include "verilated.h"
#include <SDL.h>
#include <cstdint>
#include <iostream>


static constexpr int H_RES = 640;
static constexpr int V_RES = 480;
static constexpr int H_BACK_PORCH = 48;
static constexpr int V_BACK_PORCH = 33;
static constexpr int CLK_PER_PIXEL = 5; // 125 MHz / 25 MHz = 5

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    std::cerr << "SDL_Init failed: " << SDL_GetError() << "\n";
    return 1;
  }

  SDL_Window *window = SDL_CreateWindow(
      "NI DSDB FPGA - 640x480 VGA Simulator", SDL_WINDOWPOS_CENTERED,
      SDL_WINDOWPOS_CENTERED, H_RES, V_RES, SDL_WINDOW_SHOWN);
  SDL_Renderer *renderer =
      SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
  SDL_Texture *texture =
      SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                        SDL_TEXTUREACCESS_STREAMING, H_RES, V_RES);

  uint32_t framebuffer[H_RES * V_RES] = {0};
  Vtop_fighter *top = new Vtop_fighter;

  auto tick = [&]() {
    top->clk_100mhz = 0;
    top->eval();
    top->clk_100mhz = 1;
    top->eval();
  };

  // Hold active-low reset for 10 cycles
  top->rst_n = 0;
  for (int i = 0; i < 10; ++i)
    tick();
  top->rst_n = 1;

  bool quit = false;
  bool prev_hsync = 1;
  bool prev_vsync = 1;
  int h_ticks = 0;
  int v_lines = 0;

  while (!quit) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT)
        quit = true;
      if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)
        quit = true;
    }

    // Run simulation until one complete frame finishes (or safety limit hits)
    bool frame_done = false;
    int safety_ticks = 0;
    while (!frame_done && safety_ticks < 2000000) {
      tick();
      safety_ticks++;

      bool hsync = top->hsync;
      bool vsync = top->vsync;

      // Rising edge of HSYNC = start of Horizontal Back Porch
      if (!prev_hsync && hsync) {
        h_ticks = 0;
        v_lines++;
      } else {
        h_ticks++;
      }

      // Rising edge of VSYNC = start of Vertical Back Porch
      if (!prev_vsync && vsync) {
        v_lines = 0;
      }

      // Falling edge of VSYNC = frame complete, update SDL window
      if (prev_vsync && !vsync) {
        frame_done = true;
      }

      // Sample RGB565 once per 25 MHz pixel during active region
      if (h_ticks % CLK_PER_PIXEL == 0) {
        int px = (h_ticks / CLK_PER_PIXEL) - H_BACK_PORCH;
        int py = v_lines - V_BACK_PORCH;
        if (px >= 0 && px < H_RES && py >= 0 && py < V_RES) {
          uint8_t r = (top->vga_r << 3) | (top->vga_r >> 2);
          uint8_t g = (top->vga_g << 2) | (top->vga_g >> 4);
          uint8_t b = (top->vga_b << 3) | (top->vga_b >> 2);
          framebuffer[py * H_RES + px] =
              (0xFFu << 24) | (r << 16) | (g << 8) | b;
        }
      }

      prev_hsync = hsync;
      prev_vsync = vsync;
    }

    SDL_UpdateTexture(texture, nullptr, framebuffer, H_RES * sizeof(uint32_t));
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, nullptr, nullptr);
    SDL_RenderPresent(renderer);
  }

  delete top;
  SDL_DestroyTexture(texture);
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
  return 0;
}