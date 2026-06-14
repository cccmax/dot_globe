# Changelog

## 0.1.0 — initial release

- `DotGlobe` — a dotted (halftone) 3D globe rendered with a single batched
  `drawRawPoints` per depth band; ~6300 land dots from Natural Earth 110m.
- `DotGlobeMarker` — pin **any widget** at a latitude/longitude; projected onto
  the sphere, back-face culled, and faded near the silhouette.
- `DotGlobeArc` — great-circle connection arcs that bow off the sphere, solid on
  the near side and dashed around the back; configurable altitude, color, width,
  dash pattern, and back-side opacity.
- Gesture rotation with inertia, pitch spring-back, and idle auto-rotate; an
  eager pan recognizer keeps drags from being stolen by an ancestor scrollable.
- `DotGlobeStyle` with nine ready-made presets — `light`, `dark`, `polymarket`,
  `neon`, `sunset`, `mono`, `emerald`, `pastel`, `midnight` — plus `copyWith`
  and a `presets` map.
- `DotGlobeController` — `animateTo` / `jumpTo` a coordinate and observe the
  `facing` point (it is a `ChangeNotifier`).
- `paused` flag to stop the frame loop while off-screen within a route.
- Pure Dart, zero third-party dependencies, no texture assets. Runs on iOS,
  Android, Web, macOS, Windows, and Linux.
