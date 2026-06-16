#!/usr/bin/env python3
"""Bake natural-colour values for the bundled dot cloud.

Reads ``assets/land_dots.bin`` (little-endian int16 pairs of lat*100, lng*100)
and an equirectangular natural-colour Earth raster (e.g. NASA Blue Marble,
public domain), samples the raster at each dot's latitude/longitude, and writes
``assets/land_colors.bin``: RGB888, 3 bytes per dot, in the SAME order as
``land_dots.bin``. ``DotGlobeGeometry.naturalEarth()`` loads both.

Dart decode: ``argb = 0xFF000000 | (r << 16) | (g << 8) | b``.

Sampling matches the package's runtime convention (``colorizeFromImage``):
``u = lng/360 + 0.5``, ``v = 0.5 - lat/180``. A small box average smooths out
single-pixel coastline/ocean speckles on land dots.

Usage:
    pip install pillow
    # Source raster (public domain, ~6 MB, 8192x4096):
    curl -L -o bluemarble.jpg \\
      "https://commons.wikimedia.org/wiki/Special:FilePath/Whole_world_-_land_and_oceans.jpg"
    python3 tool/gen_land_colors.py --raster bluemarble.jpg
"""
import argparse
import os
import struct

from PIL import Image


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--raster", required=True,
                    help="equirectangular natural-colour Earth image")
    ap.add_argument("--dots", default=os.path.join(here, "..", "assets", "land_dots.bin"),
                    help="bundled dot positions (default: package asset)")
    ap.add_argument("--out", default=os.path.join(here, "..", "assets", "land_colors.bin"),
                    help="output RGB888 colours (default: package asset)")
    ap.add_argument("--avg", type=int, default=2,
                    help="box-average radius in source pixels (0 = nearest)")
    ap.add_argument("--brighten", type=float, default=1.0,
                    help="multiply RGB to lift the (dark) Blue Marble palette")
    ap.add_argument("--saturate", type=float, default=1.0,
                    help="saturation multiplier around per-pixel mean")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    with open(args.dots, "rb") as f:
        raw = f.read()
    n = len(raw) // 4
    pts = struct.unpack("<%dh" % (n * 2), raw)  # lat*100, lng*100 interleaved

    im = Image.open(args.raster).convert("RGB")
    width, height = im.size
    px = im.load()
    rad = max(0, args.avg)

    out = bytearray()
    sr = sg = sb = 0
    for i in range(n):
        lat = pts[2 * i] / 100.0
        lng = pts[2 * i + 1] / 100.0
        u = lng / 360.0 + 0.5
        v = 0.5 - lat / 180.0
        cx = int(u * width) % width
        cy = min(height - 1, max(0, int(v * height)))

        r = g = b = cnt = 0
        for dy in range(-rad, rad + 1):
            yy = min(height - 1, max(0, cy + dy))
            for dx in range(-rad, rad + 1):
                xx = (cx + dx) % width
                pr, pg, pb = px[xx, yy]
                r += pr
                g += pg
                b += pb
                cnt += 1
        rf, gf, bf = r / cnt, g / cnt, b / cnt

        if args.saturate != 1.0:
            mean = (rf + gf + bf) / 3.0
            rf = mean + (rf - mean) * args.saturate
            gf = mean + (gf - mean) * args.saturate
            bf = mean + (bf - mean) * args.saturate
        if args.brighten != 1.0:
            rf *= args.brighten
            gf *= args.brighten
            bf *= args.brighten

        ri = int(min(255, max(0, round(rf))))
        gi = int(min(255, max(0, round(gf))))
        bi = int(min(255, max(0, round(bf))))
        out += bytes((ri, gi, bi))
        sr += ri
        sg += gi
        sb += bi

    with open(args.out, "wb") as f:
        f.write(out)
    if not args.quiet:
        print(f"wrote {args.out}: {n} dots, {len(out)} bytes (RGB888)")
        print(f"mean colour: ({sr // n}, {sg // n}, {sb // n})")


if __name__ == "__main__":
    main()
