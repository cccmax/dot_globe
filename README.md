<!-- This README is rendered on pub.dev. All image links must be absolute -->
<!-- (pub.dev rewrites relative paths and breaks them), so raw.githubusercontent -->
<!-- URLs are used throughout. -->

# dot_globe

> Spin a dotted 3D globe, pin any widget to a latitude/longitude, and connect
> the dots with great-circle arcs. Pure Dart, zero dependencies, nine presets.

[![pub package](https://img.shields.io/pub/v/dot_globe.svg)](https://pub.dev/packages/dot_globe)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.10-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20Web%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-blue)](#platform-support)

<p align="center">
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/showcase.webp" width="220" alt="Globe with markers and arcs"/>
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/natural.webp" width="150" alt="Natural-colour satellite Earth"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/fantasy.webp" width="150" alt="Procedural fantasy planet"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/heatmap_turbo.webp" width="150" alt="Per-dot data heatmap"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/neon.webp" width="150" alt="Neon halftone globe"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/world_cup.webp" width="150" alt="World Cup odds bubbles"/>
</p>

`dot_globe` renders ~6,300 halftone land dots and lets you pin any Flutter
widget (flags, labels, price bubbles) to geographic coordinates — with automatic
depth sorting, back-face culling, and edge fade. **Visually inspired by
[Polymarket](https://polymarket.com)'s world-cup map and
[cobe.js](https://github.com/shuding/cobe).**

🌐 **[Live demo →](https://cccmax.github.io/dot_globe/)** &nbsp;·&nbsp;
[中文文档 →](https://github.com/cccmax/dot_globe/blob/main/README_zh.md)

---

## Features

- **Any widget as a marker** — not just dots. Pin images, flags, bubbles, price
  charts, or custom widgets to lat/lng coordinates. Markers fade and hide
  automatically when they rotate to the back.
- **Great-circle arcs** — connect coordinates with flight-path lines that bow
  off the sphere. Per-arc altitude, color, width, dash, and back-side opacity;
  solid on the near side, dashed as they curve around the back.
- **Halftone (dotted) rendering** — ~6,300 land dots sampled from Natural Earth
  110m data. Cobe-style aesthetics with strong visual depth.
- **Pure Dart, zero dependencies** — no plugins, no shader code, no texture
  assets. Import and go on iOS, Android, Web, macOS, Windows, Linux.
- **High performance** — rotation never rebuilds widgets; markers re-position via
  `Flow` (transform-only, no relayout). Consistent 60 fps on Impeller.
- **Full gesture control** — drag to rotate with inertia decay, pinch to zoom,
  auto-spin when idle, configurable tilt limits, elastic spring-back to rest
  pitch.
- **Nine color presets** — `light`, `dark`, `polymarket`, `neon`, `sunset`,
  `mono`, `emerald`, `pastel`, `midnight`. One-line styling or customize with
  `copyWith`.
- **Imperative controller** — fly to a coordinate (with optional zoom) in one
  eased move, zoom in/out programmatically, or reset the view — all from outside
  the widget tree.

## Install

```yaml
dependencies:
  dot_globe: ^0.1.0
```

```bash
flutter pub add dot_globe
```

## Quick start

### Minimal: one-line globe

```dart
import 'package:dot_globe/dot_globe.dart';

DotGlobe(style: DotGlobeStyle.dark)
```

Tap and drag to rotate, swipe for momentum.

### With markers

```dart
DotGlobe(
  style: DotGlobeStyle.polymarket,
  markers: [
    DotGlobeMarker(
      latitude: 46, longitude: 2,
      anchor: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇫🇷', style: TextStyle(fontSize: 28)),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Text('16%', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
    DotGlobeMarker(
      latitude: -23, longitude: -47,
      anchor: Alignment.bottomCenter,
      child: const Icon(Icons.location_on, color: Colors.red),
    ),
  ],
)
```

Each marker auto-projects to its lat/lng, fades near the edge, and vanishes when
it rotates behind the sphere.

### Connection arcs

```dart
DotGlobe(
  style: DotGlobeStyle.midnight,
  // Shrink the globe so tall arcs stay in bounds: radiusFactor <= 1/(1+altitude)
  radiusFactor: 0.55,
  arcs: const [
    DotGlobeArc(
      startLatitude: 35.7, startLongitude: 139.7, // Tokyo
      endLatitude: 51.5, endLongitude: -0.1,       // London
      color: Color(0xFF4ED7F2),
      altitude: 0.45,   // how high it bows off the sphere (0 = hugs it)
    ),
    DotGlobeArc(
      startLatitude: 40.7, startLongitude: -74.0,  // New York
      endLatitude: -23.5, endLongitude: -46.6,     // São Paulo
      color: Color(0xFFFF5A5A),
      altitude: 0.3,
      dashed: true,       // dash the near side too (back is dashed by default)
      backOpacity: 0.4,   // fade of the half curving behind the globe
    ),
  ],
)
```

### Programmatic control

```dart
final controller = DotGlobeController();

DotGlobe(
  style: DotGlobeStyle.neon,
  controller: controller,
);

// Spin to a coordinate over 600ms
controller.animateTo(latitude: 46, longitude: 2);

// Or snap instantly
controller.jumpTo(latitude: -23, longitude: -47);

// Listen to rotations (fires every frame while spinning)
controller.addListener(() {
  final facing = controller.facing;
  print('Facing: ${facing?.latitude}, ${facing?.longitude}');
});

// Dispose when done
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### Zoom & fly-to

Two-finger pinch zooms the globe (one-finger drag always rotates). The scale
range is `[minScale, maxScale]`; the default is 1×–6×. While zoomed in, the
drag rotates proportionally finer so the motion stays natural.

```dart
DotGlobe(
  controller: controller,
  minScale: 1.0,   // cannot zoom out below natural size (default)
  maxScale: 4.0,   // allow up to 4× zoom
  zoomGesture: true,             // pinch-to-zoom (default)
  clipBehavior: Clip.hardEdge,   // keep a zoomed globe inside its box
  markersScaleWithZoom: true,    // markers magnify with the globe (default)
)
```

**Programmatic zoom & fly-to:**

```dart
// Spin to Tokyo and zoom in 2.4×, in one composed move, and STAY there:
controller.animateTo(latitude: 35.7, longitude: 139.7, scale: 2.4, hold: true);

controller.zoomTo(1);     // ease back to natural size, keep current facing
controller.resetView();   // undo spin + zoom (back to initialLatitude/Longitude/Scale)
```

By default a move resumes idle auto-rotation (and the pitch eases back to
`initialLatitude`) once it arrives. Pass `hold: true` to **park** at the
destination instead — auto-rotation and pitch spring-back stay off until the
next drag or programmatic move, so the target stays centred. `hold` is
available on `animateTo`, `zoomTo`, and `jumpTo`.

`animateTo` and `zoomTo` each take optional `duration` and `curve` parameters
(defaults: 600 ms, `Curves.easeInOutCubic`). Both return `Future<void>` that
completes when the animation finishes.

`controller.jumpTo(latitude: 35.7, longitude: 139.7, scale: 2.4)` does the
same instantly with no animation.

Read the live zoom factor with `controller.scale` (returns `null` when not
attached).

**Per-marker zoom behaviour:**

By default (`markersScaleWithZoom: true`) all markers magnify together with the
globe. Override per-marker:

```dart
DotGlobeMarker(
  latitude: 35.7, longitude: 139.7,
  scaleWithZoom: false,   // stays its natural on-screen size even when zoomed
  child: const Icon(Icons.location_pin, color: Colors.red),
)
```

`scaleWithZoom: null` (the default) inherits the widget's `markersScaleWithZoom`
setting. Either way the marker tracks the correct zoomed screen position.

### Custom styling

```dart
DotGlobe(
  style: DotGlobeStyle.dark.copyWith(
    dotRadius: 1.8,
    depthFade: 0.8,
  ),
)
```

Or build your own palette:

```dart
DotGlobe(
  style: DotGlobeStyle(
    dotColor: const Color(0xFF00FF88),
    sphereColor: const Color(0xFF0A0A20),
    glowColor: const Color(0xFF00FF44),
    sphereLight: true,
    depthFade: 0.7,
    backgroundColor: const Color(0xFF000000),
  ),
)
```

## API at a glance

| Widget / Class | Purpose |
| --- | --- |
| `DotGlobe` | Root globe widget; holds markers, gestures, and animation state. |
| `DotGlobeMarker` | A widget pinned to a lat/lng coordinate on the sphere. |
| `DotGlobeArc` | A great-circle arc (flight path) between two coordinates. |
| `DotGlobeStyle` | Color, lighting, and dot-size config; 9 presets included. |
| `DotGlobeController` | Spin the globe and read the facing coordinate. |
| `DotGlobeFacing` | The lat/lng currently facing the viewer. |
| `DotGlobeGeometry` | Point-cloud data (unit vectors + optional per-dot colours). Build with `fromLatLng` / `fromAsset` / `fromPackedInt16` / `fromUnitVectors`; add colour with `withColors` / `colorize` / `colorizeByValues` / `colorizeFromImage` / `colorizedFromImageProvider`. |
| `DotGlobeColormap` | Immutable colour ramp over `[0, 1]`; five built-in presets (`viridis`, `turbo`, `heat`, `grayscale`, `cool`) plus `gradient` factory. Used by `colorizeByValues`. |

### DotGlobe parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `style` | `DotGlobeStyle.light` | Visual config: colors, lighting, dot size. Pick a preset or customize. |
| `markers` | `[]` | Widgets pinned to the globe. |
| `arcs` | `[]` | Great-circle arcs drawn over the globe, beneath the markers. |
| `controller` | `null` | Optional handle to drive rotation/zoom and read facing point. |
| `radiusFactor` | `0.92` | Sphere radius as a fraction of half the widget's shortest side. |
| `autoRotateSpeed` | `0.12` | Idle rotation speed in radians per second; `0` = static. |
| `initialLatitude` | `18` | Pitch (latitude in degrees) at rest; also the spring-back target after a vertical drag. |
| `initialLongitude` | `10` | Yaw (longitude in degrees) facing the viewer at first build. |
| `maxTilt` | `0.6` | Maximum pitch deviation from rest, in radians (~34°). |
| `dragSensitivity` | `1.0` | Drag-to-rotation multiplier; higher = faster spin. |
| `inertiaDecay` | `0.94` | Per-frame (60 fps) momentum retention [0, 1); higher = longer spin after release. |
| `tiltReturn` | `0.92` | Per-frame pitch spring-back retention [0, 1); higher = slower return to rest. |
| `interactive` | `true` | Whether drags rotate the globe. |
| `paused` | `false` | Pause the frame loop (auto-rotation, inertia) for off-screen globes to save power. Pair with `VisibilityDetector`. |
| `initialScale` | `1.0` | Zoom factor at first build; also the target of `resetView`. Must be within `[minScale, maxScale]`. |
| `minScale` | `1.0` | Lower zoom bound for gesture and programmatic zoom. Must be `> 0`. |
| `maxScale` | `6.0` | Upper zoom bound. Set equal to `minScale` to disable zooming entirely. |
| `zoomGesture` | `true` | Whether a two-finger pinch zooms the globe. One-finger rotation always works. |
| `clipBehavior` | `Clip.none` | How a zoomed globe is clipped. `Clip.hardEdge` keeps it inside its container; `Clip.none` (default) lets it spill out. |
| `markersScaleWithZoom` | `true` | Default zoom-scaling for all markers. Each `DotGlobeMarker` can override via `scaleWithZoom`. |

### DotGlobeStyle fields & presets

| Field | Type | Notes |
| --- | --- | --- |
| `dotColor` | `Color` | **Required.** Land dot color; far dots dim when `depthFade > 0`. |
| `sphereColor` | `Color` | **Required.** Sphere base; flat or radial gradient if `sphereLight = true`. |
| `glowColor` | `Color?` | Rim glow at the silhouette; `null` disables. Best on dark backgrounds. |
| `sphereLight` | `bool` | `false` = flat fill; `true` = faked 3D radial gradient from upper-left. |
| `depthFade` | `double` | Depth intensity 0–1; `1` = strong (Polymarket look), `0` = flat dots. |
| `dotRadius` | `double` | Land dot size in logical pixels (at the sphere front). |
| `backgroundColor` | `Color?` | Optional fill behind the globe; `null` = transparent. |

**Built-in presets:**

- **`light`** — Pale blue dots on faint blue, flat. Light-themed apps.
- **`dark`** — Deep blue luminous dots on navy, flat. Dark-themed apps.
- **`polymarket`** — 3D-lit blue globe with strong depth. Homage to the
  Polymarket world-cup map.
- **`neon`** — Cyan dots with magenta rim glow. Cyber / Web3 energy.
- **`sunset`** — Amber dots on a lit ember sphere. Warm, brand-forward.
- **`mono`** — White dots on near-black, flat, no glow. Premium, editorial.
- **`emerald`** — Turquoise dots on a lit forest-green sphere. Organic.
- **`pastel`** — Mauve dots on cream lavender, flat, on light background. Cute.
- **`midnight`** — Cool off-white dots with faint blue glow. Quieter dark default.

Iterate all presets programmatically:

```dart
for (final name in DotGlobeStyle.presets.entries) {
  print('${name.key}: ${name.value}');
}
```

### DotGlobeController methods

| Method / getter | Returns | Notes |
| --- | --- | --- |
| `animateTo({latitude?, longitude?, scale?, hold, duration, curve})` | `Future<void>` | Spin to a coordinate and/or zoom to `scale` in one eased move; omitted axes keep their current value. `hold: true` parks at the destination (no auto-rotate / spring-back); `false` (default) resumes idle spin. Pitch clamped to `maxTilt`; scale clamped to `[minScale, maxScale]`. Defaults: 600 ms, `easeInOutCubic`. |
| `zoomTo(scale, {hold, duration, curve})` | `Future<void>` | Ease the zoom to `scale` without changing the facing coordinate. `hold` parks on arrival. Same defaults as `animateTo`. |
| `resetView({duration, curve})` | `Future<void>` | Ease back to `initialLatitude` / `initialLongitude` / `initialScale` and resume idle spin. |
| `jumpTo({latitude?, longitude?, scale?, hold})` | `void` | Snap instantly to a coordinate and/or zoom; omitted values unchanged. `hold: true` parks there. |
| `facing` | `DotGlobeFacing?` | Current facing coordinate; `null` if not attached. |
| `scale` | `double?` | Current zoom factor (`1.0` = natural size); `null` if not attached. |
| `isAttached` | `bool` | Whether the controller is bound to a mounted globe. |
| `addListener`, `removeListener`, `dispose` | | Standard `ChangeNotifier` API; `facing` and `scale` update on every rotation/zoom frame. |

### DotGlobeMarker parameters

| Parameter | Type | Notes |
| --- | --- | --- |
| `latitude` | `double` | Degrees north; south is negative. |
| `longitude` | `double` | Degrees east; west is negative. |
| `child` | `Widget` | The widget rendered at this coordinate. Can be anything: `Text`, `Image`, `Icon`, custom widgets. |
| `anchor` | `Alignment` | Which point of `child` pins to the projected coordinate. Default `center`; use `bottomCenter` for bubbles with a tail. |
| `scaleWithZoom` | `bool?` | Whether this marker grows with the globe's zoom. `null` (default) inherits `DotGlobe.markersScaleWithZoom`. `false` = constant on-screen size (crisp pin) while still tracking the zoomed position; `true` = magnifies with the globe. |

### DotGlobeArc parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `startLatitude`, `startLongitude` | — | **Required.** Start coordinate (degrees). |
| `endLatitude`, `endLongitude` | — | **Required.** End coordinate (degrees). |
| `color` | `0xFF6B8AE8` | Stroke color. |
| `width` | `2.0` | Stroke width in logical pixels. |
| `altitude` | `0.35` | Peak height above the sphere as a fraction of radius; `0` hugs the surface. |
| `dashed` | `false` | Dash the near (front) side. |
| `backDashed` | `true` | Dash the half curving around the back. |
| `backOpacity` | `0.38` | Opacity of the back half, 0–1; `0` hides it, `1` matches the front. |
| `dashLength`, `dashGap` | `6`, `5` | Dash pattern in logical pixels. |
| `glow` | `true` | Soft glow underlay on the front half. |

> Tall arcs bow outside the globe's circle, so shrink the sphere to keep them in
> frame: `radiusFactor <= 1 / (1 + maxAltitude)`.

## Per-dot colours & textures

Every dot can carry its own colour, fed from any source — an equirectangular
satellite image, a data heatmap, a weather/cloud overlay, or a hand-crafted
rule. Colour is added through **immutable fillers**: each returns a new
`DotGlobeGeometry` that shares the original point cloud and adds an
`Int32List colors` (one ARGB-8888 int per dot). The default (no filler called)
is pixel-identical to the existing single-colour fast path.

### Heatmap / data scalar

Map a per-dot `List<double>` through a colour ramp:

```dart
final g = base.colorizeByValues(
  values,                       // one double per dot; length == pointCount
  colormap: DotGlobeColormap.turbo,
  // min / max default to the data extent; hideBelow hides dots below a threshold
  hideBelow: 0.1,
);
DotGlobe(geometry: g, style: DotGlobeStyle.dark)
```

### Satellite / equirectangular image (one-liner)

Any plate-carrée (equirectangular) image — longitude −180…180 across the width,
latitude 90…−90 down the height — can be draped over the globe:

```dart
// AssetImage, NetworkImage, or any ImageProvider
final g = await base.colorizedFromImageProvider(
  const AssetImage('assets/earth.jpg'),
);
DotGlobe(geometry: g, style: DotGlobeStyle.dark)
```

Pixels whose alpha is below `hideBelowAlpha` (default `0.0`) are hidden,
so an image's transparent regions automatically "shape" the dot cloud. This
works for satellite imagery, cloud-cover maps, or any masked texture.

### Weather / cloud frames or a `ui.Image`

When you already have a decoded `ui.Image` (e.g. a video frame or a
procedurally generated texture), pass it directly:

```dart
import 'dart:ui' as ui;

final ui.Image uiImage = /* decode or capture your image */;
final g = await base.colorizeFromImage(
  uiImage,
  hideBelowAlpha: 0.1,  // hide near-transparent pixels
  wrapLongitude: true,  // seamless east/west wrap (default)
);
```

`u = lng / 360 + 0.5`, `v = 0.5 - lat / 180` — the standard plate-carrée
mapping. Vertical coordinates are always clamped; horizontal wraps when
`wrapLongitude` is true.

### Colour by rule

Apply an arbitrary function over each dot's latitude, longitude, and index:

```dart
final g = base.colorize((lat, lng, i) {
  // return any packed ARGB-8888 int; alpha 0 hides the dot
  final t = (lat + 90) / 180; // north = 1, south = 0
  return Color.lerp(Colors.blue, Colors.orange, t)!.toARGB32();
});
```

### Explicit per-dot ARGB list

Pass a pre-built `Int32List` directly (one packed ARGB-8888 int per dot,
`length == pointCount`):

```dart
final g = base.withColors(int32ArgbList);
```

### `DotGlobeColormap`

A lightweight immutable colour ramp over `[0, 1]`. Interpolates linearly
between evenly-spaced stop colours.

```dart
// Built-in presets
DotGlobeColormap.viridis   // perceptually-uniform blue→green→yellow
DotGlobeColormap.turbo     // high-contrast rainbow (Google turbo)
DotGlobeColormap.heat      // black → red → orange → yellow → white
DotGlobeColormap.grayscale // black → white
DotGlobeColormap.cool      // blue → cyan → white

// Custom gradient (any number of stops)
final ramp = DotGlobeColormap.gradient([Colors.navy, Colors.cyan, Colors.white]);
// or equivalently:
final ramp = DotGlobeColormap([Colors.navy, Colors.cyan, Colors.white]);

// Lookup
final color = ramp.at(0.5);        // returns Color
final argb  = ramp.argbAt(0.5);    // returns packed ARGB-8888 int
```

### Notes

- A dot whose ARGB alpha is `0` is **hidden** — no pixel is drawn. This lets
  an image's transparent area or a data threshold "shape" the cloud without
  removing any geometry.
- The image **must be equirectangular** (plate-carrée). Standard satellite
  imagery (e.g. Blue Marble, Natural Earth raster) is already in this
  projection.
- Typical use cases: satellite imagery draped over the land-dot cloud,
  country- or region-level data heatmaps, animated weather / cloud overlays
  updated frame by frame.
- **Render path**: a geometry with per-dot colours renders via `drawRawAtlas`
  (one batched call per depth band, zero per-frame allocation). The
  single-colour default keeps the original `drawRawPoints` fast path.

---

## Custom dot data

### Built-in data source

The bundled `assets/land_dots.bin` contains **6,363 points** (~25 KB) generated
offline from [Natural Earth](https://www.naturalearthdata.com/) 110m land
polygons (public domain). Candidate points are placed on a **Fibonacci sphere**
(golden-angle, uniform area distribution, no polar clustering), then each
candidate is tested for containment inside the land polygons — only those that
fall on land are kept. All Flutter target platforms are little-endian, so the
file is read directly with no byte-swap.

### Binary format (`assets/land_dots.bin`)

| Field | Type | Bytes | Notes |
|---|---|---|---|
| latitude | `int16` LE | 2 | `round(lat × 100)`, north-positive, range −9000…9000 |
| longitude | `int16` LE | 2 | `round(lng × 100)`, east-positive, range −18000…18000 |

- **4 bytes per point**, no header, no footer.
- Quantization: 0.01° ≈ 1.1 km at the equator.
- Decoder: `lib/src/dot_globe_geometry.dart` (`fromPackedInt16`).

### Using a custom point cloud

Pass a `DotGlobeGeometry` to the `geometry:` parameter. `null` (the default)
uses the built-in Earth data.

> Markers and arcs are positioned by lat/lng, so they align correctly with any
> cloud built via `fromLatLng` or `fromPackedInt16` / `fromAsset` (all three
> apply the standard axis convention automatically). If you use `fromUnitVectors`
> directly, the caller owns the axis convention.

**From lat/lng pairs (in-memory):**

```dart
final geometry = DotGlobeGeometry.fromLatLng([
  (latitude: 48.85, longitude: 2.35),   // Paris
  (latitude: 35.68, longitude: 139.69), // Tokyo
  (latitude: 40.71, longitude: -74.01), // New York
]);

DotGlobe(geometry: geometry, style: DotGlobeStyle.dark)
```

**From your own `.bin` asset (same packed int16 format):**

```dart
// In pubspec.yaml: assets: [assets/my_dots.bin]
final geometry = await DotGlobeGeometry.fromAsset('assets/my_dots.bin');

DotGlobe(geometry: geometry, style: DotGlobeStyle.neon)
```

#### All `DotGlobeGeometry` constructors

| Constructor | Input | Notes |
|---|---|---|
| `fromLatLng(List<({double latitude, double longitude})>)` | Lat/lng degrees | Standard axis convention applied; throws `ArgumentError` if empty. |
| `fromPackedInt16(ByteData)` | Raw `.bin` bytes | Throws `FormatException` if bytes aren't a multiple of 4 or are empty. |
| `static Future fromAsset(String assetKey, {AssetBundle?})` | Asset path | Throws `Exception` naming the key if missing or malformed. |
| `fromUnitVectors(Float32List)` | Flat `[x,y,z,…]` buffer | Power-user path; caller owns axis convention (`x = -cosLat·cosLng`, `y = sinLat`, `z = cosLat·sinLng`); throws `ArgumentError` if empty or not a multiple of 3. |

### Regenerating the bundled `.bin` with your own data

The repo ships a Python generator at **`tool/gen_land_dots.py`** (Python 3 +
shapely required; numpy optional, speeds up the Fibonacci math).

**Step 1 — install dependencies and download the GeoJSON:**

```bash
pip install shapely
curl -L -o ne_110m_land.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
```

**Step 2 — generate:**

```bash
python3 tool/gen_land_dots.py --geojson ne_110m_land.geojson --samples 60000
```

Output is written to `assets/land_dots.bin` by default.

**CLI flags:**

| Flag | Default | Description |
|---|---|---|
| `--geojson PATH` | auto-detect | Path to a Natural Earth land GeoJSON file. If omitted, the script looks for `ne_<resolution>_land.geojson` next to the script or in the current directory. |
| `--resolution {110m,50m,10m}` | `110m` | Resolution to auto-detect when `--geojson` is not given. |
| `--samples N` | `60000` | Number of Fibonacci sphere candidates to test; more → denser coastlines. |
| `--out PATH` | `assets/land_dots.bin` | Output path for the binary asset. |
| `--quiet` | off | Suppress progress output; only errors are printed. |

**Higher-resolution variants** (sharper coastlines, larger file, slower generation):

```bash
# 50m — finer detail
curl -L -o ne_50m_land.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson
python3 tool/gen_land_dots.py --geojson ne_50m_land.geojson --resolution 50m --samples 120000

# 10m — highest detail
curl -L -o ne_10m_land.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
python3 tool/gen_land_dots.py --geojson ne_10m_land.geojson --resolution 10m --samples 200000
```

Natural Earth GeoJSON mirrors (public domain, no attribution required):

- 110m (~200 KB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
- 50m (~600 KB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson
- 10m (~3.5 MB): https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson

---

## How it works

**Geometry:**
- ~6,300 land dots are sampled from Natural Earth's 110m coastline data using a
  Fibonacci-sphere distribution.
- The globe is a unit sphere in the `[-1, 1]^3` coordinate space.
- Each frame, the sphere rotates by two angles (yaw / longitude, pitch /
  latitude).

**Rendering:**
- The **canvas layer** (`CustomPaint` with `DotGlobePainter`) draws dots in one
  batched call per depth band: `drawRawPoints` for the single-colour fast path,
  `drawRawAtlas` when per-dot colours are set (zero per-frame allocation in both
  cases). Rotation never triggers a widget rebuild — only a repaint via a shared
  `ChangeNotifier`.
- The **widget layer** uses a `Flow` to re-position markers every frame via
  matrix transforms (no relayout, no rebuild). Back-facing markers are skipped
  entirely, so they stop receiving taps.
- Markers fade (opacity) as they approach the sphere's silhouette and disappear
  when they pass behind.

**Performance:**
- ~0.1 ms per frame for coordinate projection and layout.
- 60 fps sustained on Impeller (iOS 15+, Android 12+).
- Dragging the globe costs only a repaint, not a full rebuild.

## Why dot_globe?

### vs. `cobe_flutter`

`cobe_flutter` is a solid WebGL port, but markers are limited to small circles or
text labels baked into the shader. `dot_globe` lets you use any Flutter widget —
images, custom bubbles, charts — with full layout freedom.

### vs. textured-globe packages

Packages using `earth.png` + 3D mesh require asset bundles, GPU shaders, and
plugin code. `dot_globe` is pure Dart, zero assets, zero plugins — lighter,
simpler, faster to ship.

### vs. plain map libraries

Maps are designed for geographic data. If you want a **pretty, animated, tactile
globe as a UI component** — to show global stats, highlight regions, or just
delight users — a dotted globe is lower overhead and more visually distinctive.

## Platform support

| iOS | Android | Web | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

`dot_globe` is pure Dart; everything renders through Flutter's native Canvas
and Transform APIs. There are no plugin channels, native code, or platform-specific code paths.

## FAQ

**Q. Do markers need to be small?**
No. A marker can be as large as you want — a full `Card`, a chart widget, or a
`ListView`. It will clip to the sphere's silhouette and fade automatically.

**Q. Can I tap markers?**
Yes. Markers are regular `Widget`s, so they receive taps, gestures, and state
changes like any other Flutter widget. Back-facing markers are invisible and skip
hit-testing.

**Q. How many markers can I add?**
Go crazy. Each marker is just a widget in a `Flow`. Layout cost is negligible;
the paint cost depends on the marker complexity, not the count. Tested with
100+ markers at 60 fps.

**Q. What if I want the globe paused to save power?**
Set `paused: true`. The frame loop stops entirely. When you set `paused: false`,
it resumes. Pair it with `VisibilityDetector` to pause when the globe scrolls
off-screen.

```dart
VisibilityDetector(
  key: Key('my_globe'),
  onVisibilityChanged: (info) {
    setState(() => _globePaused = info.visibleFraction < 0.1);
  },
  child: DotGlobe(paused: _globePaused, ...),
)
```

**Q. Can I customize the dot pattern?**
Yes — two independent axes:

- **Shape / position**: pass a `DotGlobeGeometry` to `DotGlobe(geometry:)`.
  Build one from lat/lng pairs (`DotGlobeGeometry.fromLatLng`), from a custom
  `.bin` asset (`fromAsset`), or from raw bytes (`fromPackedInt16`). See the
  [Custom dot data](#custom-dot-data) section for details, including how to
  regenerate the bundled asset at higher Natural Earth resolutions.
- **Colour**: use the immutable fillers on any geometry — drape a satellite
  image (`colorizedFromImageProvider`), drive from data values
  (`colorizeByValues` with a `DotGlobeColormap`), apply a callback
  (`colorize`), or supply a raw `Int32List` (`withColors`). See the
  [Per-dot colours & textures](#per-dot-colours--textures) section.

**Q. What about haptics or sound?**
`dot_globe` is a pure rendering widget. Wrap it with your haptic / audio layer
as needed — e.g., trigger haptics in `controller.addListener()`.

## Example

A full showcase app lives in [`example/`](example/). To run it:

```bash
cd example
flutter run
```

## Contributing

Issues and PRs welcome — especially for new presets, performance tuning, and test
coverage. Run the test suite:

```bash
flutter test
cd example && flutter test
```

## License

[MIT](LICENSE) © 2026 cccmax.
