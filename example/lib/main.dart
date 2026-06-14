import 'package:flutter/material.dart';

import 'demos/controller_demo.dart';
import 'demos/demo_kit.dart';
import 'demos/light_demo.dart';
import 'demos/marker_variety_demo.dart';
import 'demos/playground_demo.dart';
import 'demos/preset_gallery_demo.dart';
import 'demos/routes_demo.dart';
import 'demos/world_cup_demo.dart';

void main() => runApp(const DotGlobeGallery());

/// Showcase app for the `dot_globe` package — five demo pages behind a custom
/// floating nav. Each page is a full-bleed hero whose chrome tunes to the live
/// globe on screen.
class DotGlobeGallery extends StatelessWidget {
  const DotGlobeGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dot_globe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Kit.voidColor,
        fontFamily: 'Roboto',
      ),
      home: const _Shell(),
    );
  }
}

/// One navigation destination.
class _Tab {
  const _Tab(this.label, this.icon, this.accent);
  final String label;
  final IconData icon;
  final Color accent;
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  // Accents mirror each page's preset glow, so the nav matches the live page.
  static const List<_Tab> _tabs = [
    _Tab('World Cup', Icons.emoji_events_outlined, Color(0xFF3358FF)),
    _Tab('Routes', Icons.timeline_outlined, Color(0xFF6B8AE8)),
    _Tab('Light', Icons.light_mode_outlined, Color(0xFF6B8AE8)),
    _Tab('Presets', Icons.palette_outlined, Color(0xFF3358FF)),
    _Tab('Control', Icons.my_location_outlined, Color(0xFF14B88A)),
    _Tab('Playground', Icons.tune, Color(0xFF12D6E8)),
    _Tab('Markers', Icons.place_outlined, Color(0xFF5A7BE0)),
  ];

  @override
  Widget build(BuildContext context) {
    // Each page receives `paused` so the four off-screen globes idle their
    // frame loops while the active page animates — the documented use of the
    // DotGlobe.paused flag with a visibility signal.
    final pages = <Widget>[
      WorldCupDemo(paused: _index != 0),
      RoutesDemo(paused: _index != 1),
      LightDemo(paused: _index != 2),
      PresetGalleryDemo(paused: _index != 3),
      ControllerDemo(paused: _index != 4),
      PlaygroundDemo(paused: _index != 5),
      MarkerVarietyDemo(paused: _index != 6),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          // The floating navigation rail.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: _NavBar(
                    tabs: _tabs,
                    index: _index,
                    onChanged: (i) => setState(() => _index = i),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glass capsule navigation bar that highlights the active tab in its accent.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = tabs[index].accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1224).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _NavItem(
              tab: tabs[i],
              selected: i == index,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected ? tab.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 20,
              color: selected ? tab.accent : Kit.inkDim,
            ),
            // Reveal the label only for the active tab to keep the bar compact.
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          color: tab.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
