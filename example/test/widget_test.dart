// A smoke test for the dot_globe showcase app: the gallery builds and the
// navigation lets you reach each demo page.

import 'package:dot_globe_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery boots and navigates between demos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DotGlobeGallery());
    await tester.pump();

    // The World Cup page is the default landing tab.
    expect(find.text('World Cup'), findsOneWidget);

    // Switching to the Playground tab unmounts the World Cup bubbles (cancelling
    // their staggered-entrance timers) and reveals the Playground controls.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Playground'), findsWidgets);
  });
}
