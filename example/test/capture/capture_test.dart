// Headless screenshot capture: renders each hero scene to a sequence of PNG
// frames in build/screenshots/ using the real raster pipeline — no browser, no
// simulator. Run from the example dir with:
//
//   flutter test test/capture/capture_test.dart
//
// Then convert the frames to animated WebP via ../tool/capture_webp.sh.
//
// Uses [LiveTestWidgetsFlutterBinding] so the real raster pipeline runs — the
// default automated binding uses fake-async and does not flush frames, which
// hangs `RenderRepaintBoundary.toImage` after the first capture.
//
// Scenes are intentionally emoji-free: flutter_tester has no flag-emoji font,
// so country flags would render as tofu. Country codes + accent dots read
// cleanly and match the package's minimal aesthetic.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'package:dot_globe_example/demos/demo_geometries.dart';
import 'package:dot_globe_example/demos/light_demo.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const int _kFrames = 64;
const Duration _kStep = Duration(milliseconds: 55);
const double _kPixelRatio = 2.0;

// Pre-built coloured geometries, warmed once in setUpAll via the shared pure
// builders so every frame paints from the cached cloud (no async per frame).
late final DotGlobeGeometry _naturalGeometry;
late final DotGlobeGeometry _heatmapTurboGeometry;
late final DotGlobeGeometry _fantasyGeometry;
late final DotGlobeGeometry _dartTextGeometry;

class _Spec {
  const _Spec(this.name, this.size, this.builder);
  final String name;
  final Size size;
  final Widget Function() builder;
}

final List<_Spec> _scenes = <_Spec>[
  _Spec('showcase', const Size(480, 480), () => const _ShowcaseScene()),
  _Spec('world_cup', const Size(380, 620), () => const _WorldCupScene()),
  _Spec('light', const Size(380, 620), () => const LightDemo(paused: false)),
  _Spec('presets', const Size(380, 620), () => const _PresetScene()),
  _Spec('neon', const Size(460, 460), () => const _NeonScene()),
  _Spec('controller', const Size(380, 620), () => const _ControllerScene()),
  _Spec('natural', const Size(480, 480), () => const _NaturalScene()),
  _Spec('heatmap_turbo', const Size(480, 480), () => const _HeatmapScene()),
  _Spec('fantasy', const Size(480, 480), () => const _FantasyScene()),
  _Spec('custom_text', const Size(480, 480), () => const _CustomTextScene()),
];

Future<void> _loadRealFonts() async {
  // flutter_tester boots with test fonts (white blocks), so pull the real
  // Roboto + MaterialIcons off disk and feed them in via FontLoader.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      '/Users/CCCMAX/Applications/flutter';
  final fontsDir = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$fontsDir/$f').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', <String>[
    'Roboto-Thin.ttf',
    'Roboto-Light.ttf',
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await load('MaterialIcons', <String>['MaterialIcons-Regular.otf']);
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  Directory('build/screenshots').createSync(recursive: true);

  setUpAll(() async {
    await _loadRealFonts();
    // Warm the land-dot cache so the globe paints from frame 0.
    final base = await DotGlobeGeometry.load();
    // Warm the natural-colour Earth cloud (async); colorize is synchronous, so
    // the coloured/custom clouds can be built right after.
    _naturalGeometry = await DotGlobeGeometry.naturalEarth();
    _heatmapTurboGeometry =
        buildHeatmapGeometry(base, DotGlobeColormap.turbo);
    _fantasyGeometry = buildFantasyPlanet();
    _dartTextGeometry = buildDartTextGeometry();
  });

  for (final spec in _scenes) {
    testWidgets('capture ${spec.name}', (tester) async {
      // Size the render surface to the scene. Under LiveTestWidgetsFlutter
      // binding, tester.view.physicalSize is not honored, so setSurfaceSize is
      // the reliable way to get the intended portrait/square framing.
      await tester.binding.setSurfaceSize(spec.size);
      tester.view.devicePixelRatio = _kPixelRatio;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: 'Roboto',
          ),
          // Force the loaded Roboto onto every Text: the M3 theme's fontFamily
          // does not reliably propagate under flutter_tester, so text would
          // otherwise fall back to the Ahem test font (solid blocks). The
          // transparent Material gives Text a Material ancestor so it doesn't
          // get the debug "missing Material" underline.
          home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Roboto'),
            child: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: key,
                child: SizedBox.fromSize(size: spec.size, child: spec.builder()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (var i = 0; i < _kFrames; i++) {
        await tester.pump(_kStep);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync<Uint8List?>(() async {
          final image = await boundary.toImage(pixelRatio: _kPixelRatio);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data?.buffer.asUint8List();
        });
        if (bytes == null) fail('Failed to encode frame $i of ${spec.name}');
        File(
          'build/screenshots/${spec.name}_${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(bytes);
      }
      stdout.writeln('captured ${spec.name}: $_kFrames frames');
    });
  }
}

// ===================== Scenes =====================

/// The flagship hero: dotted globe + widget markers + a network of arcs —
/// every headline feature in one frame.
class _ShowcaseScene extends StatelessWidget {
  const _ShowcaseScene();

  // (name, lat, lng, anchor)
  static const _cities = <(String, double, double, Alignment)>[
    ('Tokyo', 35.7, 139.7, Alignment.bottomCenter),
    ('London', 51.5, -0.1, Alignment.bottomCenter),
    ('New York', 40.7, -74.0, Alignment.centerLeft),
    ('São Paulo', -23.5, -46.6, Alignment.topCenter),
    ('Dubai', 25.2, 55.3, Alignment.centerRight),
    ('Sydney', -33.9, 151.2, Alignment.topCenter),
  ];

  @override
  Widget build(BuildContext context) {
    return DotGlobe(
      style: DotGlobeStyle.midnight,
      radiusFactor: 0.52,
      initialLatitude: 20,
      initialLongitude: 20,
      arcs: const [
        DotGlobeArc(
          startLatitude: 35.7, startLongitude: 139.7,
          endLatitude: 51.5, endLongitude: -0.1,
          color: Color(0xFF4ED7F2), altitude: 0.45,
        ),
        DotGlobeArc(
          startLatitude: 40.7, startLongitude: -74.0,
          endLatitude: 51.5, endLongitude: -0.1,
          color: Color(0xFF6B8AE8), altitude: 0.3,
        ),
        DotGlobeArc(
          startLatitude: -23.5, startLongitude: -46.6,
          endLatitude: 51.5, endLongitude: -0.1,
          color: Color(0xFFFFD24C), altitude: 0.42, dashed: true,
        ),
        DotGlobeArc(
          startLatitude: 35.7, startLongitude: 139.7,
          endLatitude: -33.9, endLongitude: 151.2,
          color: Color(0xFFC678F5), altitude: 0.5, dashed: true,
        ),
        DotGlobeArc(
          startLatitude: 25.2, startLongitude: 55.3,
          endLatitude: 35.7, endLongitude: 139.7,
          color: Color(0xFF34D9A4), altitude: 0.32,
        ),
        DotGlobeArc(
          startLatitude: 40.7, startLongitude: -74.0,
          endLatitude: -23.5, endLongitude: -46.6,
          color: Color(0xFFFF5A5A), altitude: 0.28, width: 2.5,
        ),
      ],
      markers: [
        for (final (name, lat, lng, anchor) in _cities)
          DotGlobeMarker(
            latitude: lat,
            longitude: lng,
            anchor: anchor,
            child: _CityTag(name),
          ),
      ],
    );
  }
}

class _Country {
  const _Country(this.code, this.lat, this.lng, this.pct, this.accent);
  final String code;
  final double lat;
  final double lng;
  final int pct;
  final Color accent;
}

const _contenders = <_Country>[
  _Country('FRA', 46, 2, 16, Color(0xFF2E5BFF)),
  _Country('ESP', 40, -4, 16, Color(0xFFE03B3B)),
  _Country('ENG', 52, -1, 11, Color(0xFF5B7BFF)),
  _Country('POR', 39, -8, 10, Color(0xFF1FA66B)),
  _Country('ARG', -34, -64, 9, Color(0xFF5BC0EB)),
  _Country('BRA', -10, -55, 8, Color(0xFFF5C542)),
  _Country('GER', 51, 9, 5, Color(0xFF9AA3B2)),
  _Country('USA', 38, -97, 1, Color(0xFF3D6BE5)),
];

/// World-cup hero: globe + championship-odds bubbles.
class _WorldCupScene extends StatelessWidget {
  const _WorldCupScene();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF080C1C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE ODDS · WORLD CUP',
                  style: TextStyle(
                    color: Color(0xFF6E7BB0),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Who lifts the trophy?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DotGlobe(
              style: DotGlobeStyle.polymarket,
              initialLatitude: 16,
              markers: [
                for (final c in _contenders)
                  DotGlobeMarker(
                    latitude: c.lat,
                    longitude: c.lng,
                    anchor: Alignment.bottomCenter,
                    child: _OddsBubble(c: c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OddsBubble extends StatelessWidget {
  const _OddsBubble({required this.c});
  final _Country c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            c.code,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2240),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${c.pct}%',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid of every built-in preset, each a live mini globe.
class _PresetScene extends StatelessWidget {
  const _PresetScene();

  @override
  Widget build(BuildContext context) {
    final entries = DotGlobeStyle.presets.entries.toList();
    return ColoredBox(
      color: const Color(0xFF0B0E18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NINE PRESETS, ONE LINE',
              style: TextStyle(
                color: Color(0xFF6E7BB0),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [
                  for (final e in entries) _PresetCell(name: e.key, style: e.value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCell extends StatelessWidget {
  const _PresetCell({required this.name, required this.style});
  final String name;
  final DotGlobeStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: DotGlobe(
              style: style,
              interactive: false,
              autoRotateSpeed: 0.22,
              radiusFactor: 0.98,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFFB7C0DA),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A single full-bleed neon globe with glowing city dots.
class _NeonScene extends StatelessWidget {
  const _NeonScene();

  static const _cities = <(double, double)>[
    (35.7, 139.7),
    (51.5, -0.1),
    (40.7, -74.0),
    (-23.5, -46.6),
    (25.2, 55.3),
    (1.35, 103.8),
  ];

  @override
  Widget build(BuildContext context) {
    return DotGlobe(
      style: DotGlobeStyle.neon,
      initialLatitude: 14,
      markers: [
        for (final (lat, lng) in _cities)
          DotGlobeMarker(latitude: lat, longitude: lng, child: const _CityDot()),
      ],
    );
  }
}

class _CityDot extends StatelessWidget {
  const _CityDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFF2EF2E0),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2EF2E0).withValues(alpha: 0.85),
            blurRadius: 11,
            spreadRadius: 1.5,
          ),
        ],
      ),
    );
  }
}

// Dark per-dot style shared by the natural + heatmap scenes — mirrors the
// colored_dots demo's DotGlobeStyle (per-dot colours override dotColor).
const DotGlobeStyle _colouredDotsStyle = DotGlobeStyle(
  backgroundColor: Color(0xFF05070D), // Kit.voidColor
  dotColor: Color(0xFF334466), // fallback, overridden by per-dot colours
  sphereColor: Color(0x331A2A4A),
  dotRadius: 1.8,
);

/// Natural-colour Earth (DotGlobeGeometry.naturalEarth) — the colored_dots demo
/// "Natural" mode.
class _NaturalScene extends StatelessWidget {
  const _NaturalScene();

  @override
  Widget build(BuildContext context) {
    return DotGlobe(
      geometry: _naturalGeometry,
      style: _colouredDotsStyle,
      autoRotateSpeed: 0.10,
      radiusFactor: 0.88,
    );
  }
}

/// Heatmap (turbo colormap) — the colored_dots demo "Heatmap" mode.
class _HeatmapScene extends StatelessWidget {
  const _HeatmapScene();

  @override
  Widget build(BuildContext context) {
    return DotGlobe(
      geometry: _heatmapTurboGeometry,
      style: _colouredDotsStyle,
      autoRotateSpeed: 0.10,
      radiusFactor: 0.88,
    );
  }
}

/// Fantasy planet — procedural Fibonacci cloud + biome colours, POI pins, arcs.
/// Mirrors the fantasy_world demo's DotGlobe config.
class _FantasyScene extends StatelessWidget {
  const _FantasyScene();

  // POI markers — Material-icon pins (no emoji: flutter_tester has no emoji
  // font, so they would render as tofu).
  static const List<DotGlobeMarker> _markers = [
    DotGlobeMarker(
      latitude: 42.0,
      longitude: -30.0,
      anchor: Alignment.bottomCenter,
      child: _PinBadge(
          icon: Icons.castle, label: 'Capital', accent: Color(0xFFFFD966)),
    ),
    DotGlobeMarker(
      latitude: -18.0,
      longitude: 55.0,
      anchor: Alignment.bottomCenter,
      child: _PinBadge(
          icon: Icons.sports_kabaddi, label: 'Arena', accent: Color(0xFFFF6B6B)),
    ),
    DotGlobeMarker(
      latitude: 10.0,
      longitude: 130.0,
      anchor: Alignment.bottomCenter,
      child: _PinBadge(
          icon: Icons.diamond, label: 'Mine', accent: Color(0xFF7EC8E3)),
    ),
    DotGlobeMarker(
      latitude: -55.0,
      longitude: -110.0,
      anchor: Alignment.bottomCenter,
      child: _PinBadge(
          icon: Icons.local_fire_department,
          label: 'Lair',
          accent: Color(0xFFB07EFF)),
    ),
  ];

  // Three great-circle routes connecting the POIs (one dashed).
  static const List<DotGlobeArc> _arcs = [
    DotGlobeArc(
      startLatitude: 42.0,
      startLongitude: -30.0,
      endLatitude: -18.0,
      endLongitude: 55.0,
      color: Color(0xCCFFD966),
      altitude: 0.30,
      backOpacity: 0.12,
    ),
    DotGlobeArc(
      startLatitude: -18.0,
      startLongitude: 55.0,
      endLatitude: 10.0,
      endLongitude: 130.0,
      color: Color(0xCC7EC8E3),
      altitude: 0.25,
      dashed: true,
      backOpacity: 0.12,
    ),
    DotGlobeArc(
      startLatitude: 42.0,
      startLongitude: -30.0,
      endLatitude: -55.0,
      endLongitude: -110.0,
      color: Color(0xBBB07EFF),
      altitude: 0.40,
      backOpacity: 0.10,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF05070D), // Kit.voidColor
      child: DotGlobe(
        geometry: _fantasyGeometry,
        markers: _markers,
        arcs: _arcs,
        style: const DotGlobeStyle(
          backgroundColor: Color(0xFF05070D),
          dotColor: Color(0xFF1A3055),
          sphereColor: Color(0x22122030),
          dotRadius: 1.6,
        ),
        autoRotateSpeed: 0.06,
        radiusFactor: 0.80, // shrink so tall arcs stay in frame
        clipBehavior: Clip.hardEdge,
      ),
    );
  }
}

/// Custom text — a word rasterised into a dot cloud on the neon preset.
/// Mirrors the custom_data demo's "Text" mode.
class _CustomTextScene extends StatelessWidget {
  const _CustomTextScene();

  @override
  Widget build(BuildContext context) {
    return DotGlobe(
      geometry: _dartTextGeometry,
      style: DotGlobeStyle.neon,
      autoRotateSpeed: 0,
      radiusFactor: 0.88,
      initialLatitude: 0,
      initialLongitude: 0,
    );
  }
}

/// POI pin badge — Material-icon pin used as a fantasy-scene marker child.
class _PinBadge extends StatelessWidget {
  const _PinBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.60), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityTag extends StatelessWidget {
  const _CityTag(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1430).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x335A7BE0)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Color(0xFFD6E0FF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Controller showcase: a live facing read-out over an auto-rotating globe.
class _ControllerScene extends StatefulWidget {
  const _ControllerScene();

  @override
  State<_ControllerScene> createState() => _ControllerSceneState();
}

class _ControllerSceneState extends State<_ControllerScene> {
  final DotGlobeController _controller = DotGlobeController();
  DotGlobeFacing _facing = const DotGlobeFacing(14, 10);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final f = _controller.facing;
      if (f != null && mounted) setState(() => _facing = f);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF04140F),
      child: Stack(
        children: [
          Positioned.fill(
            child: DotGlobe(
              controller: _controller,
              style: DotGlobeStyle.emerald,
              initialLatitude: 14,
              autoRotateSpeed: 0.3,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 24,
            child: Center(child: _FacingChip(facing: _facing)),
          ),
        ],
      ),
    );
  }
}

class _FacingChip extends StatelessWidget {
  const _FacingChip({required this.facing});
  final DotGlobeFacing facing;

  String _fmt(double v, String pos, String neg) =>
      '${v.abs().toStringAsFixed(1)}° ${v >= 0 ? pos : neg}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF06241B).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF14B88A).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location, size: 15, color: Color(0xFF34D9A4)),
          const SizedBox(width: 8),
          Text(
            'facing  ${_fmt(facing.latitude, 'N', 'S')}  ·  '
            '${_fmt(facing.longitude, 'E', 'W')}',
            style: const TextStyle(
              color: Color(0xFFCFF5E7),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
