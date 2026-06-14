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
library;

export 'src/dot_globe.dart' show DotGlobe, DotGlobeMarker;
export 'src/dot_globe_arc.dart' show DotGlobeArc;
export 'src/dot_globe_controller.dart'
    show DotGlobeBinding, DotGlobeController, DotGlobeFacing;
export 'src/dot_globe_style.dart' show DotGlobeStyle;
