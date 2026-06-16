import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// A flyable destination that also zooms in when tapped.
class _Place {
  const _Place(this.name, this.flag, this.lat, this.lng);
  final String name;
  final String flag;
  final double lat;
  final double lng;
}

/// Programmatic control. Tap a destination and the globe eases that coordinate
/// to face the viewer AND zooms in via [DotGlobeController.animateTo]; the live
/// readout tracks [DotGlobeController.facing] and [DotGlobeController.scale]
/// every frame. Pinch to zoom, drag to spin, use the +/− controls or reset.
class ControllerDemo extends StatefulWidget {
  const ControllerDemo({super.key, required this.paused});
  final bool paused;

  @override
  State<ControllerDemo> createState() => _ControllerDemoState();
}

class _ControllerDemoState extends State<ControllerDemo> {
  // Fly-to destinations — updated to the spec's five cities.
  static const List<_Place> _places = [
    _Place('Tokyo', '🇯🇵', 35.7, 139.7),
    _Place('London', '🇬🇧', 51.5, -0.1),
    _Place('New York', '🇺🇸', 40.7, -74.0),
    _Place('São Paulo', '🇧🇷', -23.5, -46.6),
    _Place('Sydney', '🇦🇺', -33.9, 151.2),
  ];

  // City markers shown on the globe so the viewer can see both scaling modes.
  static const List<DotGlobeMarker> _markers = [
    DotGlobeMarker(
      latitude: 35.7,
      longitude: 139.7,
      anchor: Alignment.bottomCenter,
      child: _CityDot(label: '🇯🇵'),
    ),
    DotGlobeMarker(
      latitude: 51.5,
      longitude: -0.1,
      anchor: Alignment.bottomCenter,
      child: _CityDot(label: '🇬🇧'),
    ),
    DotGlobeMarker(
      latitude: 40.7,
      longitude: -74.0,
      anchor: Alignment.bottomCenter,
      child: _CityDot(label: '🇺🇸'),
    ),
    DotGlobeMarker(
      latitude: -23.5,
      longitude: -46.6,
      anchor: Alignment.bottomCenter,
      child: _CityDot(label: '🇧🇷'),
    ),
    DotGlobeMarker(
      latitude: -33.9,
      longitude: 151.2,
      anchor: Alignment.bottomCenter,
      child: _CityDot(label: '🇦🇺'),
    ),
  ];

  static const DotGlobeStyle _style = DotGlobeStyle.emerald;

  // The zoom level each fly-to lands at.
  static const double _flyScale = 2.4;
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;

  final DotGlobeController _controller = DotGlobeController();

  DotGlobeFacing _facing = const DotGlobeFacing(0, 0);
  double _scale = 1.0;
  String? _target;
  bool _flying = false;
  bool _markersScaleWithZoom = true;
  // Park at the destination after a fly-to (vs. resume idle auto-rotation).
  bool _hold = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final f = _controller.facing;
    final s = _controller.scale;
    if (f == null) return;
    setState(() {
      _facing = f;
      if (s != null) _scale = s;
    });
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
      scale: _flyScale,
      hold: _hold, // stay parked on arrival, or resume auto-rotation
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    setState(() => _flying = false);
  }

  Future<void> _zoomIn() async {
    final current = _controller.scale ?? _scale;
    final next = (current + 0.5).clamp(_minScale, _maxScale);
    await _controller.zoomTo(next);
  }

  Future<void> _zoomOut() async {
    final current = _controller.scale ?? _scale;
    final next = (current - 0.5).clamp(_minScale, _maxScale);
    await _controller.zoomTo(next);
  }

  Future<void> _reset() async {
    setState(() {
      _target = null;
      _flying = false;
    });
    await _controller.resetView();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
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
              // Zoom parameters.
              initialScale: _minScale,
              minScale: _minScale,
              maxScale: _maxScale,
              zoomGesture: true,
              // Clip so the magnified globe stays inside its SizedBox.
              clipBehavior: Clip.hardEdge,
              markersScaleWithZoom: _markersScaleWithZoom,
              markers: _markers,
            ),
          );

          final panel = _ControlPanel(
            places: _places,
            accent: accent,
            facing: _facing,
            scale: _scale,
            target: _target,
            flying: _flying,
            markersScaleWithZoom: _markersScaleWithZoom,
            hold: _hold,
            onPick: _flyTo,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onReset: _reset,
            onMarkersScaleToggle: (v) => setState(() => _markersScaleWithZoom = v),
            onHoldToggle: (v) => setState(() => _hold = v),
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

// ---------------------------------------------------------------------------
// Control panel
// ---------------------------------------------------------------------------

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.places,
    required this.accent,
    required this.facing,
    required this.scale,
    required this.target,
    required this.flying,
    required this.markersScaleWithZoom,
    required this.hold,
    required this.onPick,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onMarkersScaleToggle,
    required this.onHoldToggle,
  });

  final List<_Place> places;
  final Color accent;
  final DotGlobeFacing facing;
  final double scale;
  final String? target;
  final bool flying;
  final bool markersScaleWithZoom;
  final bool hold;
  final ValueChanged<_Place> onPick;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final ValueChanged<bool> onMarkersScaleToggle;
  final ValueChanged<bool> onHoldToggle;

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
          // Live facing + zoom readout.
          _Readout(accent: accent, facing: facing, scale: scale, flying: flying),
          const SizedBox(height: 22),
          // ---- Fly-to city buttons ----
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
          const SizedBox(height: 22),
          // ---- Zoom controls ----
          Text('ZOOM', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 14),
          _ZoomRow(
            accent: accent,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onReset: onReset,
          ),
          const SizedBox(height: 22),
          // ---- On-arrival behaviour: stay parked vs resume spinning ----
          Text('ON ARRIVAL', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 14),
          Row(
            children: [
              _ToggleOption(
                label: 'Stay',
                selected: hold,
                accent: accent,
                onTap: () => onHoldToggle(true),
              ),
              const SizedBox(width: 10),
              _ToggleOption(
                label: 'Keep spinning',
                selected: !hold,
                accent: accent,
                onTap: () => onHoldToggle(false),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // ---- Marker scale toggle ----
          Text('MARKERS', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 14),
          _MarkerScaleToggle(
            accent: accent,
            scaleWithZoom: markersScaleWithZoom,
            onChanged: onMarkersScaleToggle,
          ),
          const SizedBox(height: 18),
          // ---- Caption ----
          Text(
            'Pinch to zoom, drag to spin, or tap a city to fly + zoom in. '
            '"Stay" parks the globe on arrival; "Keep spinning" resumes idle '
            'auto-rotation.',
            style: Kit.body(Kit.inkDim),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Readout — lat / lng / zoom
// ---------------------------------------------------------------------------

class _Readout extends StatelessWidget {
  const _Readout({
    required this.accent,
    required this.facing,
    required this.scale,
    required this.flying,
  });

  final Color accent;
  final DotGlobeFacing facing;
  final double scale;
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
          _Divider(accent: accent),
          _Axis(
            label: 'LNG',
            value: _fmt(facing.longitude, 'E', 'W'),
            accent: accent,
          ),
          _Divider(accent: accent),
          _Axis(
            label: 'ZOOM',
            value: '${scale.toStringAsFixed(1)}×',
            accent: accent,
          ),
          const Spacer(),
          // Pulsing dot while a flight is in progress.
          _StatusDot(active: flying, accent: accent),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: accent.withValues(alpha: 0.18),
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

// ---------------------------------------------------------------------------
// Zoom controls: +/− + Reset
// ---------------------------------------------------------------------------

class _ZoomRow extends StatelessWidget {
  const _ZoomRow({
    required this.accent,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final Color accent;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBtn(label: '−', accent: accent, onTap: onZoomOut),
        const SizedBox(width: 10),
        _IconBtn(label: '+', accent: accent, onTap: onZoomIn),
        const SizedBox(width: 16),
        Expanded(
          child: _TextBtn(label: 'Reset', accent: accent, onTap: onReset),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Kit.ink,
            fontSize: 20,
            fontWeight: FontWeight.w300,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
        ),
        child: Text(
          label,
          style: Kit.body(Kit.ink).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marker scale toggle
// ---------------------------------------------------------------------------

class _MarkerScaleToggle extends StatelessWidget {
  const _MarkerScaleToggle({
    required this.accent,
    required this.scaleWithZoom,
    required this.onChanged,
  });

  final Color accent;
  final bool scaleWithZoom;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleOption(
          label: 'Scale with zoom',
          selected: scaleWithZoom,
          accent: accent,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 10),
        _ToggleOption(
          label: 'Fixed size',
          selected: !scaleWithZoom,
          accent: accent,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: Kit.body(selected ? Kit.ink : Kit.inkDim)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status dot (pulsing while in-flight)
// ---------------------------------------------------------------------------

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.active, required this.accent});
  final bool active;
  final Color accent;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
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
          ? Tween<double>(begin: 0.3, end: 1.0).animate(_c)
          : const AlwaysStoppedAnimation(0.25),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: widget.active ? widget.accent : Kit.inkDim,
          shape: BoxShape.circle,
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.7),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Place chip
// ---------------------------------------------------------------------------

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
            width: active ? 1.4 : 1.0,
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

// ---------------------------------------------------------------------------
// City dot marker — a small flag badge shown on the globe
// ---------------------------------------------------------------------------

class _CityDot extends StatelessWidget {
  const _CityDot({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
