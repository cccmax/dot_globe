import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Visual configuration for a [DotGlobe] — colours, lighting and dot size.
///
/// Use a ready-made preset for one-line styling:
///
/// ```dart
/// DotGlobe(style: DotGlobeStyle.dark)
/// ```
///
/// Or tweak a preset with [copyWith]:
///
/// ```dart
/// DotGlobe(
///   style: DotGlobeStyle.neon.copyWith(dotRadius: 1.8),
/// )
/// ```
///
/// Built-in presets: [light], [dark], [polymarket], [neon], [sunset], [mono],
/// [emerald], [pastel], [midnight]. Iterate them all via [presets].
@immutable
class DotGlobeStyle {
  /// Creates a style. Only [dotColor] and [sphereColor] are required; the rest
  /// default to a flat, glow-less look.
  const DotGlobeStyle({
    required this.dotColor,
    required this.sphereColor,
    this.glowColor,
    this.sphereLight = false,
    this.depthFade = 0.0,
    this.dotRadius = 1.4,
    this.backgroundColor,
  })  : assert(depthFade >= 0 && depthFade <= 1, 'depthFade must be in 0..1'),
        assert(dotRadius > 0, 'dotRadius must be > 0');

  /// Colour of the land dots (front-facing opacity; far dots dim automatically
  /// when [depthFade] > 0). Include an alpha channel as needed.
  final Color dotColor;

  /// Base colour of the sphere body — the radial-gradient (or flat) orb the
  /// dots sit on. Usually semi-transparent.
  final Color sphereColor;

  /// Rim-glow colour drawn as a thin ring at the sphere's silhouette.
  /// `null` disables it. Reads best on dark backgrounds; on light backgrounds
  /// a rim glow tends to muddy the edge, so the light/pastel/mono presets
  /// leave it off.
  final Color? glowColor;

  /// When `true`, the sphere base is a radial gradient that fakes a light
  /// source in the upper-left (a 3D-lit look). When `false`, [sphereColor] is
  /// painted flat (minimal/flat look).
  final bool sphereLight;

  /// How strongly front-facing dots are brighter and larger than dots near the
  /// silhouette, 0–1. `1` is a strong sense of depth (the Polymarket look);
  /// `0` paints every visible dot at the same brightness and size.
  final double depthFade;

  /// Radius of a single land dot in logical pixels (measured at the sphere's
  /// front).
  final double dotRadius;

  /// Optional fill painted behind the globe so a preset looks complete on its
  /// own. `null` keeps the globe transparent and lets the host background show
  /// through. The preset values use the background each palette was tuned for.
  final Color? backgroundColor;

  /// Returns a copy with the given fields replaced.
  ///
  /// Note: passing `null` for [glowColor] or [backgroundColor] does **not**
  /// clear them (it keeps the current value), because `null` is the
  /// "unchanged" sentinel. Construct a [DotGlobeStyle] directly to clear them.
  DotGlobeStyle copyWith({
    Color? dotColor,
    Color? sphereColor,
    Color? glowColor,
    bool? sphereLight,
    double? depthFade,
    double? dotRadius,
    Color? backgroundColor,
  }) {
    return DotGlobeStyle(
      dotColor: dotColor ?? this.dotColor,
      sphereColor: sphereColor ?? this.sphereColor,
      glowColor: glowColor ?? this.glowColor,
      sphereLight: sphereLight ?? this.sphereLight,
      depthFade: depthFade ?? this.depthFade,
      dotRadius: dotRadius ?? this.dotRadius,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  // ---- Presets ----

  /// Pale blue dots, flat, faint glow — for light-themed apps (app baseline).
  static const DotGlobeStyle light = DotGlobeStyle(
    dotColor: Color(0xFFB9C6F2),
    sphereColor: Color(0x33D6DEFA),
    glowColor: Color(0xFF6B8AE8),
    backgroundColor: Color(0xFFFFFFFF),
  );

  /// Deep blue luminous dots on navy, flat — for dark-themed apps (app
  /// baseline).
  static const DotGlobeStyle dark = DotGlobeStyle(
    dotColor: Color(0xFF3A57D5),
    sphereColor: Color(0x4D16204A),
    glowColor: Color(0xFF2E5BFF),
    backgroundColor: Color(0xFF0A1430),
  );

  /// 3D-lit blue globe with strong depth — homage to the Polymarket world-cup
  /// map this package recreates.
  static const DotGlobeStyle polymarket = DotGlobeStyle(
    dotColor: Color(0xFF4E6BF5),
    sphereColor: Color(0x59101B45),
    glowColor: Color(0xFF3358FF),
    sphereLight: true,
    depthFade: 1.0,
    backgroundColor: Color(0xFF080C1C),
  );

  /// Cyber neon — cyan dots with a magenta rim. Web3 / dashboard energy.
  static const DotGlobeStyle neon = DotGlobeStyle(
    dotColor: Color(0xFF2EF2E0),
    sphereColor: Color(0x4D0A1A24),
    glowColor: Color(0xFFFF2BD6),
    depthFade: 0.55,
    backgroundColor: Color(0xFF050A10),
  );

  /// Warm sunset — amber dots on a lit ember orb. Friendly, brand-forward.
  static const DotGlobeStyle sunset = DotGlobeStyle(
    dotColor: Color(0xFFFFB24C),
    sphereColor: Color(0x593A1208),
    glowColor: Color(0xFFFF6A3D),
    sphereLight: true,
    depthFade: 0.7,
    backgroundColor: Color(0xFF160805),
  );

  /// Monochrome — white dots on near-black, flat, no glow. Editorial, premium.
  static const DotGlobeStyle mono = DotGlobeStyle(
    dotColor: Color(0xFFF2F2F2),
    sphereColor: Color(0x4D161616),
    backgroundColor: Color(0xFF0A0A0A),
  );

  /// Emerald — turquoise dots on a lit forest-green orb. Organic, geographic.
  static const DotGlobeStyle emerald = DotGlobeStyle(
    dotColor: Color(0xFF34D9A4),
    sphereColor: Color(0x59082A20),
    glowColor: Color(0xFF14B88A),
    sphereLight: true,
    depthFade: 0.5,
    backgroundColor: Color(0xFF04140F),
  );

  /// Pastel — mauve dots on cream lavender, flat, no glow. Cute, on light.
  static const DotGlobeStyle pastel = DotGlobeStyle(
    dotColor: Color(0xFFE99BC4),
    sphereColor: Color(0x2EEDE3F7),
    backgroundColor: Color(0xFFFBF7FC),
  );

  /// Midnight — cool off-white dots, faint blue glow, flat. A quieter dark
  /// default than [dark].
  static const DotGlobeStyle midnight = DotGlobeStyle(
    dotColor: Color(0xFFA8C0FF),
    sphereColor: Color(0x4D0B1230),
    glowColor: Color(0xFF5A7BE0),
    backgroundColor: Color(0xFF060912),
  );

  /// All built-in presets keyed by name — handy for galleries and pickers.
  static const Map<String, DotGlobeStyle> presets = {
    'light': light,
    'dark': dark,
    'polymarket': polymarket,
    'neon': neon,
    'sunset': sunset,
    'mono': mono,
    'emerald': emerald,
    'pastel': pastel,
    'midnight': midnight,
  };

  @override
  bool operator ==(Object other) {
    return other is DotGlobeStyle &&
        other.dotColor == dotColor &&
        other.sphereColor == sphereColor &&
        other.glowColor == glowColor &&
        other.sphereLight == sphereLight &&
        other.depthFade == depthFade &&
        other.dotRadius == dotRadius &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode => Object.hash(
        dotColor,
        sphereColor,
        glowColor,
        sphereLight,
        depthFade,
        dotRadius,
        backgroundColor,
      );
}
