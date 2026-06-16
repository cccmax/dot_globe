import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'dot_globe_geometry.dart';

/// Renders the dotted globe.
///
/// Performance notes:
/// - Redraws are driven by the [repaint] Listenable — zero widget rebuilds during rotation.
/// - Projection buffers (3 depth layers for near/far opacity) are pre-allocated; zero heap
///   allocations per frame.
/// - Single-colour clouds (`geometry.colors == null`) draw each layer in one
///   [Canvas.drawRawPoints] call — the full frame costs one radial-gradient
///   circle draw plus three point-batch draws.
/// - Per-dot-colour clouds (`geometry.colors != null`) draw each layer in one
///   [Canvas.drawRawAtlas] call against a cached soft white sprite, modulated by
///   each dot's own colour; buffers are likewise pre-allocated (zero per-frame
///   allocation).
class DotGlobePainter extends CustomPainter {
  /// Creates the painter. [repaint] drives per-frame redraws.
  DotGlobePainter({
    required this.frame,
    required this.geometry,
    required this.dotColor,
    required this.sphereColor,
    required this.dotRadius,
    required this.radiusFactor,
    required Listenable repaint,
    this.glowColor,
    this.sphereLight = true,
    this.depthFade = 1.0,
  })  : _bins = List.generate(
          _binCount,
          (_) => Float32List(geometry.pointCount * 2),
        ),
        super(repaint: repaint);

  /// Current rotation pose, shared with the widget and marker layer.
  final DotGlobeFrame frame;

  /// Land-dot unit vectors.
  final DotGlobeGeometry geometry;

  /// Land-dot colour (front-facing opacity).
  final Color dotColor;

  /// Sphere base colour.
  final Color sphereColor;

  /// Rim-glow colour used for the sphere outline in dark mode.
  /// null disables rim glow entirely, preserving the original behaviour.
  final Color? glowColor;

  /// Whether to simulate front-facing lighting on the sphere.
  /// true (default) = radial gradient simulating top-left illumination;
  /// false = flat fill with [sphereColor], no highlight.
  final bool sphereLight;

  /// Strength of the depth-fade effect (0–1).
  /// Dots facing the viewer appear larger and brighter; far-side dots are
  /// smaller and dimmer, simulating depth and front lighting.
  /// 1.0 = full effect (original behaviour); 0 = disabled (uniform brightness
  /// and size across all dots, no front-highlight zone).
  final double depthFade;

  /// Radius of a single dot in logical pixels, measured at the sphere's front.
  final double dotRadius;

  /// Fraction of half the shortest side used as the sphere radius.
  final double radiusFactor;

  /// Number of depth layers (far → near); opacity and dot size increase with depth.
  static const _binCount = 3;
  static const _binAlpha = [0.30, 0.62, 1.0];
  static const _binDotScale = [0.72, 0.88, 1.0];

  final List<Float32List> _bins;
  final List<int> _binCounts = List.filled(_binCount, 0);
  final List<Paint> _dotPaints = List.generate(_binCount, (_) => Paint());

  // --- per-dot-colour (drawRawAtlas) path ---
  // Reused per-frame atlas buffers, sized to pointCount: one RSTransform (4
  // floats), one source rect (4 floats) and one colour (1 int) per visible dot.
  // Allocated lazily on the first coloured frame so the single-colour path pays
  // nothing. Bins are drawn one at a time, so a single shared set is reused
  // across all three depth bins (zero per-frame allocation).
  Float32List? _atlasRst;
  Float32List? _atlasRects;
  Int32List? _atlasColors;

  /// Cached soft white circular sprite, modulated by each dot's colour.
  static ui.Image? _sprite;
  static const int _spriteSize = 24;

  final Paint _atlasPaint = Paint()..isAntiAlias = true;

  final Paint _spherePaint = Paint();
  Size? _sphereShaderSize;

  /// Cached rim-glow shader; shares size comparison with _sphereShaderSize to avoid an extra field.
  final Paint _glowPaint = Paint();
  Size? _glowShaderSize;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.shortestSide / 2 * radiusFactor;

    // Zoom is a real canvas scale around the widget centre: dots magnify AND
    // their stroke widths grow. scale == 1.0 is the original, pixel-identical
    // path (translate by 0, scale by 1 is a no-op the engine elides).
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.scale(frame.scale);
    canvas.translate(-centerX, -centerY);

    _paintSphere(canvas, size, centerX, centerY, radius);
    if (glowColor != null) {
      _paintRimGlow(canvas, size, centerX, centerY, radius, glowColor!);
    }
    _paintDots(canvas, centerX, centerY, radius);

    canvas.restore();
  }

  /// Sphere base fill: radial gradient simulating top-left lighting (flat fill when sphereLight is false).
  void _paintSphere(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
  ) {
    if (!sphereLight) {
      _spherePaint
        ..shader = null
        ..color = sphereColor;
      canvas.drawCircle(Offset(cx, cy), r, _spherePaint);
      return;
    }
    if (_sphereShaderSize != size) {
      _sphereShaderSize = size;
      _spherePaint.shader = ui.Gradient.radial(
        Offset(cx - r * 0.35, cy - r * 0.35),
        r * 1.9,
        [
          sphereColor,
          sphereColor.withValues(alpha: sphereColor.a * 0.35),
        ],
      );
    }
    canvas.drawCircle(Offset(cx, cy), r, _spherePaint);
  }

  /// Rim glow: draws a radial-gradient circle centred on the sphere (radius r*1.12).
  /// Gradient: fully transparent inside → semi-transparent peak at the sphere edge →
  /// fully transparent outside, producing a thin halo visible only at the outline.
  /// The inner transparent stop is held until 0.84 (sphere surface sits near 0.89)
  /// to keep the glow narrow and prevent it from bleeding inward and resembling
  /// a front-facing highlight.
  void _paintRimGlow(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    Color glow,
  ) {
    if (_glowShaderSize != size) {
      _glowShaderSize = size;
      final glowRadius = r * 1.12;
      _glowPaint.shader = ui.Gradient.radial(
        Offset(cx, cy),
        glowRadius,
        [
          glow.withValues(alpha: 0.0),   // stop 0.00: centre, fully transparent
          glow.withValues(alpha: 0.0),   // stop 0.84: inner edge, fully transparent
          glow.withValues(alpha: glow.a * 0.32), // stop 0.90: peak (sphere rim)
          glow.withValues(alpha: 0.0),   // stop 1.00: outer edge, fully transparent
        ],
        [0.0, 0.84, 0.90, 1.0],
      );
    }
    canvas.drawCircle(Offset(cx, cy), r * 1.12, _glowPaint);
  }

  void _paintDots(Canvas canvas, double cx, double cy, double r) {
    // Per-dot colours take the drawRawAtlas path; otherwise the original
    // single-colour drawRawPoints path runs unchanged (pixel-identical).
    if (geometry.colors != null) {
      _paintDotsColored(canvas, cx, cy, r);
      return;
    }

    for (var b = 0; b < _binCount; b++) {
      _binCounts[b] = 0;
    }

    // Rotation matrix coefficients — only 4 trig evaluations per frame.
    final cosPhi = math.cos(frame.phi);
    final sinPhi = math.sin(frame.phi);
    final cosTheta = math.cos(frame.theta);
    final sinTheta = math.sin(frame.theta);

    final v = geometry.unitVectors;
    final count = geometry.pointCount;
    for (var i = 0; i < count; i++) {
      final j = i * 3;
      final x = v[j];
      final y = v[j + 1];
      final z = v[j + 2];
      // Rotate around Y axis (horizontal).
      final x1 = cosPhi * x + sinPhi * z;
      final z1 = -sinPhi * x + cosPhi * z;
      // Rotate around X axis (pitch).
      final y2 = cosTheta * y - sinTheta * z1;
      final z2 = sinTheta * y + cosTheta * z1;
      if (z2 <= 0) continue; // Back-face culling.

      final bin = z2 < 0.35 ? 0 : (z2 < 0.7 ? 1 : 2);
      final buf = _bins[bin];
      final n = _binCounts[bin];
      buf[n] = cx + x1 * r;
      buf[n + 1] = cy - y2 * r;
      _binCounts[bin] = n + 2;
    }

    for (var b = 0; b < _binCount; b++) {
      final n = _binCounts[b];
      if (n == 0) continue;
      // Interpolate depth-fade from no-fade (1.0) toward the per-bin constant, scaled by depthFade.
      final alpha = 1.0 + (_binAlpha[b] - 1.0) * depthFade;
      final scale = 1.0 + (_binDotScale[b] - 1.0) * depthFade;
      final paint = _dotPaints[b]
        ..color = dotColor.withValues(alpha: dotColor.a * alpha)
        ..strokeWidth = dotRadius * 2 * scale
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_bins[b], 0, n),
        paint,
      );
    }
  }

  /// Per-dot-colour draw path: one [Canvas.drawRawAtlas] per depth bin against a
  /// cached soft white sprite, with each instance modulated by its own colour
  /// (so `sprite(white) × colour = the dot colour`). Mirrors the depth binning,
  /// per-bin alpha/scale and back-face culling of [_paintDots]; additionally
  /// skips dots whose own colour alpha is 0 (hidden).
  void _paintDotsColored(Canvas canvas, double cx, double cy, double r) {
    final count = geometry.pointCount;
    final rst = _atlasRst ??= Float32List(count * 4);
    final rects = _atlasRects ??= Float32List(count * 4);
    final colors = _atlasColors ??= Int32List(count);

    final sprite = _sprite ??= _buildSprite();
    final spriteW = sprite.width.toDouble();
    final spriteH = sprite.height.toDouble();

    final cosPhi = math.cos(frame.phi);
    final sinPhi = math.sin(frame.phi);
    final cosTheta = math.cos(frame.theta);
    final sinTheta = math.sin(frame.theta);

    final v = geometry.unitVectors;
    final dotColors = geometry.colors!;

    // Draw each depth bin separately so its alpha/scale apply uniformly; reuse
    // one shared buffer set across bins (filled, drawn, refilled).
    for (var b = 0; b < _binCount; b++) {
      // Interpolate depth-fade from no-fade (1.0) toward the per-bin constant.
      final binAlpha = 1.0 + (_binAlpha[b] - 1.0) * depthFade;
      final binScale = 1.0 + (_binDotScale[b] - 1.0) * depthFade;
      final diameter = dotRadius * 2 * binScale;
      final spriteScale = diameter / spriteW;
      final lo = b == 0 ? 0.0 : (b == 1 ? 0.35 : 0.7);
      final hi = b == 0 ? 0.35 : (b == 1 ? 0.7 : double.infinity);

      var n = 0;
      for (var i = 0; i < count; i++) {
        final argb = dotColors[i];
        final ownAlpha = (argb >> 24) & 0xFF;
        if (ownAlpha == 0) continue; // hidden dot

        final j = i * 3;
        final x = v[j];
        final y = v[j + 1];
        final z = v[j + 2];
        // Rotate around Y (horizontal) then X (pitch).
        final x1 = cosPhi * x + sinPhi * z;
        final z1 = -sinPhi * x + cosPhi * z;
        final y2 = cosTheta * y - sinTheta * z1;
        final z2 = sinTheta * y + cosTheta * z1;
        if (z2 <= 0) continue; // back-face culling
        if (z2 < lo || z2 >= hi) continue; // not this depth bin

        final sx = cx + x1 * r;
        final sy = cy - y2 * r;

        // RSTransform centres the sprite on (sx, sy): rotation 0, uniform scale,
        // anchor at the sprite centre so the centre lands exactly on (sx, sy).
        final t = n * 4;
        final rstTransform = ui.RSTransform.fromComponents(
          rotation: 0,
          scale: spriteScale,
          anchorX: spriteW / 2,
          anchorY: spriteH / 2,
          translateX: sx,
          translateY: sy,
        );
        rst[t] = rstTransform.scos;
        rst[t + 1] = rstTransform.ssin;
        rst[t + 2] = rstTransform.tx;
        rst[t + 3] = rstTransform.ty;
        // Source rect: the full sprite.
        rects[t] = 0;
        rects[t + 1] = 0;
        rects[t + 2] = spriteW;
        rects[t + 3] = spriteH;
        // Final colour: own RGB, alpha = own alpha × bin alpha (depth fade).
        final a = (ownAlpha * binAlpha).clamp(0.0, 255.0).round();
        colors[n] = (a << 24) | (argb & 0x00FFFFFF);
        n++;
      }
      if (n == 0) continue;

      canvas.drawRawAtlas(
        sprite,
        Float32List.sublistView(rst, 0, n * 4),
        Float32List.sublistView(rects, 0, n * 4),
        Int32List.sublistView(colors, 0, n),
        BlendMode.modulate,
        null,
        _atlasPaint,
      );
    }
  }

  /// Builds the soft white circular sprite used by [_paintDotsColored]: a white
  /// disc with a soft radial alpha falloff, antialiased. White so BlendMode
  /// modulate yields the dot's own colour intact.
  static ui.Image _buildSprite() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = _spriteSize;
    const radius = size / 2;
    const center = Offset(radius, radius);
    // Soft radial falloff: opaque white core fading to transparent at the edge.
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        center,
        radius,
        const [
          Color(0xFFFFFFFF), // centre: opaque white
          Color(0xFFFFFFFF), // hold solid through the core
          Color(0x00FFFFFF), // edge: transparent white
        ],
        // Solid core out to 0.78 then a thin antialiased falloff — close to the
        // hard disc of the single-colour drawRawPoints path, just smoother.
        const [0.0, 0.78, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
    return recorder.endRecording().toImageSync(size, size);
  }

  @override
  bool shouldRepaint(covariant DotGlobePainter oldDelegate) {
    // Rotation redraws are driven by the repaint Listenable; this fires only on configuration changes (state rebuilds the painter).
    return oldDelegate.geometry != geometry ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.sphereColor != sphereColor ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.radiusFactor != radiusFactor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.sphereLight != sphereLight ||
        oldDelegate.depthFade != depthFade;
  }
}
