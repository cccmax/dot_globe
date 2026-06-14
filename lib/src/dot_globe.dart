import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dot_globe_arc.dart';
import 'dot_globe_arc_painter.dart';
import 'dot_globe_controller.dart';
import 'dot_globe_geometry.dart';
import 'dot_globe_painter.dart';
import 'dot_globe_style.dart';

/// A marker pinned to a [DotGlobe] at a latitude/longitude. The [child] can be
/// any widget — a flag, a label, a price bubble — and is projected onto the
/// sphere, hidden when it rotates to the back, and faded near the silhouette.
@immutable
class DotGlobeMarker {
  /// Creates a marker. [latitude]/[longitude] are in degrees.
  const DotGlobeMarker({
    required this.latitude,
    required this.longitude,
    required this.child,
    this.anchor = Alignment.center,
  });

  /// Latitude in degrees, north positive.
  final double latitude;

  /// Longitude in degrees, east positive.
  final double longitude;

  /// The widget drawn at this coordinate. Fades out and stops receiving taps
  /// once it rotates to the back of the globe.
  final Widget child;

  /// Which point of [child] sits on the projected coordinate. Use
  /// [Alignment.bottomCenter] for a bubble whose tail points down at the spot.
  final Alignment anchor;
}

/// A dotted (halftone) 3D globe — spin it, and drop any widget as a lat/lng
/// marker. Pure Dart, no native code, no texture assets.
///
/// The globe paints in two layers:
/// * a canvas of ~6300 land dots ([DotGlobePainter], a single batched
///   `drawRawPoints` per depth band — rotation never rebuilds a widget), and
/// * a widget layer where each [DotGlobeMarker] is re-positioned every frame by
///   a [Flow] (transform only, no relayout).
///
/// Style it with a [DotGlobeStyle] preset:
///
/// ```dart
/// DotGlobe(
///   style: DotGlobeStyle.dark,
///   markers: [
///     DotGlobeMarker(
///       latitude: 46, longitude: 2,
///       anchor: Alignment.bottomCenter,
///       child: FlagBubble(flag: '🇫🇷', text: '16%'),
///     ),
///   ],
/// )
/// ```
///
/// Drive it imperatively with a [DotGlobeController].
class DotGlobe extends StatefulWidget {
  /// Creates a dotted globe.
  const DotGlobe({
    super.key,
    this.style = DotGlobeStyle.light,
    this.markers = const [],
    this.arcs = const [],
    this.controller,
    this.radiusFactor = 0.92,
    this.autoRotateSpeed = 0.12,
    this.initialLatitude = 18,
    this.initialLongitude = 10,
    this.maxTilt = 0.6,
    this.dragSensitivity = 1.0,
    this.inertiaDecay = 0.94,
    this.tiltReturn = 0.92,
    this.interactive = true,
    this.paused = false,
  })  : assert(radiusFactor > 0, 'radiusFactor must be > 0'),
        assert(
          inertiaDecay >= 0 && inertiaDecay < 1,
          'inertiaDecay must be in [0, 1)',
        ),
        assert(
          tiltReturn >= 0 && tiltReturn < 1,
          'tiltReturn must be in [0, 1)',
        );

  /// Visual configuration — colours, lighting, dot size. Defaults to
  /// [DotGlobeStyle.light]. Pick a preset or build your own.
  final DotGlobeStyle style;

  /// Markers pinned to the globe.
  final List<DotGlobeMarker> markers;

  /// Great-circle arcs (connection / flight lines) drawn over the globe,
  /// beneath the markers.
  final List<DotGlobeArc> arcs;

  /// Optional imperative handle to spin the globe and read its facing point.
  final DotGlobeController? controller;

  /// Sphere radius as a fraction of half the widget's shortest side.
  final double radiusFactor;

  /// Idle spin speed in radians per second. `0` leaves the globe still when not
  /// being dragged.
  final double autoRotateSpeed;

  /// Latitude (degrees) the pitch rests at — also the spring-back target after
  /// a vertical drag.
  final double initialLatitude;

  /// Longitude (degrees) facing the viewer at first build.
  final double initialLongitude;

  /// Maximum pitch deviation from the rest latitude, in radians.
  final double maxTilt;

  /// Multiplier on drag-to-rotation mapping. `1.0` means dragging one sphere
  /// radius rotates ~1 radian; raise for a faster, lower for a slower feel.
  final double dragSensitivity;

  /// Per-frame (at 60 fps) retention of fling velocity after release, in
  /// `[0, 1)`. Higher spins longer before settling back to [autoRotateSpeed].
  final double inertiaDecay;

  /// Per-frame (at 60 fps) retention of pitch offset while springing back to
  /// the rest latitude, in `[0, 1)`. Higher returns more slowly.
  final double tiltReturn;

  /// Whether drags rotate the globe.
  final bool interactive;

  /// Pauses the frame loop (auto-rotation, inertia, pitch spring-back) so the
  /// globe costs nothing while off-screen within the same route. Pair it with a
  /// visibility detector. Globes covered by another route or backgrounded are
  /// stopped by the framework automatically — you don't need this for that.
  final bool paused;

  @override
  State<DotGlobe> createState() => _DotGlobeState();
}

class _DotGlobeState extends State<DotGlobe>
    with SingleTickerProviderStateMixin
    implements DotGlobeBinding {
  late final Ticker _ticker;
  final DotGlobeFrame _frame = DotGlobeFrame();

  /// Per-frame repaint signal: the painter and the marker [Flow] both listen,
  /// so rotation never triggers a rebuild.
  final _RepaintNotifier _repaint = _RepaintNotifier();

  DotGlobeGeometry? _geometry;
  DotGlobePainter? _painter;
  DotGlobeArcPainter? _arcPainter;

  bool _dragging = false;
  double _phiVelocity = 0; // rad/s
  Duration _lastTick = Duration.zero;
  double _radius = 1; // current sphere radius (px), for gesture mapping

  // Programmatic animation (driven inside the same ticker).
  bool _animating = false;
  double _animFromPhi = 0;
  double _animToPhi = 0;
  double _animFromTheta = 0;
  double _animToTheta = 0;
  double _animElapsed = 0; // seconds
  double _animDuration = 0; // seconds
  Curve _animCurve = Curves.linear;
  Completer<void>? _animCompleter;

  double get _restTheta => widget.initialLatitude * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _frame.phi = math.pi / 2 - widget.initialLongitude * math.pi / 180;
    _frame.theta = _restTheta;
    _ticker = createTicker(_onTick);
    widget.controller?.attach(this);
    _startTickerIfNeeded();
    _loadGeometry();
  }

  Future<void> _loadGeometry() async {
    try {
      final geometry = await DotGlobeGeometry.load();
      if (!mounted) return;
      setState(() => _geometry = geometry);
    } on Object catch (e) {
      // A missing asset throws a FlutterError (an Error, not an Exception), so
      // catch broadly; degrade to just the sphere base instead of letting the
      // failure escape as an uncaught error.
      debugPrint('[DotGlobe] geometry load failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant DotGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (oldWidget.style != widget.style) {
      _painter = null; // visual params changed; rebuild painter in build()
    }
    if (oldWidget.arcs != widget.arcs) {
      _arcPainter = null; // arcs changed; re-sample in build()
    }
    if (oldWidget.interactive && !widget.interactive) {
      // A GestureDetector removed from the tree is not guaranteed to fire
      // onPanCancel; reset defensively so the animation can't freeze.
      _dragging = false;
    }
    if (oldWidget.initialLongitude != widget.initialLongitude) {
      // Keep accumulated rotation; shift wholesale to the new initial longitude.
      _frame.phi += (oldWidget.initialLongitude - widget.initialLongitude) *
          math.pi /
          180;
    }
    // Clamp pitch back into range when maxTilt narrows or initialLatitude moves;
    // the residual eases home via the spring-back in _onTick.
    _frame.theta = _frame.theta.clamp(
      _restTheta - widget.maxTilt,
      _restTheta + widget.maxTilt,
    );
    if (oldWidget.paused != widget.paused && widget.paused) {
      _phiVelocity = 0; // drop inertia when paused; don't replay on resume
      _finishAnimation();
      _ticker.stop();
    }
    _startTickerIfNeeded();
    _repaint.ping(); // apply param changes on the next frame, not the next tick
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _finishAnimation();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  // ---- frame loop ----

  void _startTickerIfNeeded() {
    if (widget.paused) return;
    if (!_ticker.isActive && _needsTick) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  /// Whether anything still needs driving: auto-rotation, residual inertia,
  /// pitch not yet settled, or a running programmatic animation.
  bool get _needsTick =>
      _animating ||
      widget.autoRotateSpeed.abs() > 1e-6 ||
      _phiVelocity.abs() > 1e-3 ||
      (_frame.theta - _restTheta).abs() > 1e-3;

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    // dt can be huge after a background/resume; clamp to avoid a jump.
    final dt = math.min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 15);
    _lastTick = elapsed;

    if (_animating) {
      _advanceAnimation(dt);
    } else if (!_dragging) {
      // Inertia eases toward the auto-rotate speed (0.94/frame @60fps, scaled
      // by dt to stay frame-rate independent).
      final decay = math.pow(widget.inertiaDecay, dt * 60).toDouble();
      _phiVelocity =
          widget.autoRotateSpeed + (_phiVelocity - widget.autoRotateSpeed) * decay;
      _frame.phi += _phiVelocity * dt;

      // Pitch eases back to rest.
      final tiltKeep = math.pow(widget.tiltReturn, dt * 60).toDouble();
      _frame.theta = _restTheta + (_frame.theta - _restTheta) * tiltKeep;

      if (!_needsTick) {
        _phiVelocity = 0;
        _frame.theta = _restTheta;
        _ticker.stop();
      }
    }
    _repaint.ping();
    widget.controller?.notifyFacingChanged();
  }

  // ---- programmatic animation ----

  void _advanceAnimation(double dt) {
    _animElapsed += dt;
    final t =
        _animDuration <= 0 ? 1.0 : (_animElapsed / _animDuration).clamp(0.0, 1.0);
    final e = _animCurve.transform(t);
    _frame.phi = _animFromPhi + (_animToPhi - _animFromPhi) * e;
    _frame.theta = _animFromTheta + (_animToTheta - _animFromTheta) * e;
    if (t >= 1.0) {
      _animating = false;
      final completer = _animCompleter;
      _animCompleter = null;
      completer?.complete();
      if (!_needsTick) _ticker.stop();
    }
  }

  /// Completes any in-flight animation immediately (superseded / disposed).
  void _finishAnimation() {
    _animating = false;
    final completer = _animCompleter;
    _animCompleter = null;
    completer?.complete();
  }

  // ---- DotGlobeBinding ----

  @override
  DotGlobeFacing currentFacing() {
    final lng = _normalizeLng((math.pi / 2 - _frame.phi) * 180 / math.pi);
    final lat = _frame.theta * 180 / math.pi;
    return DotGlobeFacing(lat, lng);
  }

  @override
  Future<void> animateFacingTo({
    double? latitude,
    double? longitude,
    required Duration duration,
    required Curve curve,
  }) {
    _finishAnimation(); // supersede any running animation
    _dragging = false;

    _animFromPhi = _frame.phi;
    _animFromTheta = _frame.theta;

    if (longitude != null) {
      final targetRaw = math.pi / 2 - longitude * math.pi / 180;
      // shortest angular path from current phi
      final delta = _shortestAngle(targetRaw - _frame.phi);
      _animToPhi = _frame.phi + delta;
    } else {
      _animToPhi = _frame.phi;
    }
    _animToTheta = latitude != null
        ? (latitude * math.pi / 180)
            .clamp(_restTheta - widget.maxTilt, _restTheta + widget.maxTilt)
        : _frame.theta;

    _animElapsed = 0;
    _animDuration = duration.inMicroseconds / 1e6;
    _animCurve = curve;
    _animating = true;
    final completer = Completer<void>();
    _animCompleter = completer;
    _startTickerIfNeeded();
    return completer.future;
  }

  @override
  void jumpFacingTo({double? latitude, double? longitude}) {
    _finishAnimation();
    if (longitude != null) {
      _frame.phi = math.pi / 2 - longitude * math.pi / 180;
    }
    if (latitude != null) {
      _frame.theta = (latitude * math.pi / 180)
          .clamp(_restTheta - widget.maxTilt, _restTheta + widget.maxTilt);
    }
    _repaint.ping();
    widget.controller?.notifyFacingChanged();
    _startTickerIfNeeded();
  }

  static double _shortestAngle(double d) => math.atan2(math.sin(d), math.cos(d));

  static double _normalizeLng(double deg) {
    var d = deg % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  // ---- gestures ----

  void _onPanStart(DragStartDetails details) {
    _finishAnimation(); // a drag cancels a programmatic move
    _dragging = true;
    _phiVelocity = 0;
    _startTickerIfNeeded();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Pixel delta -> angular delta: dragging one radius ~ 1 rad, scaled by
    // dragSensitivity.
    final k = widget.dragSensitivity / _radius;
    _frame.phi += details.delta.dx * k;
    _frame.theta = (_frame.theta + details.delta.dy * k).clamp(
      _restTheta - widget.maxTilt,
      _restTheta + widget.maxTilt,
    );
    _repaint.ping();
    widget.controller?.notifyFacingChanged();
  }

  void _onPanEnd(DragEndDetails details) {
    _dragging = false;
    // Convert fling velocity to angular velocity and clamp; the tick loop
    // decays it back toward the auto-rotate speed.
    _phiVelocity = (details.velocity.pixelsPerSecond.dx *
            widget.dragSensitivity /
            _radius)
        .clamp(-2.5, 2.5);
    _startTickerIfNeeded();
  }

  void _onPanCancel() {
    _dragging = false;
    _startTickerIfNeeded();
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _radius = math.max(1, size.shortestSide / 2 * widget.radiusFactor);

        final geometry = _geometry;
        if (geometry != null) {
          _painter ??= DotGlobePainter(
            frame: _frame,
            geometry: geometry,
            dotColor: widget.style.dotColor,
            sphereColor: widget.style.sphereColor,
            dotRadius: widget.style.dotRadius,
            radiusFactor: widget.radiusFactor,
            repaint: _repaint,
            glowColor: widget.style.glowColor,
            sphereLight: widget.style.sphereLight,
            depthFade: widget.style.depthFade,
          );
        }

        if (widget.arcs.isNotEmpty) {
          _arcPainter ??= DotGlobeArcPainter(
            frame: _frame,
            arcs: widget.arcs,
            radiusFactor: widget.radiusFactor,
            repaint: _repaint,
          );
        }

        Widget body = Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom: the dotted sphere canvas, isolated so it and the markers
            // don't drag each other into repaints.
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _painter),
              ),
            ),
            // Middle: great-circle arcs over the globe, beneath the markers.
            if (widget.arcs.isNotEmpty)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _arcPainter),
                ),
              ),
            // Top: the marker widget layer; Flow re-positions with transforms.
            if (widget.markers.isNotEmpty)
              Positioned.fill(
                child: Flow(
                  clipBehavior: Clip.none,
                  delegate: _MarkerFlowDelegate(
                    frame: _frame,
                    markers: widget.markers,
                    radiusFactor: widget.radiusFactor,
                    repaint: _repaint,
                  ),
                  children: [
                    for (final marker in widget.markers)
                      RepaintBoundary(child: marker.child),
                  ],
                ),
              ),
          ],
        );

        final background = widget.style.backgroundColor;
        if (background != null) {
          body = ColoredBox(color: background, child: body);
        }

        if (widget.interactive) {
          // An eager pan recognizer claims drags inside the globe before an
          // ancestor Scrollable can: a plain PanGestureRecognizer's slop
          // (kPanSlop = 36px) is larger than scroll's kTouchSlop (18px), so the
          // scrollable would otherwise win every vertical/horizontal drag.
          // _EagerPanGestureRecognizer declares victory after 6px, so drags on
          // the globe stay with the globe (like touch-action:none on web); a
          // tap with no movement never triggers the claim, so marker onTap is
          // unaffected.
          body = RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _EagerPanGestureRecognizer>(
                () => _EagerPanGestureRecognizer(),
                (recognizer) {
                  recognizer
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onPanStart
                    ..onUpdate = _onPanUpdate
                    ..onEnd = _onPanEnd
                    ..onCancel = _onPanCancel;
                },
              ),
            },
            child: body,
          );
        }
        return body;
      },
    );
  }
}

class _RepaintNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Eager pan recognizer: once cumulative movement passes [_claimDistance] — far
/// below scroll's kTouchSlop (18px) — it wins the gesture arena immediately, so
/// drags inside the globe aren't stolen by an ancestor scrollable or horizontal
/// gesture. The 6px threshold is larger than the finger jitter of a tap (1–2px),
/// so taps are unaffected, but smaller than scroll's slop, so a drag always wins
/// first.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  static const double _claimDistance = 6;

  Offset _moved = Offset.zero;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _moved = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _moved += event.delta;
      if (_moved.distance > _claimDistance) {
        // Calling resolve(accepted) repeatedly is harmless; the arena acts once.
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }
}

/// Marker layout: every frame, translate each child to its projected position.
/// [Flow] only re-paints (with transform/opacity); it never relayouts or
/// rebuilds the children. Back-facing markers are skipped, so they also stop
/// hit-testing.
class _MarkerFlowDelegate extends FlowDelegate {
  _MarkerFlowDelegate({
    required this.frame,
    required this.markers,
    required this.radiusFactor,
    required Listenable repaint,
  })  : _vectors = Float32List(markers.length * 3),
        super(repaint: repaint) {
    final tmp = Float64List(3);
    for (var i = 0; i < markers.length; i++) {
      DotGlobeGeometry.latLngToUnitVector(
        markers[i].latitude,
        markers[i].longitude,
        tmp,
      );
      _vectors[i * 3] = tmp[0];
      _vectors[i * 3 + 1] = tmp[1];
      _vectors[i * 3 + 2] = tmp[2];
    }
  }

  final DotGlobeFrame frame;
  final List<DotGlobeMarker> markers;
  final double radiusFactor;

  /// Precomputed marker unit vectors, laid out like the geometry.
  final Float32List _vectors;

  /// Depth at which a marker starts fading out; below 0 it is fully hidden.
  static const double _fadeDepth = 0.18;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  void paintChildren(FlowPaintingContext context) {
    final size = context.size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.shortestSide / 2 * radiusFactor;

    final cosPhi = math.cos(frame.phi);
    final sinPhi = math.sin(frame.phi);
    final cosTheta = math.cos(frame.theta);
    final sinTheta = math.sin(frame.theta);

    for (var i = 0; i < context.childCount; i++) {
      final x = _vectors[i * 3];
      final y = _vectors[i * 3 + 1];
      final z = _vectors[i * 3 + 2];
      final x1 = cosPhi * x + sinPhi * z;
      final z1 = -sinPhi * x + cosPhi * z;
      final y2 = cosTheta * y - sinTheta * z1;
      final z2 = sinTheta * y + cosTheta * z1;
      if (z2 <= 0) continue; // back face: don't paint, don't hit-test

      final opacity = math.min(1.0, z2 / _fadeDepth);
      final childSize = context.getChildSize(i) ?? Size.zero;
      final anchor = markers[i].anchor;
      // Align the anchor to the projected point.
      final dx = centerX +
          x1 * radius -
          childSize.width / 2 -
          anchor.x * childSize.width / 2;
      final dy = centerY -
          y2 * radius -
          childSize.height / 2 -
          anchor.y * childSize.height / 2;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(dx, dy, 0),
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerFlowDelegate oldDelegate) {
    // Rotation repaints go through the repaint Listenable; only a changed
    // marker list needs the projection cache rebuilt.
    return oldDelegate.markers != markers ||
        oldDelegate.radiusFactor != radiusFactor;
  }

  @override
  bool shouldRelayout(covariant _MarkerFlowDelegate oldDelegate) =>
      oldDelegate.markers != markers;
}
