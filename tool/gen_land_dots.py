"""
gen_land_dots.py — Generate land_dots.bin for the dot_globe Flutter package.

Binary format
-------------
Flat binary, no header, no footer.
Each land point is stored as two consecutive little-endian signed int16 values:

    offset 0: round(lat * 100)   — latitude  in centidegrees, north-positive, range [-9000, 9000]
    offset 2: round(lng * 100)   — longitude in centidegrees, east-positive,  range [-18000, 18000]

4 bytes per point total.  The Dart decoder (dot_globe_geometry.dart) reads:

    final lat = int16[i * 2]     / 100 * pi / 180;   // centidegrees → radians
    final lng = int16[i * 2 + 1] / 100 * pi / 180;

Quantization: 0.01° ≈ 1.11 km grid at the equator.

Usage examples
--------------
    # Typical: 60 000 Fibonacci candidates, default 110m resolution
    python3 tool/gen_land_dots.py --samples 60000

    # Higher-resolution land outline (needs ne_50m_land.geojson)
    python3 tool/gen_land_dots.py --resolution 50m --samples 120000

    # Explicit paths
    python3 tool/gen_land_dots.py --geojson /data/ne_110m_land.geojson --out assets/land_dots.bin

Dependencies
------------
    pip install shapely          # required — point-in-polygon
    pip install numpy            # optional — speeds up Fibonacci math

GeoJSON download (public domain, Natural Earth)
-----------------------------------------------
    110m (~200 KB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
     50m (~600 KB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson
     10m (~3.5 MB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
"""

import argparse
import array
import json
import math
import os
import sys

# ---------------------------------------------------------------------------
# Optional numpy import — used only to speed up the Fibonacci spiral math.
# ---------------------------------------------------------------------------
try:
    import numpy as _np
    _HAS_NUMPY = True
except ImportError:
    _HAS_NUMPY = False

# ---------------------------------------------------------------------------
# Shapely import — required for point-in-polygon tests.
# ---------------------------------------------------------------------------
try:
    from shapely.geometry import shape, Point
    from shapely.strtree import STRtree
except ImportError:
    print(
        "ERROR: shapely is required but not installed.\n"
        "Install it with:  pip install shapely",
        file=sys.stderr,
    )
    sys.exit(1)


# ---------------------------------------------------------------------------
# GeoJSON loading
# ---------------------------------------------------------------------------

def load_polygons_from_geojson(path: str):
    """
    Read a GeoJSON file and return a list of shapely Polygon / MultiPolygon
    objects for every feature whose geometry type is Polygon or MultiPolygon.

    Parameters
    ----------
    path : str
        Filesystem path to the GeoJSON file.

    Returns
    -------
    list of shapely geometry objects
    """
    if not os.path.isfile(path):
        print(
            f"ERROR: GeoJSON file not found: {path}\n\n"
            "Download one of the Natural Earth land GeoJSON files (public domain):\n"
            "  110m (~200 KB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson\n"
            "   50m (~600 KB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson\n"
            "   10m (~3.5 MB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson\n\n"
            "Example:\n"
            "  curl -L -o ne_110m_land.geojson \\\n"
            "    https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson\n"
            "  python3 tool/gen_land_dots.py --geojson ne_110m_land.geojson",
            file=sys.stderr,
        )
        sys.exit(1)

    with open(path, "r", encoding="utf-8") as fh:
        geojson = json.load(fh)

    polygons = []
    features = geojson.get("features", [])
    for feat in features:
        geom = feat.get("geometry")
        if geom is None:
            continue
        gtype = geom.get("type", "")
        if gtype in ("Polygon", "MultiPolygon"):
            polygons.append(shape(geom))

    if not polygons:
        print(
            "ERROR: The GeoJSON file contains no Polygon or MultiPolygon features.\n"
            "Make sure you downloaded a land-polygon GeoJSON (ne_*m_land.geojson).",
            file=sys.stderr,
        )
        sys.exit(1)

    return polygons


def _find_geojson_candidate(resolution: str, script_dir: str) -> str:
    """
    Look for a local ne_<resolution>_land.geojson next to the script or in cwd.
    Returns the path if found, or an empty string.
    """
    filename = f"ne_{resolution}_land.geojson"
    for directory in (script_dir, os.getcwd()):
        candidate = os.path.join(directory, filename)
        if os.path.isfile(candidate):
            return candidate
    return ""


# ---------------------------------------------------------------------------
# Fibonacci spiral candidate generation
# ---------------------------------------------------------------------------

def fibonacci_lat_lng(n: int):
    """
    Generate *n* uniformly distributed (lat, lng) pairs on the unit sphere
    using a golden-angle Fibonacci spiral.  This avoids the polar clustering
    that a naive uniform random approach would produce.

    Yields
    ------
    (lat_deg, lng_deg) tuples, lat in [-90, 90], lng in [-180, 180).
    """
    golden_ratio = (1.0 + math.sqrt(5.0)) / 2.0

    if _HAS_NUMPY:
        # Vectorised path — much faster for large n.
        indices = _np.arange(n, dtype=_np.float64)
        # y ranges from 1 - 1/n to -1 + 1/n, giving uniform area slices.
        y = 1.0 - (2.0 * indices + 1.0) / n          # cos(polar angle)
        # Clamp to [-1, 1] to guard against floating-point edge values.
        y = _np.clip(y, -1.0, 1.0)
        lat_rad = _np.arcsin(y)
        lng_rad = (2.0 * _np.pi * indices / golden_ratio) % (2.0 * _np.pi)
        # Shift lng from [0, 2π) to [-π, π).
        lng_rad = _np.where(lng_rad > _np.pi, lng_rad - 2.0 * _np.pi, lng_rad)
        lat_deg = _np.degrees(lat_rad)
        lng_deg = _np.degrees(lng_rad)
        for lat, lng in zip(lat_deg.tolist(), lng_deg.tolist()):
            yield lat, lng
    else:
        # Pure-math fallback — no numpy required.
        two_pi = 2.0 * math.pi
        for i in range(n):
            y = 1.0 - (2.0 * i + 1.0) / n
            y = max(-1.0, min(1.0, y))
            lat_rad = math.asin(y)
            lng_rad = (two_pi * i / golden_ratio) % two_pi
            if lng_rad > math.pi:
                lng_rad -= two_pi
            yield math.degrees(lat_rad), math.degrees(lng_rad)


# ---------------------------------------------------------------------------
# Point-in-polygon filtering
# ---------------------------------------------------------------------------

def filter_land_points(candidates, polygons, quiet: bool):
    """
    Test each (lat, lng) candidate against the land polygons using a
    shapely STRtree for spatial indexing.  Returns a list of (lat, lng)
    tuples that fall inside at least one polygon (including holes — the
    Caspian Sea and Great Lakes are treated as water correctly by shapely
    because they are encoded as interior rings in the GeoJSON).

    Parameters
    ----------
    candidates : iterable of (lat_deg, lng_deg)
    polygons   : list of shapely Polygon / MultiPolygon
    quiet      : suppress progress output

    Returns
    -------
    list of (lat_deg, lng_deg)
    """
    # Build an STRtree over all polygons for fast bounding-box pre-filter.
    tree = STRtree(polygons)

    kept = []
    total = 0

    for lat, lng in candidates:
        total += 1
        pt = Point(lng, lat)  # shapely uses (x=lng, y=lat) convention

        # Query the tree for polygons whose bounding box overlaps the point.
        # shapely 2.x STRtree.query() returns an array of integer indices into
        # the original polygons list (numpy.int64 values), not geometry objects.
        candidate_indices = tree.query(pt)
        for idx in candidate_indices:
            if polygons[idx].contains(pt):
                kept.append((lat, lng))
                break

        if not quiet and total % 10000 == 0:
            print(f"  ... tested {total:,} candidates, kept {len(kept):,} so far")

    return total, kept


# ---------------------------------------------------------------------------
# Binary writer
# ---------------------------------------------------------------------------

def write_bin(points, out_path: str) -> int:
    """
    Write *points* as little-endian int16 pairs to *out_path*.

    Each point contributes 4 bytes:
        bytes 0-1: round(lat * 100) as signed int16 LE
        bytes 2-3: round(lng * 100) as signed int16 LE

    Returns the number of bytes written.
    """
    buf = array.array("h")  # signed short, native byte order
    for lat, lng in points:
        lat_i = int(round(lat * 100))
        lng_i = int(round(lng * 100))
        # Clamp to int16 range as a safety net (should never trigger with
        # valid geographic coordinates).
        lat_i = max(-32768, min(32767, lat_i))
        lng_i = max(-32768, min(32767, lng_i))
        buf.append(lat_i)
        buf.append(lng_i)

    # Ensure little-endian output regardless of host byte order.
    if sys.byteorder == "big":
        buf.byteswap()

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "wb") as fh:
        buf.tofile(fh)

    return len(buf) * buf.itemsize  # itemsize == 2, so total = n_points * 4


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.normpath(os.path.join(script_dir, "..", "assets", "land_dots.bin"))

    parser = argparse.ArgumentParser(
        prog="gen_land_dots.py",
        description=(
            "Generate land_dots.bin for the dot_globe Flutter package.\n\n"
            "Samples N points uniformly on a sphere (Fibonacci spiral), keeps those\n"
            "that fall inside Natural Earth land polygons, and writes them as little-\n"
            "endian int16 lat/lng centidegree pairs."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--geojson",
        metavar="PATH",
        default="",
        help=(
            "Path to a Natural Earth land GeoJSON file.  "
            "If omitted the script looks for ne_<resolution>_land.geojson "
            "next to the script and in the current directory.  "
            "Download from: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson"
        ),
    )
    parser.add_argument(
        "--resolution",
        choices=["110m", "50m", "10m"],
        default="110m",
        help=(
            "Natural Earth resolution to look for when --geojson is not given.  "
            "110m (default) is sufficient for most globe visualisations; "
            "50m / 10m give sharper coastlines at the cost of slower generation."
        ),
    )
    parser.add_argument(
        "--samples",
        type=int,
        default=60000,
        metavar="N",
        help="Number of Fibonacci sphere candidates to test (default: 60000).",
    )
    parser.add_argument(
        "--out",
        default=default_out,
        metavar="PATH",
        help=f"Output path for the binary asset (default: {default_out}).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress progress output; only errors are printed.",
    )
    return parser


def main(argv=None):
    """Entry point — parse args and run the generation pipeline."""
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    script_dir = os.path.dirname(os.path.abspath(__file__))

    # ------------------------------------------------------------------
    # Resolve GeoJSON path
    # ------------------------------------------------------------------
    geojson_path = args.geojson
    if not geojson_path:
        geojson_path = _find_geojson_candidate(args.resolution, script_dir)

    if not geojson_path:
        # No file found — tell the user exactly how to get it.
        filename = f"ne_{args.resolution}_land.geojson"
        url = (
            f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/{filename}"
        )
        print(
            f"ERROR: No GeoJSON file found for resolution '{args.resolution}'.\n\n"
            f"Download it (public domain, Natural Earth) with:\n"
            f"  curl -L -o {filename} \\\n"
            f"    {url}\n\n"
            f"Then re-run:\n"
            f"  python3 tool/gen_land_dots.py --geojson {filename}\n\n"
            f"For higher-resolution variants:\n"
            f"  50m: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson\n"
            f"  10m: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson",
            file=sys.stderr,
        )
        sys.exit(1)

    # ------------------------------------------------------------------
    # Load land polygons
    # ------------------------------------------------------------------
    if not args.quiet:
        print(f"Loading land polygons from: {geojson_path}")
    polygons = load_polygons_from_geojson(geojson_path)
    if not args.quiet:
        print(f"  {len(polygons)} polygon(s) loaded.")

    # ------------------------------------------------------------------
    # Generate Fibonacci candidates and filter
    # ------------------------------------------------------------------
    if not args.quiet:
        numpy_note = "numpy" if _HAS_NUMPY else "pure-math (numpy not available)"
        print(f"Generating {args.samples:,} Fibonacci sphere candidates ({numpy_note}) ...")

    candidates = fibonacci_lat_lng(args.samples)
    total_tested, kept_points = filter_land_points(candidates, polygons, args.quiet)

    if not args.quiet:
        pct = 100.0 * len(kept_points) / total_tested if total_tested else 0
        print(f"  Kept {len(kept_points):,} / {total_tested:,} candidates ({pct:.1f}% land coverage).")

    # ------------------------------------------------------------------
    # Write binary output
    # ------------------------------------------------------------------
    if not args.quiet:
        print(f"Writing binary to: {args.out}")
    bytes_written = write_bin(kept_points, args.out)

    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    if not args.quiet:
        print()
        print("Done.")
        print(f"  Candidates tested : {total_tested:,}")
        print(f"  Points kept       : {len(kept_points):,}")
        print(f"  Bytes written     : {bytes_written:,}  ({bytes_written // 4:,} points × 4 bytes)")
        print(f"  Output path       : {os.path.abspath(args.out)}")
        print()
        print(
            "  Note: 0.01° quantization ≈ 1.11 km grid spacing at the equator "
            "(decreases toward the poles)."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
