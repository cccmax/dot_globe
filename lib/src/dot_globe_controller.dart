import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// The geographic point currently facing the viewer at the centre of a
/// [DotGlobe].
@immutable
class DotGlobeFacing {
  /// Creates a facing record.
  const DotGlobeFacing(this.latitude, this.longitude);

  /// Latitude in degrees, north positive.
  final double latitude;

  /// Longitude in degrees, east positive, normalised to [-180, 180].
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is DotGlobeFacing &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'DotGlobeFacing(lat: ${latitude.toStringAsFixed(1)}, '
      'lng: ${longitude.toStringAsFixed(1)})';
}

/// The hooks a [DotGlobe] exposes to its controller. Implemented by the
/// widget's State; you never implement this yourself.
abstract class DotGlobeBinding {
  /// The coordinate facing the viewer right now.
  DotGlobeFacing currentFacing();

  /// The zoom factor applied right now (`1.0` is the natural size).
  double currentScale();

  /// Eases the globe so the given coordinate faces the viewer, optionally
  /// zooming to [scale] over the same animation. The scale is clamped to the
  /// globe's `[minScale, maxScale]`. When [hold] is true the globe parks at the
  /// destination on arrival; otherwise it resumes idle auto-rotation.
  Future<void> animateFacingTo({
    double? latitude,
    double? longitude,
    double? scale,
    bool hold = false,
    required Duration duration,
    required Curve curve,
  });

  /// Snaps the globe so the given coordinate faces the viewer, optionally
  /// jumping the zoom to [scale] (clamped to `[minScale, maxScale]`). When
  /// [hold] is true the globe parks there; otherwise it resumes idle
  /// auto-rotation.
  void jumpFacingTo({
    double? latitude,
    double? longitude,
    double? scale,
    bool hold = false,
  });

  /// Eases the globe back to its initial facing and zoom
  /// (`initialLatitude`/`initialLongitude`/`initialScale`).
  Future<void> resetView({required Duration duration, required Curve curve});
}

/// Imperative handle for a [DotGlobe]: spin it to a coordinate from outside the
/// widget tree, and observe which coordinate currently faces the viewer.
///
/// Attach it like any Flutter controller and dispose it when done:
///
/// ```dart
/// final controller = DotGlobeController();
///
/// DotGlobe(controller: controller);
///
/// // Later, e.g. from a button:
/// controller.animateTo(latitude: 46, longitude: 2); // France faces front
///
/// // React to rotation (it is a [Listenable]):
/// controller.addListener(() => print(controller.facing));
///
/// @override
/// void dispose() {
///   controller.dispose();
///   super.dispose();
/// }
/// ```
///
/// A controller drives at most one [DotGlobe] at a time. Notifications fire on
/// every frame the globe rotates, so read [facing] inside the listener.
class DotGlobeController extends ChangeNotifier {
  DotGlobeBinding? _binding;

  /// Whether this controller is currently attached to a mounted [DotGlobe].
  bool get isAttached => _binding != null;

  /// The coordinate facing the viewer right now, or `null` if not attached.
  DotGlobeFacing? get facing => _binding?.currentFacing();

  /// The zoom factor applied right now (`1.0` is the natural size), or `null`
  /// if not attached.
  double? get scale => _binding?.currentScale();

  /// Spins the globe so [latitude]/[longitude] ends up facing the viewer and,
  /// when [scale] is given, zooms to it — both eased over [duration] in one
  /// composable move. Omitted axes/zoom keep their current value. The pitch
  /// (latitude) is clamped to the globe's tilt limits and the zoom to its
  /// `[minScale, maxScale]`. Auto-rotation and inertia pause for the duration
  /// and resume afterwards.
  ///
  /// ```dart
  /// // France faces front, zoomed in 2×.
  /// controller.animateTo(latitude: 46, longitude: 2, scale: 2);
  /// ```
  ///
  /// When [hold] is `true`, the globe parks at the destination on arrival —
  /// auto-rotation and pitch spring-back stay off, so the target stays centred
  /// until the next drag or programmatic move. When `false` (default), idle
  /// auto-rotation resumes and the pitch eases back to `initialLatitude`.
  ///
  /// Returns when the animation completes (or is superseded / detached).
  Future<void> animateTo({
    double? latitude,
    double? longitude,
    double? scale,
    bool hold = false,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    await _binding?.animateFacingTo(
      latitude: latitude,
      longitude: longitude,
      scale: scale,
      hold: hold,
      duration: duration,
      curve: curve,
    );
  }

  /// Eases the zoom to [scale] (clamped to `[minScale, maxScale]`) without
  /// changing the facing coordinate.
  ///
  /// ```dart
  /// controller.zoomTo(3); // zoom in 3×
  /// controller.zoomTo(1); // back to natural size
  /// ```
  ///
  /// When [hold] is `true` the globe parks at the current facing once the zoom
  /// settles; otherwise idle auto-rotation resumes.
  Future<void> zoomTo(
    double scale, {
    bool hold = false,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    await _binding?.animateFacingTo(
      scale: scale,
      hold: hold,
      duration: duration,
      curve: curve,
    );
  }

  /// Eases the globe back to its initial facing and zoom
  /// (`initialLatitude`/`initialLongitude`/`initialScale`).
  ///
  /// ```dart
  /// controller.resetView(); // undo any spin + zoom
  /// ```
  Future<void> resetView({
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    await _binding?.resetView(duration: duration, curve: curve);
  }

  /// Snaps the globe so [latitude]/[longitude] faces the viewer immediately and,
  /// when [scale] is given, jumps the zoom to it (clamped to
  /// `[minScale, maxScale]`). Omitted axes/zoom keep their current value. When
  /// [hold] is `true` the globe parks there; otherwise idle auto-rotation
  /// resumes.
  void jumpTo({
    double? latitude,
    double? longitude,
    double? scale,
    bool hold = false,
  }) {
    _binding?.jumpFacingTo(
      latitude: latitude,
      longitude: longitude,
      scale: scale,
      hold: hold,
    );
  }

  // ---- internal wiring (called by DotGlobe's State) ----

  /// Binds this controller to a globe. Called by `DotGlobe`'s State; not part
  /// of the day-to-day API.
  void attach(DotGlobeBinding binding) => _binding = binding;

  /// Unbinds [binding] if it is the current one. Called by `DotGlobe`'s State.
  void detach(DotGlobeBinding binding) {
    if (identical(_binding, binding)) _binding = null;
  }

  /// Notifies external listeners that the facing coordinate changed. Called by
  /// `DotGlobe`'s State on each rotated frame.
  void notifyFacingChanged() => notifyListeners();
}
