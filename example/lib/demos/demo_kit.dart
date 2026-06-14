import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

/// Shared visual primitives for the showcase — a small design system so every
/// demo page reads as one product. Built from weight, tracking and spacing
/// alone (no extra font dependencies), for an "instrument panel" feel that
/// tunes itself to whichever [DotGlobeStyle] is on screen.
class Kit {
  Kit._();

  /// Page chrome base — deep space navy the per-preset tint blends over.
  static const Color voidColor = Color(0xFF070B18);

  /// A muted ink for body copy on dark chrome.
  static const Color ink = Color(0xFFE7ECF7);

  /// A dimmer ink for secondary copy / labels.
  static const Color inkDim = Color(0xFF8A93AD);

  /// The accent for a style — its glow if it has one, else its dot colour.
  /// This is what welds the UI chrome to the globe on screen.
  static Color accentOf(DotGlobeStyle style) =>
      style.glowColor ?? style.dotColor;

  /// Whether a preset's background is light enough to need dark-on-light text.
  static bool isLight(DotGlobeStyle style) {
    final bg = style.backgroundColor ?? voidColor;
    return bg.computeLuminance() > 0.5;
  }

  /// Foreground ink that always reads on a given preset background.
  static Color inkOn(DotGlobeStyle style) =>
      isLight(style) ? const Color(0xFF161A26) : ink;

  /// Dimmed ink that reads on a given preset background.
  static Color inkDimOn(DotGlobeStyle style) =>
      isLight(style) ? const Color(0xFF5B6276) : inkDim;

  // ---- type ramp ----

  /// A wide-tracked, all-caps micro label — the "scientific instrument" tell.
  static TextStyle label(Color color) => TextStyle(
        color: color,
        fontSize: 11,
        height: 1.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.4,
      );

  /// A large, light display number/heading.
  static TextStyle display(Color color, {double size = 34}) => TextStyle(
        color: color,
        fontSize: size,
        height: 1.02,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
      );

  /// A confident section title.
  static TextStyle title(Color color) => TextStyle(
        color: color,
        fontSize: 19,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  /// Body copy.
  static TextStyle body(Color color) => TextStyle(
        color: color,
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
      );

  /// Monospaced-feeling readout for coordinates / values.
  static TextStyle mono(Color color, {double size = 14}) => TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier'],
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );
}

/// A frosted "instrument panel" surface — the recurring container for controls,
/// captions and legends. Tints toward [accent] so panels match the live globe.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    required this.accent,
    this.light = false,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color accent;
  final bool light;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final base = light ? Colors.white : const Color(0xFF0E1426);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: light ? base.withValues(alpha: 0.72) : base.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: light ? 0.18 : 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: light ? 0.10 : 0.18),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A small pill that pairs a wide-tracked label with the accent dot — used as a
/// section eyebrow across pages.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, required this.accent, required this.onDark});

  final String text;
  final Color accent;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Text(
          text,
          style: Kit.label(onDark ? Kit.inkDim : const Color(0xFF5B6276)),
        ),
      ],
    );
  }
}

/// A radial "spotlight" backdrop that gives every page depth: a soft glow of
/// [accent] behind the globe, fading into the chrome [background].
class Backdrop extends StatelessWidget {
  const Backdrop({
    super.key,
    required this.background,
    required this.accent,
    required this.child,
  });

  final Color background;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.1,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.16), background),
            background,
          ],
          stops: const [0.0, 0.85],
        ),
      ),
      child: child,
    );
  }
}
