/// A dotted (halftone) 3D globe for Flutter.
///
/// Spin it with a drag, let it auto-rotate, and drop any widget as a
/// latitude/longitude [DotGlobeMarker] that projects onto the sphere and fades
/// around the back. Pure Dart — no native code, no texture assets.
///
/// * [DotGlobe] — the widget.
/// * [DotGlobeMarker] — a widget pinned to a coordinate.
/// * [DotGlobeStyle] — colours / lighting, with ready-made presets.
/// * [DotGlobeController] / [DotGlobeFacing] — imperative spin + facing readout.
/// * [DotGlobeGeometry] — a custom dot cloud to render instead of Earth, with
///   optional per-dot colours (explicit, image/texture sampling, value→colormap
///   or callback).
/// * [DotGlobeColormap] — a colour ramp for mapping per-dot scalars to colours.
library;

export 'src/dot_globe.dart' show DotGlobe, DotGlobeMarker;
export 'src/dot_globe_arc.dart' show DotGlobeArc;
export 'src/dot_globe_colormap.dart' show DotGlobeColormap;
export 'src/dot_globe_controller.dart'
    show DotGlobeBinding, DotGlobeController, DotGlobeFacing;
export 'src/dot_globe_geometry.dart' show DotGlobeGeometry;
export 'src/dot_globe_style.dart' show DotGlobeStyle;
