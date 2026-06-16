# Changelog

## 0.2.0

- **Custom dot clouds** — new `DotGlobeGeometry` class with four constructors:
  - `fromLatLng` — build a cloud from a list of lat/lng degree pairs.
  - `fromPackedInt16` — decode the bundled `.bin` format (little-endian int16
    pairs) from any `ByteData` source.
  - `fromAsset` — async loader for a `.bin` asset; throws a descriptive
    `Exception` naming the asset key if missing or malformed.
  - `fromUnitVectors` — power-user path; accepts a flat `Float32List` of
    pre-computed unit vectors with caller-owned axis convention.
- **`DotGlobe(geometry:)`** — new optional parameter; pass a `DotGlobeGeometry`
  to replace the built-in Earth point cloud. `null` (default) loads the bundled
  data as before, so existing usage is unchanged.
- **Documented `.bin` binary format** — flat little-endian int16 pairs of
  `(round(lat × 100), round(lng × 100))`, 4 bytes per point, no header/footer,
  quantization 0.01° ≈ 1.1 km at the equator.
- **Added `tool/gen_land_dots.py`** — Python 3 generator (shapely required,
  numpy optional) to compile your own `.bin` from Natural Earth GeoJSON at
  110m / 50m / 10m resolution; flags: `--geojson`, `--resolution`, `--samples`,
  `--out`, `--quiet`.
- **Pinch-to-zoom** — two-finger pinch scales the globe in `[minScale,
  maxScale]`; one-finger drag rotates as before. While zoomed in, drag
  sensitivity scales down proportionally for finer control.
- **Programmatic zoom & fly-to** — `DotGlobeController` gains:
  - `animateTo({latitude?, longitude?, scale?, hold, duration, curve})` —
    compose a rotate + zoom into one eased move (scale is a new optional axis;
    existing callers are unaffected).
  - `zoomTo(scale, {hold, duration, curve})` — ease to a zoom level without
    changing the facing coordinate.
  - `resetView({duration, curve})` — ease back to `initialLatitude` /
    `initialLongitude` / `initialScale`.
  - `jumpTo({latitude?, longitude?, scale?, hold})` — instant snap; `scale` is a
    new optional parameter (existing callers are unaffected).
  - `scale` getter — read the current zoom factor (`null` when not attached).
  - `hold` (on `animateTo` / `zoomTo` / `jumpTo`, default `false`) — when
    `true`, the globe parks at the destination (no auto-rotation or pitch
    spring-back) until the next drag or move, instead of resuming idle spin.
- **New `DotGlobe` parameters** (all non-breaking, with defaults):
  - `initialScale` (`1.0`) — zoom at first build and `resetView` target.
  - `minScale` (`1.0`) — lower zoom bound for gesture and programmatic zoom.
  - `maxScale` (`6.0`) — upper zoom bound; set equal to `minScale` to disable.
  - `zoomGesture` (`true`) — whether pinch-to-zoom is active.
  - `clipBehavior` (`Clip.none`) — clip a zoomed globe to its container with
    `Clip.hardEdge`; default preserves previous behaviour.
  - `markersScaleWithZoom` (`true`) — global default for whether markers
    magnify with the globe's zoom.
- **`DotGlobeMarker.scaleWithZoom`** (`bool?`, default `null`) — per-marker
  override: `false` keeps the marker at a constant on-screen size (crisp pin)
  while still tracking the zoomed position; `true` magnifies it with the globe;
  `null` inherits `DotGlobe.markersScaleWithZoom`.
- **Per-dot colours** — `DotGlobeGeometry` now carries an optional
  `Int32List? colors` (one packed ARGB-8888 int per dot; `null` = every dot
  uses the style's single `dotColor`, pixel-identical to the previous
  behaviour). A dot whose alpha is `0` is hidden.
- **Immutable colour fillers** — each returns a new `DotGlobeGeometry` sharing
  the original `unitVectors`:
  - `withColors(Int32List colors)` — explicit per-dot ARGB list
    (`length == pointCount`).
  - `colorize(int Function(double latDeg, double lngDeg, int index) toArgb)`
    — colour by an arbitrary callback; return alpha `0` to hide a dot.
  - `colorizeByValues(List<double> values, {required DotGlobeColormap colormap,
    double? min, double? max, double? hideBelow})` — map a per-dot scalar
    through a colour ramp (`values.length == pointCount`; `min`/`max` default
    to the data extent; values below `hideBelow` are hidden).
  - `Future<DotGlobeGeometry> colorizeFromImage(ui.Image equirectangular,
    {double hideBelowAlpha = 0.0, bool wrapLongitude = true})` — sample an
    equirectangular (plate-carrée) image per dot
    (`u = lng/360 + 0.5`, `v = 0.5 - lat/180`); pixels below `hideBelowAlpha`
    are hidden.
  - `Future<DotGlobeGeometry> colorizedFromImageProvider(ImageProvider provider,
    {double hideBelowAlpha = 0.0, ImageConfiguration configuration =
    ImageConfiguration.empty})` — one-liner for `AssetImage` / `NetworkImage`;
    decodes then delegates to `colorizeFromImage`.
- **`DotGlobeColormap`** (new, exported) — immutable colour ramp over `[0, 1]`
  with linear interpolation between evenly-spaced stops.
  - `const DotGlobeColormap(List<Color> colors)` / `DotGlobeColormap.gradient([…])`
  - `Color at(double t)` / `int argbAt(double t)`
  - Built-in presets: `viridis` (perceptually-uniform blue→green→yellow),
    `turbo` (high-contrast rainbow), `heat` (black-body black→red→orange→yellow→white),
    `grayscale` (black→white), `cool` (blue→cyan→white).
- **Render path for coloured clouds**: `drawRawAtlas` (one batched call per
  depth band, zero per-frame allocation). The single-colour default retains
  the original `drawRawPoints` fast path.

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
