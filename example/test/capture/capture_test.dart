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
import 'package:dot_globe/src/dot_globe_geometry.dart';
import 'package:flutter/material.dart';

import 'package:dot_globe_example/demos/light_demo.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const int _kFrames = 64;
const Duration _kStep = Duration(milliseconds: 55);
const double _kPixelRatio = 2.0;

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
  _Spec('routes', const Size(460, 460), () => const _RoutesScene()),
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
    await DotGlobeGeometry.load();
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

/// Routes: city markers connected by great-circle arcs (flight paths).
class _RoutesScene extends StatelessWidget {
  const _RoutesScene();

  @override
  Widget build(BuildContext context) {
    return DotGlobe(
      style: DotGlobeStyle.midnight,
      radiusFactor: 0.52,
      initialLatitude: 18,
      initialLongitude: 90,
      arcs: const [
        DotGlobeArc(
          startLatitude: 35.7, startLongitude: 139.7,
          endLatitude: 51.5, endLongitude: -0.1,
          color: Color(0xFFFFD24C), altitude: 0.45, dashed: true,
        ),
        DotGlobeArc(
          startLatitude: -33.9, startLongitude: 151.2,
          endLatitude: 30.0, endLongitude: 31.2,
          color: Color(0xFFFF5A5A), altitude: 0.3, width: 2.5,
        ),
        DotGlobeArc(
          startLatitude: 35.7, startLongitude: 139.7,
          endLatitude: -33.9, endLongitude: 151.2,
          color: Color(0xFFC678F5), altitude: 0.5, dashed: true,
        ),
        DotGlobeArc(
          startLatitude: 39.9, startLongitude: 116.4,
          endLatitude: 30.0, endLongitude: 31.2,
          color: Color(0xFF4ED7F2), altitude: 0.32,
        ),
        DotGlobeArc(
          startLatitude: 40.7, startLongitude: -74.0,
          endLatitude: 51.5, endLongitude: -0.1,
          color: Color(0xFF6B8AE8), altitude: 0.28,
        ),
      ],
      markers: const [
        DotGlobeMarker(latitude: 35.7, longitude: 139.7, anchor: Alignment.bottomCenter, child: _CityTag('Tokyo')),
        DotGlobeMarker(latitude: 39.9, longitude: 116.4, anchor: Alignment.bottomCenter, child: _CityTag('Beijing')),
        DotGlobeMarker(latitude: -33.9, longitude: 151.2, anchor: Alignment.topCenter, child: _CityTag('Sydney')),
        DotGlobeMarker(latitude: 30.0, longitude: 31.2, anchor: Alignment.centerLeft, child: _CityTag('Cairo')),
        DotGlobeMarker(latitude: 51.5, longitude: -0.1, anchor: Alignment.bottomCenter, child: _CityTag('London')),
        DotGlobeMarker(latitude: 40.7, longitude: -74.0, anchor: Alignment.centerRight, child: _CityTag('New York')),
      ],
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
