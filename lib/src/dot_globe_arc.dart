import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'dot_globe_geometry.dart';

/// A great-circle arc drawn between two coordinates on a [DotGlobe] — a
/// flight-path / connection line.
///
/// The arc follows the shortest path over the sphere and bulges outward by
/// [altitude] so it lifts off the surface (set `altitude: 0` to hug it). The
/// half facing the viewer is drawn solid; the half curving around the back is
/// drawn dashed and faded.
@immutable
class DotGlobeArc {
  /// Creates an arc between two coordinates (degrees).
  const DotGlobeArc({
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    this.color = const Color(0xFF6B8AE8),
    this.width = 2.0,
    this.altitude = 0.35,
    this.dashed = false,
    this.glow = true,
    this.backOpacity = 0.38,
    this.backDashed = true,
    this.dashLength = 6.0,
    this.dashGap = 5.0,
  })  : assert(altitude >= 0, 'altitude must be >= 0'),
        assert(width > 0, 'width must be > 0'),
        assert(
          backOpacity >= 0 && backOpacity <= 1,
          'backOpacity must be in 0..1',
        );

  /// Start latitude in degrees, north positive.
  final double startLatitude;

  /// Start longitude in degrees, east positive.
  final double startLongitude;

  /// End latitude in degrees, north positive.
  final double endLatitude;

  /// End longitude in degrees, east positive.
  final double endLongitude;

  /// Stroke colour.
  final Color color;

  /// Stroke width in logical pixels.
  final double width;

  /// Peak height of the arc above the sphere, as a fraction of the radius.
  /// `0` hugs the surface; `0.35` lifts it into a pronounced bow.
  final double altitude;

  /// Whether the near-side (front) half is dashed. The back half is controlled
  /// separately by [backDashed].
  final bool dashed;

  /// Whether the front half gets a soft glow underlay.
  final bool glow;

  /// Opacity of the half curving around the back, `0`–`1`. `0` hides the back
  /// entirely; `1` draws it as opaque as the front. Default fades it to a hint.
  final double backOpacity;

  /// Whether the back half is dashed. `true` (default) marks it as "behind the
  /// globe"; set `false` for a solid back stroke.
  final bool backDashed;

  /// Dash length in logical pixels (applies wherever the arc is dashed).
  final double dashLength;

  /// Gap between dashes in logical pixels.
  final double dashGap;

  @override
  bool operator ==(Object other) =>
      other is DotGlobeArc &&
      other.startLatitude == startLatitude &&
      other.startLongitude == startLongitude &&
      other.endLatitude == endLatitude &&
      other.endLongitude == endLongitude &&
      other.color == color &&
      other.width == width &&
      other.altitude == altitude &&
      other.dashed == dashed &&
      other.glow == glow &&
      other.backOpacity == backOpacity &&
      other.backDashed == backDashed &&
      other.dashLength == dashLength &&
      other.dashGap == dashGap;

  @override
  int get hashCode => Object.hash(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
        color,
        width,
        altitude,
        dashed,
        glow,
        backOpacity,
        backDashed,
        dashLength,
        dashGap,
      );
}

/// Samples a great-circle arc into `samples` points, writing each as an
/// `(x, y, z)` vector whose length encodes the altitude bow (length ≥ 1).
///
/// Uses spherical linear interpolation (slerp) between the two endpoint unit
/// vectors, then scales each point by `1 + altitude * sin(pi * t)` so the arc
/// lifts off the sphere at its midpoint. Project the result like any other
/// point; the extra length pushes raised points outward on screen.
void sampleGreatCircleArc(
  DotGlobeArc arc,
  int samples,
  Float32List out,
) {
  final a = Float64List(3);
  final b = Float64List(3);
  DotGlobeGeometry.latLngToUnitVector(arc.startLatitude, arc.startLongitude, a);
  DotGlobeGeometry.latLngToUnitVector(arc.endLatitude, arc.endLongitude, b);

  final dot = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]).clamp(-1.0, 1.0);
  final omega = math.acos(dot);
  final sinOmega = math.sin(omega);

  for (var i = 0; i < samples; i++) {
    final t = samples == 1 ? 0.0 : i / (samples - 1);
    double x;
    double y;
    double z;
    if (sinOmega < 1e-6) {
      // Endpoints coincide (or are antipodal-degenerate): fall back to linear.
      x = a[0] + (b[0] - a[0]) * t;
      y = a[1] + (b[1] - a[1]) * t;
      z = a[2] + (b[2] - a[2]) * t;
    } else {
      final w0 = math.sin((1 - t) * omega) / sinOmega;
      final w1 = math.sin(t * omega) / sinOmega;
      x = a[0] * w0 + b[0] * w1;
      y = a[1] * w0 + b[1] * w1;
      z = a[2] * w0 + b[2] * w1;
    }
    // Normalize to the unit sphere, then bow outward by the altitude profile.
    final len = math.sqrt(x * x + y * y + z * z);
    final r = (1 + arc.altitude * math.sin(math.pi * t)) / (len == 0 ? 1 : len);
    out[i * 3] = x * r;
    out[i * 3 + 1] = y * r;
    out[i * 3 + 2] = z * r;
  }
}
