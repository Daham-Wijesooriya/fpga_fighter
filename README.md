# FPGA Fighter — Pure RTL 2-Player Arcade Fighting Game

A 2-player 2D arcade fighting game implemented in **100% pure synthesizable Verilog-2001 HDL** — no ARM processor, no MicroBlaze, and no framebuffers. All graphics compositing, VGA timing, game physics, and collision logic run directly in FPGA fabric.

- **Target Board:** NI / Digilent DSDB rev. C
- **FPGA Device:** Xilinx Zynq-7020 (`xc7z020clg484-1`)
- **Display Output:** 640×480 @ 60 Hz VGA, 16-bit RGB565 (`vga_r[4:0]`, `vga_g[5:0]`, `vga_b[4:0]`, `hsync`, `vsync`)
- **Development Strategy:** *White-Box First* — verify VGA timing, HUD, movement, and hitboxes with solid geometry before adding BRAM pixel-art sprites.

---

## Project Structure

```text
fpga_fighter/
├── src/
│   ├── vga_sync.v          # 640x480 @ 60Hz VGA timing generator + 60Hz frame_tick
│   ├── hud_renderer.v      # Pure combinational arcade HUD (HP bars, 7-seg timer, super meters)
│   └── top_fighter.v       # Top-level clock divider, 3-layer compositor & registered VGA outputs
├── sim/
│   ├── sim_main.cpp        # Real-time Verilator + SDL2 640x480 live VGA simulator
│   ├── tb_vga_ppm.v        # 1-frame Verilog testbench (exports P3 PPM + blanking check)
│   └── ppm_to_png.py       # Converts vga_frame.ppm -> sim/vga_frame.png (zero-dependency fallback)
├── constraints/
│   ├── DSDB_Master.xdc     # Official NI DSDB rev. C master constraints (active Phase 1 pins enabled)
│   └── dsdb_fighter.xdc    # Reference template XDC
├── assets/                 # Future BRAM pixel-art sprite PNGs and .mem files
└── README.md
```

---

## Phase 1 Architecture (Current)

### RTL Modules
| Module | File | Description |
| --- | --- | --- |
| `vga_sync` | `src/vga_sync.v` | Generates standard VESA 640×480 @ 60 Hz timing (`800×525` total counts) from a 25 MHz pixel clock, active-low `hsync`/`vsync`, `video_active`, `pixel_x[9:0]`, `pixel_y[9:0]`, and a single-cycle 60 Hz `frame_tick` pulse at the start of vertical blanking (`v_cnt == 480, h_cnt == 0`). |
| `hud_renderer` | `src/hud_renderer.v` | Pure combinational RGB565 arcade HUD drawing P1 & P2 yellow/red health bars (`0..100` HP draining toward center) with 2 px white borders, a centered timer box with 2-digit 7-segment digits (`00..99`), and two segmented bottom super-meter bars. |
| `top_fighter` | `src/top_fighter.v` | Divides the system clock to 25 MHz, drives a 3-layer priority compositor, and registers all VGA outputs while strictly forcing `vga_r`, `vga_g`, and `vga_b` to `0` during blanking intervals. |

### 3-Layer Priority Compositor
1. **Layer 1 (Top):** Arcade HUD (`hud_renderer`)
2. **Layer 2 (Mid):** Placeholder P1 (blue, left) and P2 (red, right) fighter rectangles standing on the floor line (`y = 380`), each outlined with a 2-pixel cyan hurtbox
3. **Layer 3 (Background):** 9-band RGB565 dusk sky gradient above `y = 380` and a dark 32×16 checkerboard tiled floor below `y = 380`

---

## PC Visual Verification (No FPGA Required)

### Option 1: Real-Time Live VGA Window (Verilator + SDL2 on WSL Ubuntu)
Run inside WSL (`Ubuntu`) from the `sim/` directory:

```bash
verilator --cc --exe --build -j 0 \
  --top-module top_fighter \
  -I../src ../src/top_fighter.v sim_main.cpp \
  -CFLAGS "$(sdl2-config --cflags)" \
  -LDFLAGS "$(sdl2-config --libs)" \
  -o ../vga_sim

./vga_sim
```
Press `Esc` or close the window to exit.

### Option 2: Single-Frame PNG via Vivado Simulator (`xsim`)
1. Add `src/vga_sync.v`, `src/hud_renderer.v`, `src/top_fighter.v` as Design Sources and `sim/tb_vga_ppm.v` as a Simulation Source in Vivado.
2. Run **Behavioral Simulation**, then run `run -all` in the Vivado Tcl Console (1 full frame takes ~16.8 ms).
3. Convert the captured PPM to PNG from the project root:
   ```powershell
   python sim/ppm_to_png.py
   ```
4. Open `sim/vga_frame.png` to inspect the rendered frame.

### Option 3: Single-Frame PNG via Icarus Verilog
```powershell
iverilog -g2001 -Wall -o sim/tb_vga_ppm.vvp src/vga_sync.v src/hud_renderer.v src/top_fighter.v sim/tb_vga_ppm.v
vvp sim/tb_vga_ppm.vvp
python sim/ppm_to_png.py
```

---

## FPGA Hardware Bring-Up (Vivado)

Use `constraints/DSDB_Master.xdc` with `top_fighter` as the top module:

| Signal | DSDB Pin(s) | Notes |
| --- | --- | --- |
| `clk_100mhz` | `L18` | **Note:** DSDB rev. C onboard oscillator (`sysclk_125mhz`) is **125 MHz** — switch the clock divider to divide-by-5 (or use a Vivado Clocking Wizard / MMCM) for an exact 25 MHz pixel clock on hardware. |
| `rst_n` | `T6` (`sw[0]`) | Active-low reset: switch **UP** = run, **DOWN** = reset. |
| `vga_r[4:0]` | `B15, A17, A19, A22, D22` | 5-bit Red (`LVCMOS33`) |
| `vga_g[5:0]` | `C15, A16, B17, A21, B22, F21` | 6-bit Green (`LVCMOS33`) |
| `vga_b[4:0]` | `B16, A18, B21, C22, F22` | 5-bit Blue (`LVCMOS33`) |
| `hsync`, `vsync` | `G22`, `H22` | Active-low VGA sync (`LVCMOS33`) |

---

## Roadmap

- [x] **Phase 1:** VGA 640×480 @ 60 Hz sync, arcade HUD, placeholder fighters, dusk sky/floor compositor, and PC verification (Vivado `xsim` PPM + Verilator/SDL2 live window)
- [ ] **Phase 2:** 125 MHz → 25 MHz hardware clocking, 2-player input (PS/2 keyboard / buttons), movement, jumping, gravity, and stage boundaries on `frame_tick`
- [ ] **Phase 3:** Fighter FSM (idle, walk, jump, crouch, attack, hitstun, block), active hitboxes vs. hurtboxes, HP & super-meter logic, round timer, and KO/victory states
- [ ] **Phase 4:** BRAM pixel-art sprite ROMs (`.mem`), horizontal flipping, animation frames, and optional audio effects
