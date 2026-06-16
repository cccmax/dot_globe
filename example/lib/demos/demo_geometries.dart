import 'dart:math' as math;

import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart' show Color;

/// Shared pure geometry generators used by the example demos AND the headless
/// screenshot capture test, so both render the exact same dot clouds with no
/// duplicated logic. Everything here is a pure function: no widgets, no state,
/// no async beyond what the package itself requires.

// ===========================================================================
// Custom text — rasterise a word into a dot cloud (from custom_data_demo).
// ===========================================================================

// ── 5x7 bitmap font ────────────────────────────────────────────────────────
// One entry per glyph: 7 rows of 5 columns, '1' = a lit cell. Covers the
// letters in 'DART' and 'FLUTTER'; add more rows to support other words.
const int _glyphW = 5;
const int _glyphH = 7;
const Map<String, List<String>> _font = {
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

/// Rasterises [text] into lat/lng points laid across the front of the sphere.
///
/// Each lit font cell is super-sampled into a [sub]×[sub] grid of dots so the
/// strokes read as solid halftone glyphs rather than a sparse outline. The
/// whole word is centred on (0°, 0°) and spans [lngSpan]×[latSpan] degrees,
/// small enough to stay legible on the front-facing hemisphere.
DotGlobeGeometry buildDartTextGeometry([String text = 'DART']) {
  const int gap = 1; // blank columns between glyphs
  const int sub = 3; // dots per cell per axis
  const double lngSpan = 104; // total width in degrees of longitude
  const double latSpan = 46; // total height in degrees of latitude

  final int cols = text.length * (_glyphW + gap) - gap;
  const int rows = _glyphH;
  final pts = <({double latitude, double longitude})>[];

  for (var ci = 0; ci < text.length; ci++) {
    final glyph = _font[text[ci].toUpperCase()] ?? _font[' ']!;
    final colOffset = ci * (_glyphW + gap);
    for (var r = 0; r < rows; r++) {
      final rowBits = glyph[r];
      for (var c = 0; c < _glyphW; c++) {
        if (rowBits[c] != '1') continue;
        final gx = colOffset + c; // global column index of this cell
        for (var sy = 0; sy < sub; sy++) {
          for (var sx = 0; sx < sub; sx++) {
            final fx = gx + (sx + 0.5) / sub; // 0..cols
            final fy = r + (sy + 0.5) / sub; // 0..rows
            final lng = -lngSpan / 2 + lngSpan * (fx / cols);
            final lat = latSpan / 2 - latSpan * (fy / rows);
            pts.add((latitude: lat, longitude: lng));
          }
        }
      }
    }
  }
  return DotGlobeGeometry.fromLatLng(pts);
}

// ===========================================================================
// Heatmap — smooth sinusoidal field → colormap (from colored_dots_demo).
// ===========================================================================

/// Procedural scalar field over the globe in [0, 1].
/// A sum of two sinusoidal modes produces smooth warm/cool bands.
double heatField(double latDeg, double lngDeg) {
  final lat = latDeg * math.pi / 180;
  final lng = lngDeg * math.pi / 180;
  final v = 0.5 +
      0.3 * math.sin(lat * 3) * math.cos(lng * 2) +
      0.2 * math.sin(lat * 5 + lng * 3);
  return v.clamp(0.0, 1.0);
}

/// Builds a per-dot value array from [heatField] over each dot's lat/lng, then
/// maps it through [colormap] via colorizeByValues — exactly the heatmap mode
/// of the colored-dots demo.
DotGlobeGeometry buildHeatmapGeometry(
  DotGlobeGeometry base,
  DotGlobeColormap colormap,
) {
  final values = List<double>.filled(base.pointCount, 0);

  // Track insertion index separately — colorize iterates in dot order.
  var idx = 0;
  base.colorize((lat, lng, _) {
    // Smooth field: blend of two sinusoidal modes, fully in [0, 1].
    values[idx++] = heatField(lat, lng);
    return 0; // return value unused here; we only want the lat/lng loop
  });

  // colorizeByValues: the API for "I already have a per-dot value array".
  // min/max are auto-derived from the data extent when omitted.
  return base.colorizeByValues(values, colormap: colormap);
}

// ===========================================================================
// Fantasy planet — Fibonacci cloud + biome colours (from fantasy_world_demo).
// ===========================================================================

// Returns an ARGB32 int for a dot given elevation e ∈ [0,1] and |lat| ∈ [0,90].
int _biomeColor(double e, double absLat) {
  // Polar ice overrides all biomes near the poles.
  final polarBlend = ((absLat - 68.0) / 14.0).clamp(0.0, 1.0);
  if (polarBlend > 0.0) {
    // Blend from the terrain colour into arctic white/blue.
    final snowColor = _lerp32(
      _terrainColor(e),
      const Color(0xFFD8ECF5).toARGB32(),
      polarBlend,
    );
    return snowColor;
  }

  // Latitude-modulated sub-polar snow caps (mountains near poles look white).
  final subPolarBoost = ((absLat - 55.0) / 18.0).clamp(0.0, 1.0);
  final terrainE = e + subPolarBoost * 0.25;

  return _terrainColor(terrainE.clamp(0.0, 1.0));
}

// Elevation → terrain colour, from deep ocean through biomes to snow peaks.
int _terrainColor(double e) {
  // thresholds tuned for believable continent coverage (~35 % land)
  if (e < 0.28) {
    // Deep ocean
    return const Color(0xFF0D2A52).toARGB32();
  } else if (e < 0.38) {
    // Shallow sea / shelf
    final t = (e - 0.28) / 0.10;
    return _lerp32(
      const Color(0xFF0D2A52).toARGB32(),
      const Color(0xFF1A7A8A).toARGB32(),
      t,
    );
  } else if (e < 0.42) {
    // Beach / sand
    return const Color(0xFFD9C27A).toARGB32();
  } else if (e < 0.56) {
    // Grassland
    return const Color(0xFF4E9A47).toARGB32();
  } else if (e < 0.70) {
    // Forest
    return const Color(0xFF2D6B2B).toARGB32();
  } else if (e < 0.83) {
    // Mountain
    return const Color(0xFF7A6B58).toARGB32();
  } else {
    // Snow peak
    return const Color(0xFFEFF3F6).toARGB32();
  }
}

// Linear-interpolate between two ARGB32 ints (channel-wise).
int _lerp32(int a, int b, double t) {
  final aA = (a >> 24) & 0xFF;
  final aR = (a >> 16) & 0xFF;
  final aG = (a >> 8) & 0xFF;
  final aB = a & 0xFF;
  final bA = (b >> 24) & 0xFF;
  final bR = (b >> 16) & 0xFF;
  final bG = (b >> 8) & 0xFF;
  final bB = b & 0xFF;
  final rA = (aA + (bA - aA) * t).round();
  final rR = (aR + (bR - aR) * t).round();
  final rG = (aG + (bG - aG) * t).round();
  final rB = (aB + (bB - aB) * t).round();
  return (rA << 24) | (rR << 16) | (rG << 8) | rB;
}

// Procedural "elevation" field — deterministic sine-octave pseudo-noise.
//
// No Random: each value is a pure function of (lat, lng) in radians.
// Four octaves at ascending spatial frequencies + fixed phase offsets give
// enough variation for believable continents without RNG. Result ∈ [0, 1].
double _elevation(double latDeg, double lngDeg) {
  final lat = latDeg * math.pi / 180.0;
  final lng = lngDeg * math.pi / 180.0;

  // Octave 1 — low-frequency "continental" tilt (big blobs).
  final o1 = math.sin(lat * 1.3 + 0.7) * math.cos(lng * 1.1 - 0.4);
  // Octave 2 — mid-frequency terrain ridges.
  final o2 = math.sin(lat * 2.8 + lng * 1.9 + 1.2) * 0.55;
  // Octave 3 — finer coastal detail.
  final o3 = math.cos(lat * 5.1 - lng * 3.3 + 2.1) * 0.30;
  // Octave 4 — mountain / valley micro-variation.
  final o4 = math.sin(lat * 9.7 + lng * 6.2 - 3.0) * 0.15;

  // Weighted sum, normalised to [0, 1].
  final raw = (o1 + o2 + o3 + o4) / (1.0 + 0.55 + 0.30 + 0.15);
  return (raw * 0.5 + 0.5).clamp(0.0, 1.0);
}

/// Builds the fantasy planet: a ~7000-point Fibonacci sphere cloud coloured by
/// a four-octave sine-sum elevation field (deep ocean → shelf → beach →
/// grassland → forest → mountain → snow peak, with polar ice override).
DotGlobeGeometry buildFantasyPlanet() {
  // --- Step 1: Fibonacci sphere point cloud (~7000 points) ---
  // Golden angle spacing gives near-perfect sphere coverage.
  const int n = 7000;
  // Golden angle = π * (3 − √5) ≈ 2.399 rad — gives near-perfect sphere coverage.
  const double phi = math.pi * (3.0 - 2.2360679774997896);

  final points = <({double latitude, double longitude})>[];
  for (var i = 0; i < n; i++) {
    // y ∈ [-1, 1] linearly spaced → latitude via arcsin.
    final y = 1.0 - (i / (n - 1.0)) * 2.0;
    final latRad = math.asin(y.clamp(-1.0, 1.0));
    final lngRad = (i * phi) % (2.0 * math.pi);

    final latDeg = latRad * 180.0 / math.pi;
    // Map longitude to [-180, 180].
    var lngDeg = lngRad * 180.0 / math.pi;
    if (lngDeg > 180.0) lngDeg -= 360.0;

    points.add((latitude: latDeg, longitude: lngDeg));
  }

  final geometry = DotGlobeGeometry.fromLatLng(points);

  // --- Step 2: Per-dot biome colour ---
  return geometry.colorize((latDeg, lngDeg, _) {
    final e = _elevation(latDeg, lngDeg);
    return _biomeColor(e, latDeg.abs());
  });
}
