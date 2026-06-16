import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'dot_globe_arc.dart';
import 'dot_globe_geometry.dart';

/// Paints great-circle [DotGlobeArc]s over the globe.
///
/// Each arc is pre-sampled into 3D points (slerp + altitude bow); every frame
/// the points are rotated by the shared [frame] and projected orthographically.
/// Runs facing the viewer are stroked solid (with an optional glow); runs
/// curving around the back are dashed and faded.
class DotGlobeArcPainter extends CustomPainter {
  /// Creates the arc painter and pre-samples every arc.
  DotGlobeArcPainter({
    required this.frame,
    required this.arcs,
    required this.radiusFactor,
    required Listenable repaint,
  })  : _samples = List.generate(
          arcs.length,
          (_) => Float32List(_kSamples * 3),
        ),
        super(repaint: repaint) {
    for (var i = 0; i < arcs.length; i++) {
      sampleGreatCircleArc(arcs[i], _kSamples, _samples[i]);
    }
  }

  /// Current rotation pose, shared with the dot painter and marker layer.
  final DotGlobeFrame frame;

  /// The arcs to draw.
  final List<DotGlobeArc> arcs;

  /// Sphere radius as a fraction of half the shortest side (matches the globe).
  final double radiusFactor;

  static const int _kSamples = 56;

  /// Pre-sampled 3D points per arc, length-encoding the altitude bow.
  final List<Float32List> _samples;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide / 2 * radiusFactor;

    // Match the dot painter's zoom: a real canvas scale around the widget
    // centre so arcs and their stroke widths grow together with the globe.
    // scale == 1.0 is the original, pixel-identical path.
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(frame.scale);
    canvas.translate(-cx, -cy);

    final cosPhi = math.cos(frame.phi);
    final sinPhi = math.sin(frame.phi);
    final cosTheta = math.cos(frame.theta);
    final sinTheta = math.sin(frame.theta);

    for (var ai = 0; ai < arcs.length; ai++) {
      final arc = arcs[ai];
      final v = _samples[ai];

      // Walk the sampled points, splitting into front (z >= 0) and back runs.
      // At each front/back crossing, interpolate the exact z = 0 point and
      // join both runs to it so there is no gap where the arc dips behind.
      final frontPath = Path();
      final backPath = Path();
      var hasPrev = false;
      var prevSx = 0.0;
      var prevSy = 0.0;
      var prevZ = 0.0;
      var prevFront = false;

      for (var i = 0; i < _kSamples; i++) {
        final x = v[i * 3];
        final y = v[i * 3 + 1];
        final z = v[i * 3 + 2];
        final x1 = cosPhi * x + sinPhi * z;
        final z1 = -sinPhi * x + cosPhi * z;
        final y2 = cosTheta * y - sinTheta * z1;
        final z2 = sinTheta * y + cosTheta * z1;
        final sx = cx + x1 * r;
        final sy = cy - y2 * r;
        final front = z2 >= 0;

        if (!hasPrev) {
          (front ? frontPath : backPath).moveTo(sx, sy);
        } else if (front == prevFront) {
          (front ? frontPath : backPath).lineTo(sx, sy);
        } else {
          // Crossing: split at z = 0 so the two halves share the seam point.
          final t = prevZ / (prevZ - z2);
          final mx = prevSx + (sx - prevSx) * t;
          final my = prevSy + (sy - prevSy) * t;
          if (prevFront) {
            frontPath.lineTo(mx, my);
            backPath
              ..moveTo(mx, my)
              ..lineTo(sx, sy);
          } else {
            backPath.lineTo(mx, my);
            frontPath
              ..moveTo(mx, my)
              ..lineTo(sx, sy);
          }
        }

        hasPrev = true;
        prevSx = sx;
        prevSy = sy;
        prevZ = z2;
        prevFront = front;
      }

      // Back half: curves into space / around the rim — faded (and dashed)
      // by the arc's own settings.
      if (arc.backOpacity > 0) {
        _stroke
          ..color = arc.color.withValues(alpha: arc.color.a * arc.backOpacity)
          ..strokeWidth = arc.width;
        canvas.drawPath(
          arc.backDashed ? _dash(backPath, arc.dashLength, arc.dashGap) : backPath,
          _stroke,
        );
      }

      // Front half: optional glow underlay, then the main stroke.
      if (arc.glow) {
        _glow
          ..color = arc.color.withValues(alpha: arc.color.a * 0.35)
          ..strokeWidth = arc.width * 3;
        canvas.drawPath(frontPath, _glow);
      }
      _stroke
        ..color = arc.color
        ..strokeWidth = arc.width;
      canvas.drawPath(
        arc.dashed ? _dash(frontPath, arc.dashLength, arc.dashGap) : frontPath,
        _stroke,
      );
    }

    canvas.restore();
  }

  /// Splits a path into dashes via its metrics.
  Path _dash(Path source, double dash, double gap) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = math.min(dash, metric.length - dist);
        dest.addPath(metric.extractPath(dist, dist + len), Offset.zero);
        dist += dash + gap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DotGlobeArcPainter oldDelegate) =>
      oldDelegate.arcs != arcs || oldDelegate.radiusFactor != radiusFactor;
}
