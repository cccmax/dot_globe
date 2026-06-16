import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_geometries.dart';
import 'demo_kit.dart';

/// Demonstrates [DotGlobeGeometry.fromLatLng]: rasterises a word into a dot
/// cloud (a tiny 5x7 bitmap font) in pure Dart and toggles between it and the
/// built-in Earth.
///
/// Custom clouds are pure lat/lng → [DotGlobeGeometry.fromLatLng]; switch back
/// to the bundled Earth by passing `geometry: null`.
class CustomDataDemo extends StatefulWidget {
  const CustomDataDemo({super.key, required this.paused});

  final bool paused;

  @override
  State<CustomDataDemo> createState() => _CustomDataDemoState();
}

class _CustomDataDemoState extends State<CustomDataDemo> {
  // The word painted onto the sphere. Every letter it uses must exist in
  // [_font] below — extend the map to spell anything else (e.g. 'FLUTTER').
  static const String _word = 'DART';

  // Built once — geometry construction is O(n) but synchronous, so initState
  // is fine and we never pay for it on rebuild.
  late final DotGlobeGeometry _textGeometry;

  bool _useCustom = false;

  // Neon preset: deep dark background, vivid cyan glow — reads great for both
  // the Earth and a glowing word.
  static const DotGlobeStyle _style = DotGlobeStyle.neon;

  @override
  void initState() {
    super.initState();
    // Geometry built from the shared pure generator (see demo_geometries.dart),
    // reused by the screenshot capture test for the same on-screen result.
    _textGeometry = buildDartTextGeometry(_word);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF12D6E8); // neon cyan
    const bg = Color(0xFF070B18);

    return Backdrop(
      background: bg,
      accent: accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 680;
          final globeSize = wide
              ? (constraints.maxHeight * 0.68).clamp(280.0, 500.0)
              : constraints.maxWidth.clamp(240.0, 420.0);

          final globe = _GlobeSection(
            useCustom: _useCustom,
            customGeometry: _textGeometry,
            style: _style,
            size: globeSize,
            paused: widget.paused,
          );

          final controls = _ControlPanel(
            accent: accent,
            word: _word,
            useCustom: _useCustom,
            onToggle: (v) => setState(() => _useCustom = v),
          );

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow(
                    'CUSTOM DATA · fromLatLng',
                    accent: accent,
                    onDark: true,
                  ),
                  const SizedBox(height: 12),
                  Text('Your data, your shape.', style: Kit.display(Kit.ink)),
                  const SizedBox(height: 24),
                  // scaleDown so the globe + caption never overflow the
                  // Expanded when the available height is tight.
                  Expanded(
                    child: Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: globe),
                    ),
                  ),
                  const SizedBox(height: 20),
                  controls,
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow(
                  'CUSTOM DATA · fromLatLng',
                  accent: accent,
                  onDark: true,
                ),
                const SizedBox(height: 10),
                Text('Your data, your shape.',
                    style: Kit.display(Kit.ink, size: 28)),
                const SizedBox(height: 20),
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

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _GlobeSection extends StatelessWidget {
  const _GlobeSection({
    required this.useCustom,
    required this.customGeometry,
    required this.style,
    required this.size,
    required this.paused,
  });

  final bool useCustom;
  final DotGlobeGeometry customGeometry;
  final DotGlobeStyle style;
  final double size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          // Key on the mode so DotGlobe resets its internal geometry + facing
          // cleanly when switching between Earth and the custom cloud.
          child: DotGlobe(
            key: ValueKey(useCustom),
            style: style,
            geometry: useCustom ? customGeometry : null,
            paused: paused,
            // The word reads face-on, so hold it still (still draggable); the
            // Earth keeps its idle spin.
            autoRotateSpeed: useCustom ? 0.0 : 0.10,
            radiusFactor: 0.88,
            initialLatitude: 0,
            initialLongitude: 0,
            // Two markers visible only in Earth mode to show they still project.
            markers: useCustom
                ? const []
                : const [
                    DotGlobeMarker(
                      latitude: 51.5,
                      longitude: -0.1,
                      child: _PinLabel('London'),
                    ),
                    DotGlobeMarker(
                      latitude: 40.7,
                      longitude: -74.0,
                      child: _PinLabel('New York'),
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            useCustom
                ? 'geometry: DotGlobeGeometry.fromLatLng(…)   •   '
                    '${customGeometry.pointCount} pts'
                : 'geometry: null   →   built-in Earth (~6 300 pts)',
            key: ValueKey(useCustom),
            style: Kit.mono(
              useCustom ? const Color(0xFF12D6E8) : Kit.inkDim,
              size: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.accent,
    required this.word,
    required this.useCustom,
    required this.onToggle,
  });

  final Color accent;
  final String word;
  final bool useCustom;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data source', style: Kit.label(Kit.inkDim)),
                    const SizedBox(height: 6),
                    Text(
                      useCustom ? '"$word" — text (custom)' : 'Earth (built-in)',
                      style: Kit.title(Kit.ink),
                    ),
                  ],
                ),
              ),
              // SegmentedButton for a clean two-option switch.
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Earth'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Text'),
                    icon: Icon(Icons.text_fields),
                  ),
                ],
                selected: {useCustom},
                onSelectionChanged: (s) => onToggle(s.first),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? accent
                        : Kit.inkDim,
                  ),
                  iconColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? accent
                        : Kit.inkDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ── Caption ───────────────────────────────────────────────────
          Text(
            'The word is rasterised from a 5×7 bitmap font into lat/lng points '
            'and fed to DotGlobeGeometry.fromLatLng — no assets, no JSON, no '
            'network. Switch back to the bundled Earth by passing geometry: '
            'null. Drag to spin the sphere either way.',
            style: Kit.body(Kit.inkDim),
          ),
          const SizedBox(height: 14),
          // ── API hint ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Text(
              'DotGlobe(\n'
              '  geometry: useCustom\n'
              '    ? DotGlobeGeometry.fromLatLng(points)\n'
              '    : null,   // ← null = built-in Earth\n'
              ')',
              style: Kit.mono(accent, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny label pin used as a [DotGlobeMarker] child in Earth mode.
class _PinLabel extends StatelessWidget {
  const _PinLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1426).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: const Color(0xFF12D6E8).withValues(alpha: 0.55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3312D6E8),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF12D6E8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
