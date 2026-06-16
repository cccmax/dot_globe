import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_geometries.dart';
import 'demo_kit.dart';

// ---------------------------------------------------------------------------
// Data model — fictional POI
// ---------------------------------------------------------------------------

class _Poi {
  const _Poi(this.name, this.icon, this.lat, this.lng, this.accent);
  final String name;
  final IconData icon;
  final double lat;
  final double lng;
  final Color accent;
}

// Four fictional locations spread across the procedural planet. Material icons
// (not emoji) so they render on every platform, including Flutter web.
const List<_Poi> _pois = [
  _Poi('Capital', Icons.castle, 42.0, -30.0, Color(0xFFFFD966)),
  _Poi('Arena', Icons.sports_kabaddi, -18.0, 55.0, Color(0xFFFF6B6B)),
  _Poi('Mine', Icons.diamond, 10.0, 130.0, Color(0xFF7EC8E3)),
  _Poi('Lair', Icons.local_fire_department, -55.0, -110.0, Color(0xFFB07EFF)),
];

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

/// Combines every major dot_globe feature in one fictional planet:
/// custom full-sphere Fibonacci cloud, per-dot biome colours, widget markers,
/// great-circle arcs, pinch zoom, and programmatic fly-to.
class FantasyWorldDemo extends StatefulWidget {
  const FantasyWorldDemo({super.key, required this.paused});

  final bool paused;

  @override
  State<FantasyWorldDemo> createState() => _FantasyWorldDemoState();
}

class _FantasyWorldDemoState extends State<FantasyWorldDemo> {
  DotGlobeGeometry? _planet;
  bool _loading = true;
  int _activePoi = -1; // index of the last fly-to destination, -1 = none
  bool _flying = false;

  final DotGlobeController _controller = DotGlobeController();

  // Accent colour for chrome — gold of the Capital.
  static const Color _accent = Color(0xFFFFD966);

  // ---------------------------------------------------------------------------
  // Markers — one badge per POI, built once (const where possible).
  // ---------------------------------------------------------------------------
  static const List<DotGlobeMarker> _markers = [
    DotGlobeMarker(
      latitude: 42.0,
      longitude: -30.0,
      anchor: Alignment.bottomCenter,
      scaleWithZoom: true,
      child: _PinBadge(
          icon: Icons.castle, label: 'Capital', accent: Color(0xFFFFD966)),
    ),
    DotGlobeMarker(
      latitude: -18.0,
      longitude: 55.0,
      anchor: Alignment.bottomCenter,
      scaleWithZoom: true,
      child: _PinBadge(
          icon: Icons.sports_kabaddi, label: 'Arena', accent: Color(0xFFFF6B6B)),
    ),
    DotGlobeMarker(
      latitude: 10.0,
      longitude: 130.0,
      anchor: Alignment.bottomCenter,
      scaleWithZoom: true,
      child: _PinBadge(
          icon: Icons.diamond, label: 'Mine', accent: Color(0xFF7EC8E3)),
    ),
    DotGlobeMarker(
      latitude: -55.0,
      longitude: -110.0,
      anchor: Alignment.bottomCenter,
      scaleWithZoom: true,
      child: _PinBadge(
          icon: Icons.local_fire_department,
          label: 'Lair',
          accent: Color(0xFFB07EFF)),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Arcs — three great-circle routes connecting POIs.
  // ---------------------------------------------------------------------------
  static const List<DotGlobeArc> _arcs = [
    // Capital → Arena  (solid gold trade route)
    DotGlobeArc(
      startLatitude: 42.0,
      startLongitude: -30.0,
      endLatitude: -18.0,
      endLongitude: 55.0,
      color: Color(0xCCFFD966),
      altitude: 0.30,
      backOpacity: 0.12,
    ),
    // Arena → Mine  (dashed blue shipping lane)
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
    // Capital → Lair  (purple danger road)
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

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _buildPlanet();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Build the planet geometry on the next microtask so initState returns
  // immediately and the frame paints the loading indicator first.
  Future<void> _buildPlanet() async {
    // Yield so the first frame renders (loading spinner visible).
    await Future<void>.microtask(() {});
    if (!mounted) return;

    // Built from the shared pure generator (see demo_geometries.dart): a
    // ~7000-point Fibonacci sphere coloured by a four-octave elevation field.
    // The capture test reuses the same builder for an identical planet.
    final coloured = buildFantasyPlanet();

    if (!mounted) return;
    setState(() {
      _planet = coloured;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Fly-to
  // ---------------------------------------------------------------------------

  Future<void> _flyTo(int index) async {
    if (_flying) return;
    final poi = _pois[index];
    setState(() {
      _flying = true;
      _activePoi = index;
    });
    await _controller.animateTo(
      latitude: poi.lat,
      longitude: poi.lng,
      scale: 2.4,
      hold: true,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    setState(() => _flying = false);
  }

  // Pull back to the high-altitude overview: zoom out to 1× and recentre,
  // resuming the idle spin (resetView returns to initialScale / facing).
  Future<void> _overview() async {
    setState(() => _activePoi = -1);
    await _controller.resetView(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      background: Kit.voidColor,
      accent: _accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 680;
          final globeSize = wide
              ? (constraints.maxHeight * 0.72).clamp(300.0, 520.0)
              : constraints.maxWidth.clamp(260.0, 440.0);

          final globe = _GlobeSection(
            planet: _planet,
            loading: _loading,
            size: globeSize,
            controller: _controller,
            paused: widget.paused,
          );

          final panel = _ControlPanel(
            pois: _pois,
            accent: _accent,
            activePoi: _activePoi,
            flying: _flying,
            onFlyTo: _flyTo,
            onOverview: _overview,
          );

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    'FANTASY WORLD  ·  all features composed',
                    accent: _accent,
                    onDark: true,
                  ),
                  const SizedBox(height: 12),
                  Text('Fantasy world.', style: Kit.display(Kit.ink)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Center(child: globe),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(child: panel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  'FANTASY WORLD  ·  all features composed',
                  accent: _accent,
                  onDark: true,
                ),
                const SizedBox(height: 10),
                Text('Fantasy world.', style: Kit.display(Kit.ink, size: 28)),
                const SizedBox(height: 20),
                Center(child: globe),
                const SizedBox(height: 20),
                panel,
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Globe section
// ---------------------------------------------------------------------------

class _GlobeSection extends StatelessWidget {
  const _GlobeSection({
    required this.planet,
    required this.loading,
    required this.size,
    required this.controller,
    required this.paused,
  });

  final DotGlobeGeometry? planet;
  final bool loading;
  final double size;
  final DotGlobeController controller;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD966),
                strokeWidth: 1.5,
              ),
            )
          : DotGlobe(
              key: ValueKey(planet),
              geometry: planet,
              markers: _FantasyWorldDemoState._markers,
              arcs: _FantasyWorldDemoState._arcs,
              controller: controller,
              style: const DotGlobeStyle(
                backgroundColor: Kit.voidColor,
                dotColor: Color(0xFF1A3055),
                sphereColor: Color(0x22122030),
                dotRadius: 1.6,
              ),
              paused: paused,
              autoRotateSpeed: 0.06,
              radiusFactor: 0.80, // shrink so tall arcs stay in frame
              zoomGesture: true,
              maxScale: 5.0,
              clipBehavior: Clip.hardEdge,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Control panel
// ---------------------------------------------------------------------------

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.pois,
    required this.accent,
    required this.activePoi,
    required this.flying,
    required this.onFlyTo,
    required this.onOverview,
  });

  final List<_Poi> pois;
  final Color accent;
  final int activePoi;
  final bool flying;
  final ValueChanged<int> onFlyTo;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('LOCATIONS', accent: accent, onDark: true),
          const SizedBox(height: 18),
          // Fly-to buttons
          Text('FLY TO', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < pois.length; i++)
                _PoiChip(
                  poi: pois[i],
                  active: activePoi == i,
                  onTap: () => onFlyTo(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Pull back out to the high-altitude overview (resetView → 1× zoom).
          GestureDetector(
            onTap: onOverview,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_out_map, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text('Overview',
                      style: Kit.body(Kit.ink)
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Feature caption
          Text('FEATURES COMPOSED', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 14),
          const _FeatureBadgeRow(),
          const SizedBox(height: 18),

          // Description
          Text(
            'A procedural planet generated in pure Dart: ~7 000-point Fibonacci '
            'sphere cloud coloured by a four-octave sine-sum elevation field '
            '(deep ocean → shelf → beach → grassland → forest → mountain → '
            'snow peak, with polar ice override above 68 °). Four fictional '
            'POI markers pin the globe; three great-circle arcs (one dashed) '
            'connect them. Pinch to zoom up to 5×; tap a location to '
            'fly-to + zoom in. Every feature is active at once.',
            style: Kit.body(Kit.inkDim),
          ),

          const SizedBox(height: 16),

          // Code hint
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Text(
              '// Full-sphere Fibonacci cloud + biome colours\n'
              'final geo = DotGlobeGeometry.fromLatLng(points);\n'
              'final planet = geo.colorize((lat, lng, _) {\n'
              '  final e = _elevation(lat, lng); // sine octaves\n'
              '  return _biomeColor(e, lat.abs());\n'
              '});\n'
              'DotGlobe(\n'
              '  geometry: planet,\n'
              '  markers: _markers,  // 4 POI badges\n'
              '  arcs: _arcs,        // 3 great-circle routes\n'
              '  controller: _ctrl,  // animateTo(...)\n'
              '  zoomGesture: true, maxScale: 5,\n'
              '  radiusFactor: 0.80,\n'
              ')',
              style: Kit.mono(accent, size: 11.0),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// POI fly-to chip
// ---------------------------------------------------------------------------

class _PoiChip extends StatelessWidget {
  const _PoiChip({
    required this.poi,
    required this.active,
    required this.onTap,
  });

  final _Poi poi;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = poi.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.10),
            width: active ? 1.5 : 1.0,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(poi.icon, size: 15, color: color),
            const SizedBox(width: 8),
            Text(
              poi.name,
              style: Kit.body(active ? Kit.ink : Kit.inkDim)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature badge row — six tiny pills, one per composed feature.
// ---------------------------------------------------------------------------

class _FeatureBadgeRow extends StatelessWidget {
  const _FeatureBadgeRow();

  static const List<(String, Color)> _features = [
    ('Fibonacci cloud', Color(0xFF4E9A47)),
    ('Biome colours', Color(0xFF1A7A8A)),
    ('Markers', Color(0xFFFFD966)),
    ('Arcs', Color(0xFF7EC8E3)),
    ('Pinch zoom', Color(0xFFB07EFF)),
    ('Fly-to', Color(0xFFFF6B6B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, color) in _features)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.40)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// POI pin badge — shown as a marker on the globe.
// ---------------------------------------------------------------------------

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
