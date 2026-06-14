import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// A named accent the user can paint the dots with via [DotGlobeStyle.copyWith].
class _Swatch {
  const _Swatch(this.name, this.dot, this.glow);
  final String name;
  final Color dot;
  final Color glow;
}

/// Hands-on parameter lab. Every knob maps to a real [DotGlobe] /
/// [DotGlobeStyle] property so the reader can feel each one. Sliders for the
/// continuous params, toggles for the booleans, swatches for live recolouring.
class PlaygroundDemo extends StatefulWidget {
  const PlaygroundDemo({super.key, required this.paused});
  final bool paused;

  @override
  State<PlaygroundDemo> createState() => _PlaygroundDemoState();
}

class _PlaygroundDemoState extends State<PlaygroundDemo> {
  static const List<_Swatch> _swatches = [
    _Swatch('Blue', Color(0xFF4E6BF5), Color(0xFF3358FF)),
    _Swatch('Cyan', Color(0xFF2EF2E0), Color(0xFF12D6E8)),
    _Swatch('Amber', Color(0xFFFFB24C), Color(0xFFFF6A3D)),
    _Swatch('Magenta', Color(0xFFFF5FD1), Color(0xFFFF2BD6)),
    _Swatch('Mint', Color(0xFF34D9A4), Color(0xFF14B88A)),
    _Swatch('Snow', Color(0xFFF2F2F2), Color(0xFF9FB2FF)),
  ];

  // Live DotGlobe params.
  double _dotRadius = 1.5;
  double _autoRotate = 0.16;
  double _dragSensitivity = 1.0;
  double _maxTilt = 0.6;
  double _depthFade = 0.6;
  bool _sphereLight = true;
  bool _interactive = true;
  bool _selfPaused = false;
  int _swatch = 1; // cyan

  // Live arc params (a single Tokyo -> New York demo arc).
  bool _showArc = true;
  double _arcAltitude = 0.4;
  double _arcBackOpacity = 0.38;
  bool _arcDashed = false;
  bool _arcBackDashed = true;

  DotGlobeStyle get _style {
    final s = _swatches[_swatch];
    return DotGlobeStyle(
      dotColor: s.dot,
      sphereColor: const Color(0x59101B45),
      glowColor: s.glow,
      sphereLight: _sphereLight,
      depthFade: _depthFade,
      dotRadius: _dotRadius,
      backgroundColor: const Color(0xFF080C1C),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _swatches[_swatch].glow;
    final bg = _style.backgroundColor ?? Kit.voidColor;

    return Backdrop(
      background: bg,
      accent: accent,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 760;
          final globeSize = wide
              ? (c.maxHeight * 0.8).clamp(300.0, 540.0)
              : c.maxWidth.clamp(260.0, 420.0);

          final globe = SizedBox.square(
            dimension: globeSize.toDouble(),
            child: DotGlobe(
              // Param changes apply via didUpdateWidget — no key churn needed,
              // except interactive/paused which the widget handles internally.
              style: _style,
              paused: widget.paused || _selfPaused,
              interactive: _interactive,
              autoRotateSpeed: _autoRotate,
              dragSensitivity: _dragSensitivity,
              maxTilt: _maxTilt,
              // Shrink the globe while an arc is shown so a tall bow stays in
              // bounds; full size otherwise.
              radiusFactor: _showArc ? 0.56 : 0.9,
              arcs: _showArc
                  ? [
                      DotGlobeArc(
                        startLatitude: 35.7,
                        startLongitude: 139.7,
                        endLatitude: 40.7,
                        endLongitude: -74.0,
                        color: _swatches[_swatch].glow,
                        width: 2.5,
                        altitude: _arcAltitude,
                        dashed: _arcDashed,
                        backDashed: _arcBackDashed,
                        backOpacity: _arcBackOpacity,
                      ),
                    ]
                  : const [],
            ),
          );

          final controls = _Controls(
            accent: accent,
            dotRadius: _dotRadius,
            autoRotate: _autoRotate,
            dragSensitivity: _dragSensitivity,
            maxTilt: _maxTilt,
            depthFade: _depthFade,
            sphereLight: _sphereLight,
            interactive: _interactive,
            paused: _selfPaused,
            swatches: _swatches,
            swatch: _swatch,
            showArc: _showArc,
            arcAltitude: _arcAltitude,
            arcBackOpacity: _arcBackOpacity,
            arcDashed: _arcDashed,
            arcBackDashed: _arcBackDashed,
            onDotRadius: (v) => setState(() => _dotRadius = v),
            onAutoRotate: (v) => setState(() => _autoRotate = v),
            onDrag: (v) => setState(() => _dragSensitivity = v),
            onTilt: (v) => setState(() => _maxTilt = v),
            onDepth: (v) => setState(() => _depthFade = v),
            onSphereLight: (v) => setState(() => _sphereLight = v),
            onInteractive: (v) => setState(() => _interactive = v),
            onPaused: (v) => setState(() => _selfPaused = v),
            onSwatch: (i) => setState(() => _swatch = i),
            onShowArc: (v) => setState(() => _showArc = v),
            onArcAltitude: (v) => setState(() => _arcAltitude = v),
            onArcBackOpacity: (v) => setState(() => _arcBackOpacity = v),
            onArcDashed: (v) => setState(() => _arcDashed = v),
            onArcBackDashed: (v) => setState(() => _arcBackDashed = v),
          );

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: Center(child: globe)),
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 360,
                    child: SingleChildScrollView(child: controls),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
            child: Column(
              children: [
                Center(child: globe),
                const SizedBox(height: 20),
                controls,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.accent,
    required this.dotRadius,
    required this.autoRotate,
    required this.dragSensitivity,
    required this.maxTilt,
    required this.depthFade,
    required this.sphereLight,
    required this.interactive,
    required this.paused,
    required this.swatches,
    required this.swatch,
    required this.showArc,
    required this.arcAltitude,
    required this.arcBackOpacity,
    required this.arcDashed,
    required this.arcBackDashed,
    required this.onDotRadius,
    required this.onAutoRotate,
    required this.onDrag,
    required this.onTilt,
    required this.onDepth,
    required this.onSphereLight,
    required this.onInteractive,
    required this.onPaused,
    required this.onSwatch,
    required this.onShowArc,
    required this.onArcAltitude,
    required this.onArcBackOpacity,
    required this.onArcDashed,
    required this.onArcBackDashed,
  });

  final Color accent;
  final double dotRadius;
  final double autoRotate;
  final double dragSensitivity;
  final double maxTilt;
  final double depthFade;
  final bool sphereLight;
  final bool interactive;
  final bool paused;
  final List<_Swatch> swatches;
  final int swatch;
  final bool showArc;
  final double arcAltitude;
  final double arcBackOpacity;
  final bool arcDashed;
  final bool arcBackDashed;

  final ValueChanged<double> onDotRadius;
  final ValueChanged<double> onAutoRotate;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onTilt;
  final ValueChanged<double> onDepth;
  final ValueChanged<bool> onSphereLight;
  final ValueChanged<bool> onInteractive;
  final ValueChanged<bool> onPaused;
  final ValueChanged<int> onSwatch;
  final ValueChanged<bool> onShowArc;
  final ValueChanged<double> onArcAltitude;
  final ValueChanged<double> onArcBackOpacity;
  final ValueChanged<bool> onArcDashed;
  final ValueChanged<bool> onArcBackDashed;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('PLAYGROUND', accent: accent, onDark: true),
          const SizedBox(height: 18),
          _SliderRow(
            label: 'dotRadius',
            value: dotRadius,
            min: 0.6,
            max: 3.0,
            accent: accent,
            onChanged: onDotRadius,
          ),
          _SliderRow(
            label: 'autoRotateSpeed',
            value: autoRotate,
            min: 0.0,
            max: 0.6,
            accent: accent,
            onChanged: onAutoRotate,
          ),
          _SliderRow(
            label: 'dragSensitivity',
            value: dragSensitivity,
            min: 0.3,
            max: 2.5,
            accent: accent,
            onChanged: onDrag,
          ),
          _SliderRow(
            label: 'maxTilt',
            value: maxTilt,
            min: 0.0,
            max: 1.2,
            accent: accent,
            onChanged: onTilt,
          ),
          _SliderRow(
            label: 'depthFade',
            value: depthFade,
            min: 0.0,
            max: 1.0,
            accent: accent,
            onChanged: onDepth,
          ),
          const SizedBox(height: 6),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 24),
          _ToggleRow(
            label: 'sphereLight',
            value: sphereLight,
            accent: accent,
            onChanged: onSphereLight,
          ),
          _ToggleRow(
            label: 'interactive',
            value: interactive,
            accent: accent,
            onChanged: onInteractive,
          ),
          _ToggleRow(
            label: 'paused',
            value: paused,
            accent: accent,
            onChanged: onPaused,
          ),
          const SizedBox(height: 18),
          Text('DOT COLOUR', style: Kit.label(Kit.inkDim)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < swatches.length; i++)
                _SwatchDot(
                  swatch: swatches[i],
                  selected: i == swatch,
                  onTap: () => onSwatch(i),
                ),
            ],
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 28),
          Row(
            children: [
              Eyebrow('ARC · Tokyo → New York', accent: accent, onDark: true),
            ],
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            label: 'show arc',
            value: showArc,
            accent: accent,
            onChanged: onShowArc,
          ),
          if (showArc) ...[
            _SliderRow(
              label: 'altitude',
              value: arcAltitude,
              min: 0.0,
              max: 0.8,
              accent: accent,
              onChanged: onArcAltitude,
            ),
            _SliderRow(
              label: 'backOpacity',
              value: arcBackOpacity,
              min: 0.0,
              max: 1.0,
              accent: accent,
              onChanged: onArcBackOpacity,
            ),
            _ToggleRow(
              label: 'dashed (front)',
              value: arcDashed,
              accent: accent,
              onChanged: onArcDashed,
            ),
            _ToggleRow(
              label: 'backDashed',
              value: arcBackDashed,
              accent: accent,
              onChanged: onArcBackDashed,
            ),
          ],
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Kit.mono(Kit.ink, size: 12.5)),
            Text(value.toStringAsFixed(2), style: Kit.mono(accent, size: 12.5)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.18),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Kit.mono(Kit.ink, size: 12.5)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
            inactiveThumbColor: Kit.inkDim,
          ),
        ],
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final _Swatch swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: swatch.dot,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2.4,
          ),
          boxShadow: selected
              ? [BoxShadow(color: swatch.glow.withValues(alpha: 0.7), blurRadius: 14)]
              : null,
        ),
      ),
    );
  }
}
