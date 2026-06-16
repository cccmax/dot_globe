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
    this.scaleWithZoom,
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

  /// Whether this marker grows with the globe's zoom. When `null` (default), it
  /// inherits [DotGlobe.markersScaleWithZoom]. `false` keeps the marker at its
  /// natural size (crisp, never magnified) while still tracking the zoomed
  /// position; `true` magnifies it by the current zoom factor about [anchor].
  final bool? scaleWithZoom;
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
    this.geometry,
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
    this.initialScale = 1.0,
    this.minScale = 1.0,
    this.maxScale = 6.0,
    this.zoomGesture = true,
    this.clipBehavior = Clip.none,
    this.markersScaleWithZoom = true,
  })  : assert(radiusFactor > 0, 'radiusFactor must be > 0'),
        assert(
          inertiaDecay >= 0 && inertiaDecay < 1,
          'inertiaDecay must be in [0, 1)',
        ),
        assert(
          tiltReturn >= 0 && tiltReturn < 1,
          'tiltReturn must be in [0, 1)',
        ),
        assert(minScale > 0, 'minScale must be > 0'),
        assert(
          maxScale >= minScale,
          'maxScale must be >= minScale',
        ),
        assert(
          initialScale >= minScale && initialScale <= maxScale,
          'initialScale must be within [minScale, maxScale]',
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

  /// Custom dot cloud to render instead of the bundled Earth landmass. When
  /// null (default), the built-in ~6300-point Earth is used. Build one with
  /// [DotGlobeGeometry.fromLatLng] / [DotGlobeGeometry.fromPackedInt16] /
  /// [DotGlobeGeometry.fromAsset] / [DotGlobeGeometry.fromUnitVectors]. Markers
  /// and arcs are positioned by lat/lng, so they only line up with a custom
  /// cloud that uses the standard axis convention ([DotGlobeGeometry.fromLatLng]
  /// / [DotGlobeGeometry.fromPackedInt16] guarantee it).
  final DotGlobeGeometry? geometry;

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

  /// Zoom factor at first build, clamped to `[minScale, maxScale]`. `1.0`
  /// (default) is the natural size.
  final double initialScale;

  /// Lower bound for the zoom factor (gesture and programmatic). Must be `> 0`;
  /// defaults to `1.0` (no zooming out below the natural size).
  final double minScale;

  /// Upper bound for the zoom factor (gesture and programmatic). Must be
  /// `>= minScale`; defaults to `6.0`. When `maxScale <= minScale` zooming is a
  /// no-op.
  final double maxScale;

  /// Whether a two-finger pinch zooms the globe. No-op when
  /// `maxScale <= minScale`. One-finger rotation works regardless.
  final bool zoomGesture;

  /// How a zoomed-in globe is clipped to its container. [Clip.none] (default)
  /// preserves today's behaviour, letting markers and a magnified globe spill
  /// outside the bounds; [Clip.hardEdge] keeps the zoomed globe inside.
  final Clip clipBehavior;

  /// Default for whether markers grow with zoom. Each [DotGlobeMarker] can
  /// override this via [DotGlobeMarker.scaleWithZoom]. `true` (default)
  /// magnifies markers with the globe; `false` keeps them at natural size.
  final bool markersScaleWithZoom;

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
  double _scaleAtGestureStart = 1; // _frame.scale captured at gesture start

  /// Parked: a `hold` move arrived and the globe is frozen at its destination
  /// (no auto-rotation, no pitch spring-back) until the next drag or move.
  bool _parked = false;

  // Programmatic animation (driven inside the same ticker).
  bool _animating = false;
  double _animFromPhi = 0;
  double _animToPhi = 0;
  double _animFromTheta = 0;
  double _animToTheta = 0;
  double _animFromScale = 1;
  double _animToScale = 1;
  bool _animHold = false; // park on arrival when this animation completes
  bool _animMovesOrbit = false; // this animation retargets the spin orbit
  double _animElapsed = 0; // seconds
  double _animDuration = 0; // seconds
  Curve _animCurve = Curves.linear;
  Completer<void>? _animCompleter;

  /// Latitude (radians) the globe orbits at and the pitch springs back to.
  /// Starts at [DotGlobe.initialLatitude]; each fly-to with a latitude moves it,
  /// so "keep spinning" stays at the latitude you flew to, and a drag springs
  /// back to it. [DotGlobeController.resetView] restores [DotGlobe.initialLatitude].
  double _restThetaValue = 0;
  double get _restTheta => _restThetaValue;

  /// Hard pitch limit for a programmatic fly-to (~85°, just shy of the poles).
  /// A drag is still confined to `maxTilt` around the current orbit.
  static const double _kMaxPitch = math.pi / 2 * 0.94;

  @override
  void initState() {
    super.initState();
    _frame.phi = math.pi / 2 - widget.initialLongitude * math.pi / 180;
    _restThetaValue = widget.initialLatitude * math.pi / 180;
    _frame.theta = _restThetaValue;
    _frame.scale = widget.initialScale;
    _ticker = createTicker(_onTick);
    widget.controller?.attach(this);
    _startTickerIfNeeded();
    _loadGeometry();
  }

  Future<void> _loadGeometry() async {
    // A caller-supplied cloud is used directly — no asset load, no global cache.
    final supplied = widget.geometry;
    if (supplied != null) {
      if (!mounted) return;
      setState(() => _geometry = supplied);
      return;
    }
    try {
      final geometry = await DotGlobeGeometry.load();
      if (!mounted) return;
      // A custom cloud may have been supplied while this built-in load was
      // in flight; the synchronous assignment wins, so don't overwrite it.
      if (widget.geometry != null) return;
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
    if (oldWidget.geometry != widget.geometry) {
      _painter = null; // point cloud changed; rebuild painter in build()
      final supplied = widget.geometry;
      if (supplied != null) {
        // Assign synchronously so it supersedes any in-flight built-in load().
        _geometry = supplied;
      } else {
        // Reverted to the built-in cloud; reload (cached after first time).
        _geometry = null;
        unawaited(_loadGeometry());
      }
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
    if (oldWidget.initialLatitude != widget.initialLatitude) {
      // A changed initialLatitude prop resets the spin orbit (it is the rest /
      // resetView target); the residual eases home via the spring-back in _onTick.
      _restThetaValue = widget.initialLatitude * math.pi / 180;
    }
    // Re-clamp pitch ONLY when the tilt window actually moved (maxTilt narrowed
    // or the rest orbit changed) and no animation is running. Clamping on an
    // ordinary rebuild would fight an in-flight fly-to: an arbitrary rebuild
    // (e.g. a parent calling setState every frame to read the facing) would
    // snap the animating theta to `orbit ± maxTilt`, so a north→south fly would
    // jump to the clamp boundary mid-flight instead of moving point-to-point.
    if (!_animating &&
        (oldWidget.maxTilt != widget.maxTilt ||
            oldWidget.initialLatitude != widget.initialLatitude)) {
      _frame.theta = _frame.theta.clamp(
        _restTheta - widget.maxTilt,
        _restTheta + widget.maxTilt,
      );
    }
    // Likewise re-clamp zoom only when the bounds changed. A changed
    // initialScale alone is intentionally NOT re-applied — it is the first-build
    // value (and the resetView target), not a live setter, so the user's
    // current zoom is preserved across rebuilds.
    if (!_animating &&
        (oldWidget.minScale != widget.minScale ||
            oldWidget.maxScale != widget.maxScale)) {
      _frame.scale = _frame.scale.clamp(widget.minScale, widget.maxScale);
    }
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
  /// pitch not yet settled, or a running programmatic animation. A parked globe
  /// needs nothing (it sits frozen at its destination), so the ticker stops.
  bool get _needsTick {
    if (_parked) return false;
    return _animating ||
        widget.autoRotateSpeed.abs() > 1e-6 ||
        _phiVelocity.abs() > 1e-3 ||
        (_frame.theta - _restTheta).abs() > 1e-3;
  }

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
    } else if (!_dragging && !_parked) {
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
    _frame.scale = _animFromScale + (_animToScale - _animFromScale) * e;
    if (t >= 1.0) {
      _animating = false;
      // Arrived: the destination latitude becomes the new spin orbit.
      if (_animMovesOrbit) _restThetaValue = _animToTheta;
      // hold => park at the destination (no auto-rotate / pitch spring-back);
      // this flips _needsTick to false below, so the ticker stops.
      _parked = _animHold;
      final completer = _animCompleter;
      _animCompleter = null;
      completer?.complete();
      if (!_needsTick) _ticker.stop();
    }
  }

  /// Completes any in-flight animation immediately (superseded / disposed).
  void _finishAnimation() {
    // An interrupted orbit-moving fly-to keeps the spin orbit where the globe
    // actually is now, so idle spring-back doesn't drift to the unreached target.
    if (_animating && _animMovesOrbit) _restThetaValue = _frame.theta;
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
  double currentScale() => _frame.scale;

  @override
  Future<void> animateFacingTo({
    double? latitude,
    double? longitude,
    double? scale,
    bool hold = false,
    required Duration duration,
    required Curve curve,
  }) {
    _finishAnimation(); // supersede any running animation
    _dragging = false;
    _parked = false; // a fresh move unparks; re-parks on arrival if hold
    _animHold = hold;

    _animFromPhi = _frame.phi;
    _animFromTheta = _frame.theta;
    _animFromScale = _frame.scale;

    if (longitude != null) {
      final targetRaw = math.pi / 2 - longitude * math.pi / 180;
      // shortest angular path from current phi
      final delta = _shortestAngle(targetRaw - _frame.phi);
      _animToPhi = _frame.phi + delta;
    } else {
      _animToPhi = _frame.phi;
    }
    // A fly-to with a latitude retargets the spin orbit — but only commit it on
    // ARRIVAL (or, if interrupted, to where the globe actually is), never at the
    // start, or an interrupted fly-to would drift to a latitude it never reached.
    _animMovesOrbit = latitude != null;
    if (latitude != null) {
      // A fly-to may reach any latitude (clamped only near the poles).
      _animToTheta = (latitude * math.pi / 180).clamp(-_kMaxPitch, _kMaxPitch);
    } else {
      _animToTheta = _frame.theta;
    }
    _animToScale = scale != null
        ? scale.clamp(widget.minScale, widget.maxScale)
        : _frame.scale;

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
  Future<void> resetView({
    required Duration duration,
    required Curve curve,
  }) {
    return animateFacingTo(
      latitude: widget.initialLatitude,
      longitude: widget.initialLongitude,
      scale: widget.initialScale,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void jumpFacingTo({
    double? latitude,
    double? longitude,
    double? scale,
    bool hold = false,
  }) {
    _finishAnimation();
    if (longitude != null) {
      _frame.phi = math.pi / 2 - longitude * math.pi / 180;
    }
    if (latitude != null) {
      _frame.theta = (latitude * math.pi / 180).clamp(-_kMaxPitch, _kMaxPitch);
      _restThetaValue = _frame.theta; // jump also moves the spin orbit
    }
    if (scale != null) {
      _frame.scale = scale.clamp(widget.minScale, widget.maxScale);
    }
    _parked = hold; // hold => freeze here; otherwise idle physics resume below
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

  void _onScaleStart(ScaleStartDetails details) {
    _finishAnimation(); // a drag cancels a programmatic move
    _dragging = true;
    _parked = false; // grabbing the globe unparks it; idle physics resume on release
    _phiVelocity = 0;
    _scaleAtGestureStart = _frame.scale; // d.scale is cumulative from here
    _startTickerIfNeeded();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Rotation from the focal point delta — works for one finger (a pan) and
    // for the centre of a two-finger pinch alike. Pixel delta -> angular delta:
    // dragging one (zoomed) radius ~ 1 rad, scaled by dragSensitivity. Dividing
    // by the on-screen radius (_radius * scale) makes a zoomed-in globe rotate
    // proportionally finer.
    final k = widget.dragSensitivity / (_radius * _frame.scale);
    _frame.phi += details.focalPointDelta.dx * k;
    // Drag tilts within maxTilt of the current orbit, never past the poles.
    final lo = math.max(_restTheta - widget.maxTilt, -_kMaxPitch);
    final hi = math.min(_restTheta + widget.maxTilt, _kMaxPitch);
    _frame.theta = (_frame.theta + details.focalPointDelta.dy * k).clamp(lo, hi);

    // Pinch zoom: d.scale is the cumulative pinch ratio since the gesture
    // started, so multiply the captured start scale and clamp.
    if (widget.zoomGesture && widget.maxScale > widget.minScale) {
      _frame.scale = (_scaleAtGestureStart * details.scale)
          .clamp(widget.minScale, widget.maxScale);
    }

    _repaint.ping();
    widget.controller?.notifyFacingChanged();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _dragging = false;
    // Convert fling velocity to angular velocity and clamp; the tick loop
    // decays it back toward the auto-rotate speed. Map through the on-screen
    // radius so the feel matches the (zoom-aware) drag sensitivity.
    _phiVelocity = (details.velocity.pixelsPerSecond.dx *
            widget.dragSensitivity /
            (_radius * _frame.scale))
        .clamp(-2.5, 2.5);
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
                    defaultScaleWithZoom: widget.markersScaleWithZoom,
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

        // Keep a zoomed globe inside its container when asked. Wrap before the
        // gesture detector so hit-testing still covers the full box; the Stack's
        // own clipBehavior stays Clip.none so markers can overflow as before.
        if (widget.clipBehavior != Clip.none) {
          body = ClipRect(clipBehavior: widget.clipBehavior, child: body);
        }

        if (widget.interactive) {
          // An eager scale recognizer claims gestures inside the globe before an
          // ancestor Scrollable can: a plain recognizer's slop is larger than
          // scroll's kTouchSlop (18px), so the scrollable would otherwise win
          // every vertical/horizontal drag. _EagerScaleGestureRecognizer
          // declares victory after 6px of focal movement OR as soon as a second
          // finger lands (a pinch), so drags and pinches on the globe stay with
          // the globe (like touch-action:none on web); a tap with no movement
          // never triggers the claim, so marker onTap is unaffected. The single
          // recognizer unifies one-finger rotation (focalPointDelta) and
          // two-finger pinch (details.scale).
          body = RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _EagerScaleGestureRecognizer>(
                () => _EagerScaleGestureRecognizer(),
                (recognizer) {
                  recognizer
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate
                    ..onEnd = _onScaleEnd;
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

/// Eager scale recognizer: unifies one-finger rotation and two-finger pinch in
/// a single recognizer, and claims the gesture arena early so drags/pinches
/// inside the globe aren't stolen by an ancestor scrollable or horizontal
/// gesture. It wins as soon as either (a) the focal point moves past
/// [_claimDistance] — far below scroll's kTouchSlop (18px) — or (b) a second
/// finger lands (an unmistakable pinch). The 6px threshold is larger than the
/// finger jitter of a tap (1–2px), so taps are unaffected (marker onTap still
/// works), but smaller than scroll's slop, so a drag always wins first.
class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
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
    }
    // Claim immediately on a second finger (pinch) or once the (single-finger)
    // focal movement passes the threshold. Calling resolve(accepted) repeatedly
    // is harmless; the arena acts once.
    if (pointerCount >= 2 || _moved.distance > _claimDistance) {
      resolve(GestureDisposition.accepted);
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
    required this.defaultScaleWithZoom,
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

  /// Widget-level default for whether markers grow with the globe's zoom;
  /// each marker's own [DotGlobeMarker.scaleWithZoom] overrides it.
  final bool defaultScaleWithZoom;

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

    // Zoom magnifies the projected radius, so positions move outward with the
    // dots even for fixed-size markers; size only grows when a marker scales.
    final scale = frame.scale;

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
      // Projected (zoomed) screen point the anchor must land on.
      final px = centerX + x1 * radius * scale;
      final py = centerY - y2 * radius * scale;
      // The anchor's offset inside the child box.
      final anchorX = childSize.width / 2 + anchor.x * childSize.width / 2;
      final anchorY = childSize.height / 2 + anchor.y * childSize.height / 2;

      final scaleWithZoom = markers[i].scaleWithZoom ?? defaultScaleWithZoom;
      final Matrix4 transform;
      if (scaleWithZoom) {
        // Magnify the child by the zoom factor about its anchor: scale, then
        // place so the (scaled) anchor sits exactly on (px, py). Composed as
        // T(px,py) · S(scale) · T(-anchorX,-anchorY).
        transform = Matrix4.identity()
          ..translateByDouble(px, py, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-anchorX, -anchorY, 0, 1);
      } else {
        // Fixed size: translate only, so the marker renders at natural size
        // (crisp) while still tracking the zoomed position.
        transform = Matrix4.translationValues(px - anchorX, py - anchorY, 0);
      }
      context.paintChild(i, transform: transform, opacity: opacity);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerFlowDelegate oldDelegate) {
    // Rotation/zoom repaints go through the repaint Listenable; only a changed
    // marker list, radius, or scaling default needs the projection rebuilt.
    return oldDelegate.markers != markers ||
        oldDelegate.radiusFactor != radiusFactor ||
        oldDelegate.defaultScaleWithZoom != defaultScaleWithZoom;
  }

  @override
  bool shouldRelayout(covariant _MarkerFlowDelegate oldDelegate) =>
      oldDelegate.markers != markers;
}
