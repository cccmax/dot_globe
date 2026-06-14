import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

import 'demo_kit.dart';

/// One-line, ready-made palettes. A large hero globe re-tunes the whole page to
/// the selected preset, while a strip of live mini-globes lets you audition the
/// rest. This is the "open the box, it already looks good" pitch.
class PresetGalleryDemo extends StatefulWidget {
  const PresetGalleryDemo({super.key, required this.paused});
  final bool paused;

  @override
  State<PresetGalleryDemo> createState() => _PresetGalleryDemoState();
}

class _PresetGalleryDemoState extends State<PresetGalleryDemo> {
  static final List<MapEntry<String, DotGlobeStyle>> _entries =
      DotGlobeStyle.presets.entries.toList();

  String _selected = 'polymarket';

  DotGlobeStyle get _style => DotGlobeStyle.presets[_selected]!;

  @override
  Widget build(BuildContext context) {
    final accent = Kit.accentOf(_style);
    final bg = _style.backgroundColor ?? Kit.voidColor;
    final onDark = !Kit.isLight(_style);
    final ink = Kit.inkOn(_style);
    final inkDim = Kit.inkDimOn(_style);

    // The whole page cross-fades its palette when the preset changes.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      color: bg,
      child: Backdrop(
        background: bg,
        accent: accent,
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 720;
            final heroSize = wide
                ? (c.maxHeight * 0.72).clamp(320.0, 540.0)
                : c.maxWidth.clamp(280.0, 460.0);

            final hero = _Hero(
              styleName: _selected,
              style: _style,
              accent: accent,
              ink: ink,
              inkDim: inkDim,
              size: heroSize.toDouble(),
              paused: widget.paused,
            );

            final strip = _PresetStrip(
              entries: _entries,
              selected: _selected,
              accent: accent,
              ink: ink,
              inkDim: inkDim,
              paused: widget.paused,
              onPick: (name) => setState(() => _selected = name),
            );

            if (wide) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(40, 30, 40, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('${_entries.length} BUILT-IN PRESETS',
                        accent: accent, onDark: onDark),
                    const SizedBox(height: 14),
                    Text('Styled out of the box.',
                        style: Kit.display(ink, size: 34)),
                    const SizedBox(height: 24),
                    Expanded(child: Center(child: hero)),
                    const SizedBox(height: 20),
                    strip,
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('${_entries.length} BUILT-IN PRESETS',
                      accent: accent, onDark: onDark),
                  const SizedBox(height: 12),
                  Text('Styled out of the box.',
                      style: Kit.display(ink, size: 30)),
                  const SizedBox(height: 22),
                  Center(child: hero),
                  const SizedBox(height: 22),
                  strip,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.styleName,
    required this.style,
    required this.accent,
    required this.ink,
    required this.inkDim,
    required this.size,
    required this.paused,
  });

  final String styleName;
  final DotGlobeStyle style;
  final Color accent;
  final Color ink;
  final Color inkDim;
  final double size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          // Keyed so the new preset gets a fresh globe and animates cleanly.
          child: DotGlobe(
            key: ValueKey(styleName),
            style: style,
            paused: paused,
            autoRotateSpeed: 0.14,
            radiusFactor: 0.9,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DotGlobeStyle.',
              style: Kit.mono(inkDim, size: 15),
            ),
            Text(
              styleName,
              style: Kit.mono(accent, size: 15).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Horizontally scrolling strip of live mini-globes — every one is a real
/// [DotGlobe], so the palette differences are honest.
class _PresetStrip extends StatelessWidget {
  const _PresetStrip({
    required this.entries,
    required this.selected,
    required this.accent,
    required this.ink,
    required this.inkDim,
    required this.paused,
    required this.onPick,
  });

  final List<MapEntry<String, DotGlobeStyle>> entries;
  final String selected;
  final Color accent;
  final Color ink;
  final Color inkDim;
  final bool paused;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final e = entries[i];
          final isSel = e.key == selected;
          return _PresetCard(
            name: e.key,
            style: e.value,
            selected: isSel,
            accent: accent,
            ink: ink,
            inkDim: inkDim,
            // Pause off-screen-ish minis to keep the strip light; the selected
            // one always animates so the swatch feels alive.
            paused: paused && !isSel,
            onTap: () => onPick(e.key),
          );
        },
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.style,
    required this.selected,
    required this.accent,
    required this.ink,
    required this.inkDim,
    required this.paused,
    required this.onTap,
  });

  final String name;
  final DotGlobeStyle style;
  final bool selected;
  final Color accent;
  final Color ink;
  final Color inkDim;
  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardBg = style.backgroundColor ?? Kit.voidColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent
                : ink.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: cardBg,
            child: Column(
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: DotGlobe(
                      style: style,
                      interactive: false,
                      paused: paused,
                      autoRotateSpeed: selected ? 0.22 : 0.16,
                      radiusFactor: 0.82,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: selected
                          ? accent
                          : (Kit.isLight(style)
                              ? const Color(0xFF5B6276)
                              : Kit.inkDim),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
