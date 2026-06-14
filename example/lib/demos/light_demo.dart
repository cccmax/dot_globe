import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// Light-mode showcase: the flat `DotGlobeStyle.light` preset (no front
/// lighting, no depth shading — the same look used in production) with region
/// markers that pair a drawn mini-flag (an image-like widget) with a label.
/// Demonstrates that a marker can be any widget, not just a dot.
class LightDemo extends StatelessWidget {
  const LightDemo({super.key, required this.paused});

  final bool paused;

  // (name, lat, lng, flag bands, vertical?)
  static const List<_Region> _regions = [
    _Region('France', 46, 2, [Color(0xFF0055A4), Colors.white, Color(0xFFEF4135)], true),
    _Region('Netherlands', 52, 5, [Color(0xFFAE1C28), Colors.white, Color(0xFF21468B)], false),
    _Region('Germany', 51, 9, [Colors.black, Color(0xFFDD0000), Color(0xFFFFCE00)], false),
    _Region('Italy', 42, 12, [Color(0xFF008C45), Colors.white, Color(0xFFCD212A)], true),
    _Region('Portugal', 39, -8, [Color(0xFF046A38), Color(0xFFDA291C)], true),
    _Region('Belgium', 50.6, 4.5, [Colors.black, Color(0xFFFDDA24), Color(0xFFEF3340)], true),
    _Region('Argentina', -34, -64, [Color(0xFF74ACDF), Colors.white, Color(0xFF74ACDF)], false),
    _Region('Brazil', -10, -55, [Color(0xFF009C3B), Color(0xFFFFDF00)], true),
  ];

  @override
  Widget build(BuildContext context) {
    const style = DotGlobeStyle.light; // flat: sphereLight false, depthFade 0
    final accent = Kit.accentOf(style);
    return Backdrop(
      background: style.backgroundColor!,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('LIGHT · NO SHADING', accent: accent, onDark: false),
                const SizedBox(height: 12),
                Text('Flat & airy', style: Kit.display(Kit.inkOn(style))),
                const SizedBox(height: 8),
                Text(
                  'The light preset with front-lighting off — the production look. '
                  'Each region marker is a drawn flag plus a label.',
                  style: Kit.body(Kit.inkDimOn(style)),
                ),
              ],
            ),
          ),
          Expanded(
            child: DotGlobe(
              style: style,
              paused: paused,
              initialLatitude: 24,
              initialLongitude: 6,
              markers: [
                for (final r in _regions)
                  DotGlobeMarker(
                    latitude: r.lat,
                    longitude: r.lng,
                    anchor: Alignment.bottomCenter,
                    child: _RegionTag(region: r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Region {
  const _Region(this.name, this.lat, this.lng, this.bands, this.vertical);
  final String name;
  final double lat;
  final double lng;
  final List<Color> bands;
  final bool vertical;
}

/// A region marker: a small drawn flag (image-like widget) + the region name.
class _RegionTag extends StatelessWidget {
  const _RegionTag({required this.region});

  final _Region region;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 11, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x1F1B2A55), blurRadius: 10, offset: Offset(0, 3)),
        ],
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniFlag(bands: region.bands, vertical: region.vertical),
          const SizedBox(width: 7),
          Text(
            region.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2240),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny banded flag rendered purely with widgets — stands in for an image.
class _MiniFlag extends StatelessWidget {
  const _MiniFlag({required this.bands, required this.vertical});

  final List<Color> bands;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final stripes = [
      for (final c in bands) Expanded(child: ColoredBox(color: c)),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 22,
        height: 16,
        child: vertical
            ? Row(children: stripes)
            : Column(children: stripes),
      ),
    );
  }
}
