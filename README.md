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
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/world_cup.webp" width="150" alt="World Cup"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/presets.webp" width="150" alt="Presets"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/neon.webp" width="150" alt="Neon"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/routes.webp" width="150" alt="Routes"/>
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
- **Full gesture control** — drag to rotate with inertia decay, auto-spin when
  idle, configurable tilt limits, elastic spring-back to rest pitch.
- **Nine color presets** — `light`, `dark`, `polymarket`, `neon`, `sunset`,
  `mono`, `emerald`, `pastel`, `midnight`. One-line styling or customize with
  `copyWith`.
- **Imperative controller** — spin to a coordinate, observe the current facing
  point, drive animations from outside the widget tree.

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

### DotGlobe parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `style` | `DotGlobeStyle.light` | Visual config: colors, lighting, dot size. Pick a preset or customize. |
| `markers` | `[]` | Widgets pinned to the globe. |
| `arcs` | `[]` | Great-circle arcs drawn over the globe, beneath the markers. |
| `controller` | `null` | Optional handle to drive rotation and read facing point. |
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

| Method | Returns | Notes |
| --- | --- | --- |
| `animateTo({latitude?, longitude?, duration, curve})` | `Future<void>` | Spin to a coordinate with easing; omitted axes keep their current value. Pitch is clamped to `maxTilt`. |
| `jumpTo({latitude?, longitude?})` | `void` | Snap instantly; omitted axes unchanged. |
| `facing` | `DotGlobeFacing?` | Current facing coordinate; `null` if not attached. |
| `isAttached` | `bool` | Whether the controller is bound to a mounted globe. |
| `addListener`, `removeListener`, `dispose` | | Standard `ChangeNotifier` API; `facing` updates fire on every rotation frame. |

### DotGlobeMarker parameters

| Parameter | Type | Notes |
| --- | --- | --- |
| `latitude` | `double` | Degrees north; south is negative. |
| `longitude` | `double` | Degrees east; west is negative. |
| `child` | `Widget` | The widget rendered at this coordinate. Can be anything: `Text`, `Image`, `Icon`, custom widgets. |
| `anchor` | `Alignment` | Which point of `child` pins to the projected coordinate. Default `center`; use `bottomCenter` for bubbles with a tail. |

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

## How it works

**Geometry:**
- ~6,300 land dots are sampled from Natural Earth's 110m coastline data using a
  Fibonacci-sphere distribution.
- The globe is a unit sphere in the `[-1, 1]^3` coordinate space.
- Each frame, the sphere rotates by two angles (yaw / longitude, pitch /
  latitude).

**Rendering:**
- The **canvas layer** (`CustomPaint` with `DotGlobePainter`) draws dots in one
  batched `drawRawPoints` call per depth band. Rotation never triggers a widget
  rebuild — only a repaint via a shared `ChangeNotifier`.
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
Not directly — the land geometry is baked into `assets/land_dots.bin` at build
time. It's based on Natural Earth 110m data, which is a good balance of detail
and performance. Custom geometries are a future enhancement.

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
