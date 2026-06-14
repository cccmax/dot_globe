import 'dart:async';

import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// One contender on the map.
class _Team {
  const _Team(this.name, this.flag, this.lat, this.lng, this.pct);
  final String name;
  final String flag;
  final double lat;
  final double lng;
  final int pct;
}

/// Championship odds, drawn as flag bubbles pinned to each nation. This is the
/// hero page — a big lit globe (the Polymarket preset) with probability
/// bubbles that scale and stack by likelihood, mirroring the prediction-market
/// map this package was built to recreate.
class WorldCupDemo extends StatefulWidget {
  const WorldCupDemo({super.key, required this.paused});

  /// Pauses the globe's frame loop while another tab is on screen.
  final bool paused;

  @override
  State<WorldCupDemo> createState() => _WorldCupDemoState();
}

class _WorldCupDemoState extends State<WorldCupDemo> {
  // Ordered low → high so higher-probability bubbles paint last (on top).
  static const List<_Team> _teams = [
    _Team('USA', '🇺🇸', 38, -97, 1),
    _Team('Norway', '🇳🇴', 61, 8, 2),
    _Team('Netherlands', '🇳🇱', 52, 5, 4),
    _Team('Germany', '🇩🇪', 51, 9, 5),
    _Team('Brazil', '🇧🇷', -10, -55, 8),
    _Team('Argentina', '🇦🇷', -34, -64, 9),
    _Team('Portugal', '🇵🇹', 39, -8, 10),
    _Team('England', '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 52, -1, 11),
    _Team('Spain', '🇪🇸', 40, -4, 16),
    _Team('France', '🇫🇷', 46, 2, 16),
  ];

  static const DotGlobeStyle _style = DotGlobeStyle.polymarket;

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
              ? c.maxHeight.clamp(360.0, 620.0)
              : c.maxWidth.clamp(300.0, 560.0);

          final globe = SizedBox.square(
            dimension: globeSize.toDouble(),
            child: DotGlobe(
              style: _style,
              paused: widget.paused,
              autoRotateSpeed: 0.06,
              initialLongitude: -10,
              initialLatitude: 22,
              radiusFactor: 0.84,
              markers: [
                for (var i = 0; i < _teams.length; i++)
                  DotGlobeMarker(
                    latitude: _teams[i].lat,
                    longitude: _teams[i].lng,
                    anchor: Alignment.bottomCenter,
                    child: _OddsBubble(
                      team: _teams[i],
                      accent: accent,
                      delayMs: 120 + i * 70,
                      leader: _teams[i].pct >= 16,
                    ),
                  ),
              ],
            ),
          );

          final header = _Header(accent: accent);

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    // Centred when it fits, scrollable when the window is short
                    // — keeps the header + leaderboard from overflowing.
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          const SizedBox(height: 28),
                          _Leaderboard(teams: _teams, accent: accent),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: Center(child: globe),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 8),
                Center(child: globe),
                const SizedBox(height: 16),
                _Leaderboard(teams: _teams, accent: accent),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('LIVE ODDS · WORLD CUP', accent: accent, onDark: true),
        const SizedBox(height: 18),
        Text('Who lifts\nthe trophy?', style: Kit.display(Kit.ink, size: 40)),
        const SizedBox(height: 14),
        SizedBox(
          width: 360,
          child: Text(
            'Championship probabilities pinned to each nation. Drag to spin '
            'the world; bubbles fade as they rotate to the far side.',
            style: Kit.body(Kit.inkDim),
          ),
        ),
      ],
    );
  }
}

/// The compact odds table beside the globe — reinforces the data without
/// crowding the map.
class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.teams, required this.accent});
  final List<_Team> teams;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Highest first for the table.
    final ranked = [...teams]..sort((a, b) => b.pct.compareTo(a.pct));
    final top = ranked.take(5).toList();
    final maxPct = ranked.first.pct;

    return GlassPanel(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOP CONTENDERS',
                  style: Kit.label(Kit.inkDim),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 8),
              Text('IMPLIED %', style: Kit.label(Kit.inkDim)),
            ],
          ),
          const SizedBox(height: 16),
          for (final t in top) ...[
            _Row(team: t, accent: accent, fraction: t.pct / maxPct),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.team, required this.accent, required this.fraction});
  final _Team team;
  final Color accent;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(team.flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        // Flexible (not a fixed width) so the row never overflows when the
        // side panel is narrow; the name ellipsises and yields to the bar.
        Flexible(
          flex: 4,
          child: Text(
            team.name,
            style: Kit.body(Kit.ink).copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 40,
          child: Text(
            '${team.pct}%',
            textAlign: TextAlign.right,
            style: Kit.mono(Kit.ink, size: 13),
          ),
        ),
      ],
    );
  }
}

/// A white prediction-market bubble whose tail points at the nation. Leaders
/// (the highest odds) get an accent ring so the eye lands on them first.
class _OddsBubble extends StatefulWidget {
  const _OddsBubble({
    required this.team,
    required this.accent,
    required this.delayMs,
    required this.leader,
  });

  final _Team team;
  final Color accent;
  final int delayMs;
  final bool leader;

  @override
  State<_OddsBubble> createState() => _OddsBubbleState();
}

class _OddsBubbleState extends State<_OddsBubble>
    with SingleTickerProviderStateMixin {
  // Built in initState so the ticker is created while the element is active.
  late final AnimationController _c;
  late final Animation<double> _in;

  Timer? _entrance;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _in = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    // Staggered entrance; the timer is cancelled in dispose so it never leaks
    // if the page is left before the bubble appears.
    _entrance = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _entrance?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leader = widget.leader;
    return FadeTransition(
      opacity: _c,
      child: ScaleTransition(
        scale: _in,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: leader
                    ? Border.all(color: widget.accent, width: 1.6)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  if (leader)
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.team.flag,
                      style: TextStyle(fontSize: leader ? 18 : 15)),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.team.pct}%',
                    style: TextStyle(
                      color: const Color(0xFF0B1020),
                      fontSize: leader ? 15 : 13,
                      fontWeight: leader ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            // The pin tail.
            CustomPaint(
              size: const Size(12, 7),
              painter: _TailPainter(
                leader ? widget.accent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the downward triangle tail under a bubble.
class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color;
}
