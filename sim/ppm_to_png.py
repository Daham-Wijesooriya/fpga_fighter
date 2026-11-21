#!/usr/bin/env python3
"""
Convert an ASCII P3 PPM file (e.g. sim/vga_frame.ppm) into a PNG image
(e.g. sim/vga_frame.png) for direct visual inspection in the IDE.

Uses Pillow if available, and falls back to a zero-dependency pure-Python
PNG encoder (stdlib struct + zlib) if Pillow is not installed.
"""

import struct
import sys
import zlib
from pathlib import Path


def read_ppm_p3(ppm_path: Path) -> tuple[int, int, bytes]:
    """Parse an ASCII P3 PPM file and return (width, height, raw_rgb_bytes)."""
    tokens: list[str] = []
    with ppm_path.open("r", encoding="ascii") as f:
        for line in f:
            # Strip PPM comments starting with '#'
            hash_idx = line.find("#")
            if hash_idx != -1:
                line = line[:hash_idx]
            tokens.extend(line.split())

    if len(tokens) < 4 or tokens[0] != "P3":
        raise ValueError(f"Expected ASCII P3 PPM header in {ppm_path}")

    width = int(tokens[1])
    height = int(tokens[2])
    maxval = int(tokens[3])
    if maxval <= 0 or maxval > 255:
        raise ValueError(f"Unsupported PPM maxval: {maxval}")

    expected_vals = width * height * 3
    pixel_tokens = tokens[4:]
    if len(pixel_tokens) < expected_vals:
        raise ValueError(
            f"Truncated PPM data: expected {expected_vals} RGB values, got {len(pixel_tokens)}"
        )

    if maxval == 255:
        rgb = bytes(int(v) for v in pixel_tokens[:expected_vals])
    else:
        rgb = bytes((int(v) * 255) // maxval for v in pixel_tokens[:expected_vals])

    return width, height, rgb


def write_png_stdlib(png_path: Path, width: int, height: int, rgb: bytes) -> None:
    """Write an 8-bit RGB PNG file using only the Python standard library."""
    def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

    # Prepend filter byte 0 (None) to each scanline
    stride = width * 3
    raw_scanlines = bytearray()
    for y in range(height):
        raw_scanlines.append(0)
        start = y * stride
        raw_scanlines.extend(rgb[start : start + stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    idat = zlib.compress(bytes(raw_scanlines), level=6)

    with png_path.open("wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(png_chunk(b"IHDR", ihdr))
        f.write(png_chunk(b"IDAT", idat))
        f.write(png_chunk(b"IEND", b""))


def convert_ppm_to_png(ppm_path: Path, png_path: Path) -> None:
    width, height, rgb = read_ppm_p3(ppm_path)
    try:
        from PIL import Image  # type: ignore

        img = Image.frombytes("RGB", (width, height), rgb)
        img.save(png_path, format="PNG")
    except ImportError:
        write_png_stdlib(png_path, width, height, rgb)

    print(f"Converted {ppm_path} ({width}x{height}) -> {png_path}")


def main() -> int:
    default_ppm = Path("sim/vga_frame.ppm")
    default_png = Path("sim/vga_frame.png")

    ppm_path = Path(sys.argv[1]) if len(sys.argv) > 1 else default_ppm
    png_path = Path(sys.argv[2]) if len(sys.argv) > 2 else default_png

    if not ppm_path.exists():
        print(f"ERROR: Input PPM file not found: {ppm_path}", file=sys.stderr)
        return 1

    convert_ppm_to_png(ppm_path, png_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

