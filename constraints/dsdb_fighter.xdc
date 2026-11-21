## =============================================================================
## Constraints File: dsdb_fighter.xdc
## Target Board: NI/Digilent DSDB (Xilinx Zynq-7020, part: xc7z020clg484-1)
## Top-Level Module: top_fighter
##
## IMPORTANT:
##   Pin assignments marked with TODO MUST be cross-checked against the
##   official NI DSDB master XDC before running Vivado implementation and
##   bitstream generation!
## =============================================================================

## -----------------------------------------------------------------------------
## 1. System Clock (100 MHz)
## -----------------------------------------------------------------------------
## TODO: Verify 100 MHz PL oscillator PACKAGE_PIN against NI DSDB master XDC
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports { clk_100mhz }];

## -----------------------------------------------------------------------------
## 2. Active-Low Reset (Pushbutton / Switch)
## -----------------------------------------------------------------------------
## TODO: Verify active-low reset button/switch PACKAGE_PIN against NI DSDB master XDC
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## -----------------------------------------------------------------------------
## 3. VGA Red Channel — vga_r[4:0] (5-bit RGB565)
## -----------------------------------------------------------------------------
## TODO: Verify all 5 VGA Red PACKAGE_PINs against NI DSDB master XDC
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_r[4] }];

## -----------------------------------------------------------------------------
## 4. VGA Green Channel — vga_g[5:0] (6-bit RGB565)
## -----------------------------------------------------------------------------
## TODO: Verify all 6 VGA Green PACKAGE_PINs against NI DSDB master XDC
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_g[4] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_g[5] }];

## -----------------------------------------------------------------------------
## 5. VGA Blue Channel — vga_b[4:0] (5-bit RGB565)
## -----------------------------------------------------------------------------
## TODO: Verify all 5 VGA Blue PACKAGE_PINs against NI DSDB master XDC
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vga_b[4] }];

## -----------------------------------------------------------------------------
## 6. VGA Sync Signals — hsync, vsync
## -----------------------------------------------------------------------------
## TODO: Verify VGA HSYNC and VSYNC PACKAGE_PINs against NI DSDB master XDC
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { hsync }];
# set_property -dict { PACKAGE_PIN <TODO_PIN>  IOSTANDARD LVCMOS33 } [get_ports { vsync }];
