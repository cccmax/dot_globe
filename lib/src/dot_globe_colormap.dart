import 'dart:ui' show Color;

/// An immutable colour ramp over the normalised range `[0, 1]`.
///
/// A colormap wraps a list of evenly-spaced stop colours and interpolates
/// linearly between adjacent stops, so [at] / [argbAt] turn a value `t` into a
/// colour. It is the bridge between a per-dot scalar (heat, density, elevation)
/// and the per-dot colour primitive consumed by
/// [DotGlobeGeometry.colorizeByValues].
///
/// ```dart
/// final ramp = DotGlobeColormap.turbo;
/// final color = ramp.at(0.5); // mid-ramp colour
/// ```
///
/// Built-in presets: [viridis], [turbo], [heat], [grayscale], [cool]. They are
/// pure Dart and allocate nothing per lookup.
class DotGlobeColormap {
  /// Creates a colormap from [colors], treated as evenly spaced over `[0, 1]`
  /// (the first stop sits at `t == 0`, the last at `t == 1`).
  ///
  /// Asserts [colors] is non-empty.
  const DotGlobeColormap(this.colors)
      : assert(colors.length > 0, 'colors must be non-empty');

  /// Builds a colormap from a gradient described by its stop [colors]. Identical
  /// to the default constructor; provided for a readable, intent-revealing call
  /// site.
  factory DotGlobeColormap.gradient(List<Color> colors) =>
      DotGlobeColormap(colors);

  /// Evenly-spaced stop colours spanning `[0, 1]`.
  final List<Color> colors;

  /// Interpolated colour at [t], clamped to `[0, 1]`. Linearly blends the two
  /// adjacent stops.
  Color at(double t) {
    final clamped = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    final last = colors.length - 1;
    if (last == 0) return colors[0];
    final scaled = clamped * last;
    final lo = scaled.floor();
    if (lo >= last) return colors[last];
    final hi = lo + 1;
    final f = scaled - lo;
    return Color.lerp(colors[lo], colors[hi], f) ?? colors[lo];
  }

  /// Interpolated colour at [t] as a packed ARGB-8888 int (the per-dot colour
  /// format consumed by [DotGlobeGeometry]). See [at].
  int argbAt(double t) => at(t).toARGB32();

  /// Perceptually-uniform blue→green→yellow ramp (Matplotlib viridis stops).
  static DotGlobeColormap get viridis => DotGlobeColormap(const [
    Color(0xFF440154),
    Color(0xFF482878),
    Color(0xFF3E4A89),
    Color(0xFF31688E),
    Color(0xFF26828E),
    Color(0xFF1F9E89),
    Color(0xFF35B779),
    Color(0xFF6DCD59),
    Color(0xFFB4DE2C),
    Color(0xFFFDE725),
  ]);

  /// High-contrast rainbow ramp (Google turbo stops), good for wide dynamic
  /// range.
  static DotGlobeColormap get turbo => DotGlobeColormap(const [
    Color(0xFF30123B),
    Color(0xFF4145AB),
    Color(0xFF4675ED),
    Color(0xFF39A2FC),
    Color(0xFF1BCFD4),
    Color(0xFF24ECA0),
    Color(0xFF61FC6C),
    Color(0xFFA4FC3B),
    Color(0xFFD1E834),
    Color(0xFFF3C63A),
    Color(0xFFFE992C),
    Color(0xFFEA5A0F),
    Color(0xFFC42503),
    Color(0xFF7A0403),
  ]);

  /// Black-body heat ramp: black → red → orange → yellow → white.
  static DotGlobeColormap get heat => DotGlobeColormap(const [
    Color(0xFF000000),
    Color(0xFFFF0000),
    Color(0xFFFF8C00),
    Color(0xFFFFFF00),
    Color(0xFFFFFFFF),
  ]);

  /// Linear black → white ramp.
  static DotGlobeColormap get grayscale => DotGlobeColormap(const [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ]);

  /// Cool ramp: blue → cyan → white.
  static DotGlobeColormap get cool => DotGlobeColormap(const [
    Color(0xFF0000FF),
    Color(0xFF00FFFF),
    Color(0xFFFFFFFF),
  ]);
}
