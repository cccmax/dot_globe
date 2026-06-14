import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// Proof that a [DotGlobeMarker.child] is *any* widget: an avatar, a bare
/// label, a custom gradient pill, an emoji ping, and a shadowed mini-card all
/// share one globe. Tap-throughs are honest too — back-facing markers stop
/// hit-testing automatically.
class MarkerVarietyDemo extends StatelessWidget {
  const MarkerVarietyDemo({super.key, required this.paused});
  final bool paused;

  static const DotGlobeStyle _style = DotGlobeStyle.midnight;

  @override
  Widget build(BuildContext context) {
    final accent = Kit.accentOf(_style);
    final bg = _style.backgroundColor ?? Kit.voidColor;

    return Backdrop(
      background: bg,
      accent: accent,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 720;
          final globeSize = wide
              ? (c.maxHeight * 0.82).clamp(340.0, 580.0)
              : c.maxWidth.clamp(300.0, 480.0);

          final globe = SizedBox.square(
            dimension: globeSize.toDouble(),
            child: DotGlobe(
              style: _style,
              paused: paused,
              autoRotateSpeed: 0.08,
              initialLongitude: 10,
              radiusFactor: 0.86,
              markers: [
                // 1 — an avatar (CircleAvatar with a ring).
                DotGlobeMarker(
                  latitude: 48,
                  longitude: 2,
                  anchor: Alignment.center,
                  child: _AvatarMarker(accent: accent),
                ),
                // 2 — a bare text label, no chrome at all.
                const DotGlobeMarker(
                  latitude: 28,
                  longitude: 77,
                  anchor: Alignment.bottomCenter,
                  child: _TextMarker(),
                ),
                // 3 — a custom gradient pill.
                DotGlobeMarker(
                  latitude: -23,
                  longitude: -46,
                  anchor: Alignment.bottomCenter,
                  child: _GradientPill(accent: accent),
                ),
                // 4 — an emoji "ping" with a pulsing halo.
                const DotGlobeMarker(
                  latitude: 35,
                  longitude: 139,
                  anchor: Alignment.center,
                  child: _PingMarker(emoji: '🗼'),
                ),
                // 5 — a shadowed mini-card.
                const DotGlobeMarker(
                  latitude: 40,
                  longitude: -74,
                  anchor: Alignment.bottomCenter,
                  child: _CardMarker(),
                ),
              ],
            ),
          );

          final caption = _Caption(accent: accent);

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    // Centred when it fits, scrollable on short windows.
                    child: SingleChildScrollView(
                      child: caption,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: Center(child: globe)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                caption,
                const SizedBox(height: 12),
                Center(child: globe),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.accent});
  final Color accent;

  static const _legend = [
    ('Avatar', 'CircleAvatar + ring'),
    ('Label', 'plain Text, no box'),
    ('Gradient pill', 'custom Container'),
    ('Emoji ping', 'pulsing halo'),
    ('Mini-card', 'shadowed surface'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('ANY WIDGET, PINNED', accent: accent, onDark: true),
        const SizedBox(height: 18),
        Text('Markers are\njust widgets.', style: Kit.display(Kit.ink, size: 36)),
        const SizedBox(height: 16),
        SizedBox(
          width: 320,
          child: Text(
            'A DotGlobeMarker takes any child and projects it onto the sphere — '
            'fading and disabling taps as it rotates to the back.',
            style: Kit.body(Kit.inkDim),
          ),
        ),
        const SizedBox(height: 22),
        for (final item in _legend)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  item.$1,
                  style: Kit.body(Kit.ink).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(item.$2, style: Kit.body(Kit.inkDim)),
              ],
            ),
          ),
      ],
    );
  }
}

class _AvatarMarker extends StatelessWidget {
  const _AvatarMarker({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [accent, Colors.white, accent],
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 14),
        ],
      ),
      child: const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0xFF0B1020),
        child: Text('AM', style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.5,
        )),
      ),
    );
  }
}

class _TextMarker extends StatelessWidget {
  const _TextMarker();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'DELHI',
      style: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
      ),
    );
  }
}

class _GradientPill extends StatelessWidget {
  const _GradientPill({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CFF), Color(0xFF35C2FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        '◎ São Paulo',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PingMarker extends StatefulWidget {
  const _PingMarker({required this.emoji});
  final String emoji;

  @override
  State<_PingMarker> createState() => _PingMarkerState();
}

class _PingMarkerState extends State<_PingMarker>
    with SingleTickerProviderStateMixin {
  // Built in initState so the ticker is created while the element is active.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The expanding halo ring.
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Opacity(
                opacity: (1 - t) * 0.7,
                child: Container(
                  width: 20 + t * 36,
                  height: 20 + t * 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF7DF9D6), width: 2),
                  ),
                ),
              );
            },
          ),
          Text(widget.emoji, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}

class _CardMarker extends StatelessWidget {
  const _CardMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🗽', style: TextStyle(fontSize: 18)),
          SizedBox(width: 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New York',
                  style: TextStyle(
                    color: Color(0xFF0B1020),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
              SizedBox(height: 2),
              Text('8.4M people',
                  style: TextStyle(
                    color: Color(0xFF6B7388),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
