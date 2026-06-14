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

  /// Eases the globe so the given coordinate faces the viewer.
  Future<void> animateFacingTo({
    double? latitude,
    double? longitude,
    required Duration duration,
    required Curve curve,
  });

  /// Snaps the globe so the given coordinate faces the viewer.
  void jumpFacingTo({double? latitude, double? longitude});
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

  /// Spins the globe so [latitude]/[longitude] ends up facing the viewer,
  /// easing over [duration]. Omitted axes keep their current value. The pitch
  /// (latitude) is clamped to the globe's tilt limits. Auto-rotation and
  /// inertia pause for the duration and resume afterwards.
  ///
  /// Returns when the animation completes (or is superseded / detached).
  Future<void> animateTo({
    double? latitude,
    double? longitude,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    await _binding?.animateFacingTo(
      latitude: latitude,
      longitude: longitude,
      duration: duration,
      curve: curve,
    );
  }

  /// Snaps the globe so [latitude]/[longitude] faces the viewer immediately.
  /// Omitted axes keep their current value.
  void jumpTo({double? latitude, double? longitude}) {
    _binding?.jumpFacingTo(latitude: latitude, longitude: longitude);
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
