import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// A flyable destination.
class _Place {
  const _Place(this.name, this.flag, this.lat, this.lng);
  final String name;
  final String flag;
  final double lat;
  final double lng;
}

/// Programmatic control. Tap a destination and the globe eases that coordinate
/// to face the viewer via [DotGlobeController.animateTo]; the live readout
/// tracks [DotGlobeController.facing] every frame.
class ControllerDemo extends StatefulWidget {
  const ControllerDemo({super.key, required this.paused});
  final bool paused;

  @override
  State<ControllerDemo> createState() => _ControllerDemoState();
}

class _ControllerDemoState extends State<ControllerDemo> {
  static const List<_Place> _places = [
    _Place('Paris', '🇫🇷', 46, 2),
    _Place('São Paulo', '🇧🇷', -23, -47),
    _Place('Tokyo', '🇯🇵', 36, 138),
    _Place('New York', '🇺🇸', 41, -74),
    _Place('Cape Town', '🇿🇦', -34, 18),
  ];

  static const DotGlobeStyle _style = DotGlobeStyle.emerald;

  final DotGlobeController _controller = DotGlobeController();

  DotGlobeFacing _facing = const DotGlobeFacing(0, 0);
  String? _target;
  bool _flying = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onFacingChanged);
  }

  void _onFacingChanged() {
    if (!mounted) return;
    final f = _controller.facing;
    if (f == null) return;
    setState(() => _facing = f);
  }

  Future<void> _flyTo(_Place place) async {
    if (_flying) return; // re-entrancy guard: ignore taps mid-flight
    setState(() {
      _flying = true;
      _target = place.name;
    });
    await _controller.animateTo(
      latitude: place.lat,
      longitude: place.lng,
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    setState(() => _flying = false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onFacingChanged);
    _controller.dispose();
    super.dispose();
  }

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
              ? (c.maxHeight * 0.78).clamp(320.0, 560.0)
              : c.maxWidth.clamp(280.0, 460.0);

          final globe = SizedBox.square(
            dimension: globeSize.toDouble(),
            child: DotGlobe(
              style: _style,
              controller: _controller,
              paused: widget.paused,
              autoRotateSpeed: 0.05,
              radiusFactor: 0.9,
            ),
          );

          final panel = _ControlPanel(
            places: _places,
            accent: accent,
            facing: _facing,
            target: _target,
            flying: _flying,
            onPick: _flyTo,
          );

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Center(child: globe)),
                  const SizedBox(width: 28),
                  Expanded(
                    flex: 4,
                    // Centred when it fits, scrollable on short windows.
                    child: SingleChildScrollView(
                      child: Center(child: panel),
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: Column(
              children: [
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

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.places,
    required this.accent,
    required this.facing,
    required this.target,
    required this.flying,
    required this.onPick,
  });

  final List<_Place> places;
  final Color accent;
  final DotGlobeFacing facing;
  final String? target;
  final bool flying;
  final ValueChanged<_Place> onPick;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('IMPERATIVE CONTROL', accent: accent, onDark: true),
          const SizedBox(height: 18),
          // The live facing readout.
          _Readout(accent: accent, facing: facing, flying: flying),
          const SizedBox(height: 22),
          Text('FLY TO', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in places)
                _PlaceChip(
                  place: p,
                  accent: accent,
                  active: target == p.name,
                  onTap: () => onPick(p),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'controller.animateTo(latitude, longitude) eases the shortest path; '
            'facing updates on every frame.',
            style: Kit.body(Kit.inkDim),
          ),
        ],
      ),
    );
  }
}

/// The big coordinate readout — the centerpiece of this page.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.accent,
    required this.facing,
    required this.flying,
  });

  final Color accent;
  final DotGlobeFacing facing;
  final bool flying;

  String _fmt(double v, String pos, String neg) {
    final hemi = v >= 0 ? pos : neg;
    return '${v.abs().toStringAsFixed(1)}° $hemi';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _Axis(
            label: 'LAT',
            value: _fmt(facing.latitude, 'N', 'S'),
            accent: accent,
          ),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            color: accent.withValues(alpha: 0.18),
          ),
          _Axis(
            label: 'LNG',
            value: _fmt(facing.longitude, 'E', 'W'),
            accent: accent,
          ),
          const Spacer(),
          // A pulsing dot while a flight is in progress.
          _StatusDot(active: flying, accent: accent),
        ],
      ),
    );
  }
}

class _Axis extends StatelessWidget {
  const _Axis({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Kit.label(Kit.inkDim)),
        const SizedBox(height: 8),
        Text(value, style: Kit.mono(Kit.ink, size: 17)),
      ],
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.active, required this.accent});
  final bool active;
  final Color accent;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  // Built in initState (not a late-final field) so the ticker is created while
  // the element is active — a late-final would otherwise initialise inside
  // dispose() if the widget is torn down before its first build.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.active
          ? Tween(begin: 0.3, end: 1.0).animate(_c)
          : const AlwaysStoppedAnimation(0.25),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: widget.active ? widget.accent : Kit.inkDim,
          shape: BoxShape.circle,
          boxShadow: widget.active
              ? [BoxShadow(color: widget.accent.withValues(alpha: 0.7), blurRadius: 8)]
              : null,
        ),
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    required this.place,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  final _Place place;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? accent : Colors.white.withValues(alpha: 0.10),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(place.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              place.name,
              style: Kit.body(active ? Kit.ink : Kit.inkDim)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
