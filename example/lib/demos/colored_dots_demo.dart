import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_geometries.dart';
import 'demo_kit.dart';

/// Demonstrates per-dot colouring on the built-in Earth cloud.
///
/// Two modes:
///
/// - "Heatmap" — builds a List[double] of length base.pointCount from a
///   smooth sinusoidal field over each dot's lat/lng, then calls
///   `base.colorizeByValues(values, colormap: cm)` to colour the cloud.
///   The colormap can be swapped live via the chip row below.
/// - "Regions" — calls `base.colorize((lat, lng, i) { … })` to paint dots
///   by a latitude-band / hemisphere rule into four distinct colours.
///
/// Both API surfaces are shown: colorizeByValues is the go-to when you already
/// hold a per-dot value array (e.g. temperature, density); colorize is cleaner
/// when the colour derives from a direct lat/lng rule.
///
/// The same geometry.colorizeFromImage / colorizedFromImageProvider API lets
/// you sample a satellite image or weather raster in the same way.
class ColoredDotsDemo extends StatefulWidget {
  const ColoredDotsDemo({super.key, required this.paused});

  final bool paused;

  @override
  State<ColoredDotsDemo> createState() => _ColoredDotsDemoState();
}

// ── Mode ───────────────────────────────────────────────────────────────────

enum _ColourMode { natural, heatmap, regions }

// ── Colormap descriptor ────────────────────────────────────────────────────

class _ColormapOption {
  const _ColormapOption(this.label, this.colormap, this.accent);
  final String label;
  final DotGlobeColormap colormap;
  final Color accent; // UI tint for the chip and glow
}

// ── State ──────────────────────────────────────────────────────────────────

class _ColoredDotsDemoState extends State<ColoredDotsDemo> {
  // Loading
  DotGlobeGeometry? _base;
  bool _loading = true;

  // Control state
  _ColourMode _mode = _ColourMode.natural;
  int _colormapIndex = 0;

  // Coloured geometry cache — recomputed only when mode/colormap changes.
  DotGlobeGeometry? _coloured;

  // The bundled natural-colour Earth (loaded once, async).
  DotGlobeGeometry? _natural;

  static final List<_ColormapOption> _colormaps = [
    _ColormapOption('viridis', DotGlobeColormap.viridis, const Color(0xFF35B779)),
    _ColormapOption('turbo', DotGlobeColormap.turbo, const Color(0xFF39A2FC)),
    _ColormapOption('heat', DotGlobeColormap.heat, const Color(0xFFFF8C00)),
    _ColormapOption('cool', DotGlobeColormap.cool, const Color(0xFF00FFFF)),
    _ColormapOption('grayscale', DotGlobeColormap.grayscale, const Color(0xFFAAAAAA)),
  ];

  @override
  void initState() {
    super.initState();
    _loadBase();
  }

  Future<void> _loadBase() async {
    // naturalEarth() loads the base cloud internally, then the base load() is a
    // cached no-op — so both resolve with no flash of uncoloured dots.
    final natural = await DotGlobeGeometry.naturalEarth();
    final base = await DotGlobeGeometry.load();
    if (!mounted) return;
    setState(() {
      _base = base;
      _natural = natural;
      _loading = false;
      _coloured = _buildColoured(base);
    });
  }

  // Returns a freshly coloured geometry for the current mode/colormap.
  DotGlobeGeometry _buildColoured(DotGlobeGeometry base) {
    switch (_mode) {
      case _ColourMode.natural:
        return _natural ?? base; // base (uncoloured) until the colours load
      case _ColourMode.heatmap:
        return _buildHeatmap(base);
      case _ColourMode.regions:
        return _buildRegions(base);
    }
  }

  // ── Heatmap ──────────────────────────────────────────────────────────────
  //
  // Demonstrates colorizeByValues: we build a List<double> of length
  // base.pointCount where each value is a smooth sinusoidal field evaluated at
  // the dot's lat/lng, then hand it to colorizeByValues along with the chosen
  // colormap. The API normalises to [min, max] internally and maps to colours.
  DotGlobeGeometry _buildHeatmap(DotGlobeGeometry base) {
    // Delegates to the shared pure generator (see demo_geometries.dart) so the
    // capture test renders the identical heatmap cloud.
    final cm = _colormaps[_colormapIndex].colormap;
    return buildHeatmapGeometry(base, cm);
  }

  // ── Regions ───────────────────────────────────────────────────────────────
  //
  // Demonstrates colorize: a pure lat/lng rule assigns each dot to one of
  // four colour zones (polar, temperate north, tropical, temperate south).
  // No colormap needed — the callback returns a literal ARGB int per dot.
  DotGlobeGeometry _buildRegions(DotGlobeGeometry base) {
    return base.colorize((lat, lng, _) {
      if (lat > 60) {
        // Arctic — icy blue
        return const Color(0xFF7ECFFF).toARGB32();
      } else if (lat > 23.5) {
        // North temperate — warm amber
        return const Color(0xFFFFC14A).toARGB32();
      } else if (lat > -23.5) {
        // Tropical — vivid green
        return const Color(0xFF3EE89A).toARGB32();
      } else if (lat > -60) {
        // South temperate — soft violet
        return const Color(0xFFB07EFF).toARGB32();
      } else {
        // Antarctic — pale steel
        return const Color(0xFF9BB8D4).toARGB32();
      }
    });
  }

  // ── Change handlers ───────────────────────────────────────────────────────

  void _setMode(_ColourMode mode) {
    if (_mode == mode) return;
    final base = _base;
    if (base == null) return;
    setState(() {
      _mode = mode;
      _coloured = _buildColoured(base);
    });
  }

  void _setColormapIndex(int i) {
    if (_colormapIndex == i) return;
    final base = _base;
    if (base == null) return;
    setState(() {
      _colormapIndex = i;
      if (_mode == _ColourMode.heatmap) {
        _coloured = _buildColoured(base);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cm = _colormaps[_colormapIndex];
    final accent = switch (_mode) {
      _ColourMode.natural => const Color(0xFF5BC8A0),
      _ColourMode.heatmap => cm.accent,
      _ColourMode.regions => const Color(0xFF3EE89A),
    };
    const bg = Kit.voidColor;

    return Backdrop(
      background: bg,
      accent: accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 680;
          final globeSize = wide
              ? (constraints.maxHeight * 0.65).clamp(280.0, 480.0)
              : constraints.maxWidth.clamp(240.0, 400.0);

          final globeSection = _GlobeSection(
            coloured: _coloured,
            loading: _loading,
            size: globeSize,
            accent: accent,
            paused: widget.paused,
            mode: _mode,
            base: _base,
          );

          final controls = _ControlPanel(
            accent: accent,
            mode: _mode,
            colormapIndex: _colormapIndex,
            colormaps: _colormaps,
            onModeChanged: _setMode,
            onColormapChanged: _setColormapIndex,
          );

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    'PER-DOT COLOUR  ·  colorize / colorizeByValues',
                    accent: accent,
                    onDark: true,
                  ),
                  const SizedBox(height: 12),
                  Text('Data globe.', style: Kit.display(Kit.ink)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: globeSection),
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
                Eyebrow(
                  'PER-DOT COLOUR  ·  colorize / colorizeByValues',
                  accent: accent,
                  onDark: true,
                ),
                const SizedBox(height: 10),
                Text('Data globe.', style: Kit.display(Kit.ink, size: 28)),
                const SizedBox(height: 20),
                Center(child: globeSection),
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

// ── Globe section ──────────────────────────────────────────────────────────

class _GlobeSection extends StatelessWidget {
  const _GlobeSection({
    required this.coloured,
    required this.loading,
    required this.size,
    required this.accent,
    required this.paused,
    required this.mode,
    required this.base,
  });

  final DotGlobeGeometry? coloured;
  final DotGlobeGeometry? base;
  final bool loading;
  final double size;
  final Color accent;
  final bool paused;
  final _ColourMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 1.5,
                  ),
                )
              : DotGlobe(
                  // Re-key when the geometry changes so the widget initialises cleanly.
                  key: ValueKey(coloured),
                  geometry: coloured,
                  style: const DotGlobeStyle(
                    backgroundColor: Kit.voidColor,
                    dotColor: Color(0xFF334466), // fallback, overridden by per-dot colours
                    sphereColor: Color(0x331A2A4A),
                    dotRadius: 1.8,
                  ),
                  paused: paused,
                  autoRotateSpeed: 0.10,
                  zoomGesture: true,
                  radiusFactor: 0.88,
                ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            loading
                ? 'Loading Earth cloud…'
                : switch (mode) {
                    _ColourMode.natural =>
                      'DotGlobeGeometry.naturalEarth()  ·  ${base?.pointCount ?? 0} dots',
                    _ColourMode.heatmap =>
                      'colorizeByValues(values, colormap: …)  ·  ${base?.pointCount ?? 0} dots',
                    _ColourMode.regions =>
                      'colorize((lat, lng, i) { … })  ·  ${base?.pointCount ?? 0} dots',
                  },
            key: ValueKey('$loading$mode'),
            style: Kit.mono(loading ? Kit.inkDim : accent, size: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── Control panel ──────────────────────────────────────────────────────────

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.accent,
    required this.mode,
    required this.colormapIndex,
    required this.colormaps,
    required this.onModeChanged,
    required this.onColormapChanged,
  });

  final Color accent;
  final _ColourMode mode;
  final int colormapIndex;
  final List<_ColormapOption> colormaps;
  final ValueChanged<_ColourMode> onModeChanged;
  final ValueChanged<int> onColormapChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mode toggle ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Colour mode', style: Kit.label(Kit.inkDim)),
                    const SizedBox(height: 6),
                    Text(
                      switch (mode) {
                        _ColourMode.natural => 'Natural — satellite colours',
                        _ColourMode.heatmap => 'Heatmap — value → colormap',
                        _ColourMode.regions => 'Regions — lat/lng rule',
                      },
                      style: Kit.title(Kit.ink),
                    ),
                  ],
                ),
              ),
              SegmentedButton<_ColourMode>(
                segments: const [
                  ButtonSegment(
                    value: _ColourMode.natural,
                    label: Text('Natural'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: _ColourMode.heatmap,
                    label: Text('Heatmap'),
                    icon: Icon(Icons.gradient),
                  ),
                  ButtonSegment(
                    value: _ColourMode.regions,
                    label: Text('Regions'),
                    icon: Icon(Icons.layers_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
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

          // ── Colormap picker (visible in Heatmap mode only) ─────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: mode == _ColourMode.heatmap
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Colormap', style: Kit.label(Kit.inkDim)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < colormaps.length; i++)
                              _ColormapChip(
                                option: colormaps[i],
                                selected: i == colormapIndex,
                                onTap: () => onColormapChanged(i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 18),

          // ── Caption ────────────────────────────────────────────────────
          Text(
            switch (mode) {
              _ColourMode.natural =>
                'naturalEarth() ships a tiny baked colour per dot — sampled '
                    'offline from NASA Blue Marble: tan deserts, green forests, '
                    'white ice, blue water. One call, real Earth, zero setup.',
              _ColourMode.heatmap =>
                'colorizeByValues builds a per-dot value array from a '
                    'sinusoidal field over each dot\'s lat/lng, then maps it '
                    'through the chosen DotGlobeColormap ramp. Swap the '
                    'colormap to recolour instantly.',
              _ColourMode.regions =>
                'colorize assigns each dot to a latitude band with a direct '
                    'rule — Arctic, North Temperate, Tropical, South Temperate, '
                    'Antarctic. Any colour per dot, no ramp required.',
            },
            style: Kit.body(Kit.inkDim),
          ),
          const SizedBox(height: 16),

          // ── API snippet ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Text(
              switch (mode) {
                _ColourMode.natural => '// bundled natural-colour Earth\n'
                    'final earth = await DotGlobeGeometry.naturalEarth();\n'
                    'DotGlobe(geometry: earth)',
                _ColourMode.heatmap => '// colorizeByValues: value array → colormap\n'
                    'final values = List<double>.filled(base.pointCount, 0);\n'
                    '// ... fill values from your data ...\n'
                    'final geo = base.colorizeByValues(\n'
                    '  values, colormap: DotGlobeColormap.viridis,\n'
                    ');\n'
                    'DotGlobe(geometry: geo)',
                _ColourMode.regions => '// colorize: lat/lng rule → ARGB int per dot\n'
                    'final geo = base.colorize((lat, lng, i) {\n'
                    '  if (lat > 60) return Color(0xFF7ECFFF).toARGB32();\n'
                    '  if (lat > 23.5) return Color(0xFFFFC14A).toARGB32();\n'
                    '  return Color(0xFF3EE89A).toARGB32(); // tropical\n'
                    '});\n'
                    'DotGlobe(geometry: geo)',
              },
              style: Kit.mono(accent, size: 11.5),
            ),
          ),

          const SizedBox(height: 14),

          // ── Footnote ───────────────────────────────────────────────────
          Text(
            'Every dot carries its own colour — fed here from a value → '
            'DotGlobeColormap ramp or a lat/lng rule. The same API samples a '
            'satellite image or weather map via '
            'geometry.colorizeFromImage / colorizedFromImageProvider.',
            style: Kit.body(Kit.inkDim).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Colormap chip ──────────────────────────────────────────────────────────

class _ColormapChip extends StatelessWidget {
  const _ColormapChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ColormapOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = option.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Kit.inkDim.withValues(alpha: 0.28),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Text(
          option.label,
          style: TextStyle(
            color: selected ? accent : Kit.inkDim,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
