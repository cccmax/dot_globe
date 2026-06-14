import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// Routes showcase: city markers connected by great-circle [DotGlobeArc]s —
/// flight-path lines that bow off the sphere, solid on the near side and dashed
/// as they curve around the back.
class RoutesDemo extends StatelessWidget {
  const RoutesDemo({super.key, required this.paused});

  final bool paused;

  static const List<_City> _cities = [
    _City('Tokyo', 35.7, 139.7, Alignment.bottomCenter),
    _City('Beijing', 39.9, 116.4, Alignment.bottomCenter),
    _City('Sydney', -33.9, 151.2, Alignment.topCenter),
    _City('Cairo', 30.0, 31.2, Alignment.centerLeft),
    _City('London', 51.5, -0.1, Alignment.bottomCenter),
    _City('New York', 40.7, -74.0, Alignment.centerRight),
  ];

  static const List<DotGlobeArc> _routes = [
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
  ];

  @override
  Widget build(BuildContext context) {
    const style = DotGlobeStyle.midnight;
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
                Eyebrow('GREAT-CIRCLE ARCS', accent: accent, onDark: true),
                const SizedBox(height: 12),
                Text('Connect the dots', style: Kit.display(Kit.inkOn(style))),
                const SizedBox(height: 8),
                Text(
                  'Point-to-point routes bow off the sphere — solid on the near '
                  'side, dashed as they curve around the back.',
                  style: Kit.body(Kit.inkDimOn(style)),
                ),
              ],
            ),
          ),
          Expanded(
            child: DotGlobe(
              style: style,
              paused: paused,
              // Shrink the globe so the arcs have headroom to bow off the
              // sphere without spilling out of the widget. Rule of thumb:
              // radiusFactor <= 1 / (1 + maxArcAltitude).
              radiusFactor: 0.52,
              initialLatitude: 18,
              initialLongitude: 90,
              arcs: _routes,
              markers: [
                for (final c in _cities)
                  DotGlobeMarker(
                    latitude: c.lat,
                    longitude: c.lng,
                    anchor: c.anchor,
                    child: _CityTag(name: c.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _City {
  const _City(this.name, this.lat, this.lng, this.anchor);
  final String name;
  final double lat;
  final double lng;
  final Alignment anchor;
}

class _CityTag extends StatelessWidget {
  const _CityTag({required this.name});
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
