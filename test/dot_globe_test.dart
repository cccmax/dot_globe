import 'dart:typed_data';

import 'package:dot_globe/dot_globe.dart';
import 'package:dot_globe/src/dot_globe_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DotGlobeGeometry', () {
    test('land dots asset loads into valid unit vectors', () async {
      final geometry = await DotGlobeGeometry.load();
      expect(geometry.pointCount, greaterThan(4000));
      expect(geometry.unitVectors.length, geometry.pointCount * 3);
      for (var i = 0; i < 100; i++) {
        final x = geometry.unitVectors[i * 3];
        final y = geometry.unitVectors[i * 3 + 1];
        final z = geometry.unitVectors[i * 3 + 2];
        expect(x * x + y * y + z * z, closeTo(1.0, 1e-4));
      }
    });

    test('projection: east is screen-right, north is screen-up', () {
      final frame = DotGlobeFrame(); // phi = pi/2, longitude 0 faces front
      final v = Float64List(3);
      final out = Float64List(3);

      DotGlobeGeometry.latLngToUnitVector(0, 0, v);
      frame.project(v[0], v[1], v[2], out);
      expect(out[0], closeTo(0, 1e-9));
      expect(out[1], closeTo(0, 1e-9));
      expect(out[2], closeTo(1, 1e-9));

      DotGlobeGeometry.latLngToUnitVector(0, 30, v);
      frame.project(v[0], v[1], v[2], out);
      expect(out[0], greaterThan(0)); // east -> right

      DotGlobeGeometry.latLngToUnitVector(30, 0, v);
      frame.project(v[0], v[1], v[2], out);
      expect(out[1], greaterThan(0)); // north -> up

      DotGlobeGeometry.latLngToUnitVector(0, 180, v);
      frame.project(v[0], v[1], v[2], out);
      expect(out[2], lessThan(0)); // far side
    });
  });

  group('DotGlobeStyle', () {
    test('all named presets are registered in the presets map', () {
      expect(DotGlobeStyle.presets.length, 9);
      expect(DotGlobeStyle.presets['dark'], same(DotGlobeStyle.dark));
      // value equality + copyWith
      expect(DotGlobeStyle.dark, equals(DotGlobeStyle.dark));
      expect(
        DotGlobeStyle.dark.copyWith(dotRadius: 2),
        isNot(equals(DotGlobeStyle.dark)),
      );
    });
  });

  group('DotGlobe widget', () {
    testWidgets('renders with a preset + markers, survives drag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: DotGlobe(
                  style: DotGlobeStyle.dark,
                  markers: [
                    DotGlobeMarker(
                      latitude: 46,
                      longitude: 2,
                      child: Text('FR 16%'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('FR 16%'), findsOneWidget);

      await tester.drag(find.byType(DotGlobe), const Offset(120, 30));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('paused stops the frame loop, resume restarts it',
        (tester) async {
      Widget build(bool paused) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 300,
                child: DotGlobe(style: DotGlobeStyle.light, paused: paused),
              ),
            ),
          );

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(build(false));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller jumpTo/facing + animateTo work', (tester) async {
      final controller = DotGlobeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: DotGlobe(
                controller: controller,
                autoRotateSpeed: 0, // hold still so facing is deterministic
                style: DotGlobeStyle.mono,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.isAttached, isTrue);

      controller.jumpTo(latitude: 0, longitude: 120);
      await tester.pump(const Duration(milliseconds: 16));
      final facing = controller.facing!;
      expect(facing.longitude, closeTo(120, 0.5));
      expect(facing.latitude, closeTo(0, 0.5));

      // animateTo eases toward the target and completes
      final done = controller.animateTo(
        latitude: 0,
        longitude: -30,
        duration: const Duration(milliseconds: 300),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await done;
      expect(controller.facing!.longitude, closeTo(-30, 1.0));
      expect(tester.takeException(), isNull);
    });
  });
}
