import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Geometry data and projection math for the dotted globe.
///
/// Land dots come from `assets/land_dots.bin`: generated offline from Natural
/// Earth 110m land polygons sampled on a Fibonacci sphere, stored as
/// little-endian int16 pairs (lat*100, lng*100), ~6300 points. (Every Flutter
/// target platform is little-endian, so the host byte order is used directly.)
class DotGlobeGeometry {
  DotGlobeGeometry._(this.unitVectors) : pointCount = unitVectors.length ~/ 3;

  /// Land-dot unit vectors, laid out as `[x0,y0,z0, x1,y1,z1, ...]`.
  /// Axes: `x = -cos(lat)cos(lng)` (negated so east projects to screen-right),
  /// `y = sin(lat)` (north positive), `z = cos(lat)sin(lng)`.
  final Float32List unitVectors;

  /// Number of land dots (`unitVectors.length / 3`).
  final int pointCount;

  /// Global cache so multiple instances share one point cloud.
  static DotGlobeGeometry? _cached;
  static Future<DotGlobeGeometry>? _loading;

  /// Loads (and caches) the land-dot point cloud from the bundled asset.
  static Future<DotGlobeGeometry> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _doLoad();
  }

  static Future<DotGlobeGeometry> _doLoad() async {
    try {
      // When loaded by a consumer app, the asset key must be prefixed with packages/<package-name>/.
      final data =
          await rootBundle.load('packages/dot_globe/assets/land_dots.bin');
      final int16 = Int16List.sublistView(data);
      final count = int16.length ~/ 2;
      final vectors = Float32List(count * 3);
      for (var i = 0; i < count; i++) {
        final lat = int16[i * 2] / 100 * math.pi / 180;
        final lng = int16[i * 2 + 1] / 100 * math.pi / 180;
        final cosLat = math.cos(lat);
        vectors[i * 3] = -cosLat * math.cos(lng);
        vectors[i * 3 + 1] = math.sin(lat);
        vectors[i * 3 + 2] = cosLat * math.sin(lng);
      }
      _cached = DotGlobeGeometry._(vectors);
      return _cached!;
    } finally {
      // On success the result is stored in _cached; on failure _loading is cleared so
      // the next load() call can retry — prevents a failed Future from being cached permanently.
      _loading = null;
    }
  }

  /// Converts a latitude/longitude (degrees) to a unit sphere vector, written into [out] indices 0–2.
  static void latLngToUnitVector(double latDeg, double lngDeg, Float64List out) {
    final lat = latDeg * math.pi / 180;
    final lng = lngDeg * math.pi / 180;
    final cosLat = math.cos(lat);
    out[0] = -cosLat * math.cos(lng);
    out[1] = math.sin(lat);
    out[2] = cosLat * math.sin(lng);
  }
}

/// Current-frame rotation pose, shared between the painter and the marker layout layer
/// to avoid rebuilding widgets on every frame.
class DotGlobeFrame {
  /// Horizontal rotation angle around the Y axis, in radians.
  /// When longitude [lng] is centred in front, phi = π/2 − lng.
  double phi = math.pi / 2;

  /// Pitch angle around the X axis, in radians. Positive values tilt the north pole toward the viewer.
  double theta = 0;

  /// Projects a unit vector (x, y, z) using the current pose.
  /// Results are written to [out]: [0] = rotated x (screen horizontal, sphere radius = 1),
  /// [1] = rotated y (screen vertical, up is positive), [2] = depth z (> 0 faces the viewer).
  void project(double x, double y, double z, Float64List out) {
    final cy = math.cos(phi);
    final sy = math.sin(phi);
    final cx = math.cos(theta);
    final sx = math.sin(theta);
    final x1 = cy * x + sy * z;
    final z1 = -sy * x + cy * z;
    out[0] = x1;
    out[1] = cx * y - sx * z1;
    out[2] = sx * y + cx * z1;
  }
}
