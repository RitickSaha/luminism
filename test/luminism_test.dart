import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminism/luminism.dart';
import 'package:luminism/src/surface.dart' show prismBandRotation;

Widget _app({
  required Widget child,
  LuminismLightController? controller,
  bool drift = true,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: LuminismLight(
        controller: controller,
        drift: drift,
        child: app!,
      ),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('surfaces', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('render their child in $b', (tester) async {
        await tester.pumpWidget(_app(
          brightness: b,
          child:
              const Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            LuminSurface(color: Colors.orange, child: Text('lumin')),
            LuminSurface(
                color: Colors.orange, bright: true, child: Text('button')),
            PrismBendSurface(child: Text('prism')),
          ]),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('lumin'), findsOneWidget);
        expect(find.text('button'), findsOneWidget);
        expect(find.text('prism'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('work without a LuminismLight above them', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Column(children: <Widget>[
          LuminSurface(color: Colors.teal, child: Text('a')),
          PrismBendSurface(child: Text('b')),
        ]),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('keep child state when the theme changes', (tester) async {
      final TextEditingController text = TextEditingController();
      Widget build(Brightness b) => _app(
            brightness: b,
            child: PrismBendSurface(
              child: SizedBox(width: 200, child: TextField(controller: text)),
            ),
          );
      await tester.pumpWidget(build(Brightness.light));
      await tester.enterText(find.byType(TextField), 'kept');
      final State before = tester.state(find.byType(TextField));
      await tester.pumpWidget(build(Brightness.dark));
      await tester.pump();
      expect(tester.state(find.byType(TextField)), same(before));
      expect(text.text, 'kept');
    });
  });

  group('light', () {
    testWidgets('drifts on its own', (tester) async {
      final LuminismLightController light = LuminismLightController();
      await tester.pumpWidget(_app(controller: light, child: const SizedBox()));
      await tester.pump(const Duration(milliseconds: 16));
      final Offset a = light.position;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect((light.position - a).distance, greaterThan(5));
    });

    testWidgets('rests at the top centre with reduce motion', (tester) async {
      final LuminismLightController light = LuminismLightController();
      await tester.pumpWidget(_app(
        controller: light,
        reduceMotion: true,
        child: const SizedBox(),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(light.position.dx, closeTo(screen.width / 2, 0.5));
      expect(light.position.dy, closeTo(screen.height * 0.3, 0.5));
      final Offset a = light.position;
      await tester.pump(const Duration(seconds: 1));
      expect(light.position, a);
    });

    testWidgets('tilt steers the light', (tester) async {
      final LuminismLightController light = LuminismLightController();
      await tester.pumpWidget(
          _app(controller: light, drift: false, child: const SizedBox()));
      await tester.pump(const Duration(milliseconds: 16));
      final Offset level = light.position;

      light.tilt = const Offset(1, 0);
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(light.position.dx - level.dx, closeTo(screen.width * 0.45, 2));
      expect(light.tilt, const Offset(1, 0));

      light.tilt = const Offset(5, -5);
      expect(light.tilt, const Offset(1, -1), reason: 'tilt is clamped');
    });

    testWidgets('pressing a surface lends it the light', (tester) async {
      final LuminismLightController light = LuminismLightController();
      await tester.pumpWidget(_app(
        controller: light,
        drift: false,
        child: const LuminSurface(
          color: Colors.orange,
          child: SizedBox(width: 200, height: 100),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      final Offset rest = light.position;
      final Offset finger = tester.getBottomRight(find.byType(LuminSurface)) -
          const Offset(10, 10);

      final TestGesture gesture = await tester.startGesture(finger);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(light.isPressed, isTrue);
      expect((light.position - finger).distance, lessThan(2));

      await gesture.up();
      for (int i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(light.isPressed, isFalse);
      expect((light.position - rest).distance, lessThan(2));
    });

    testWidgets('a drag is not a press', (tester) async {
      final LuminismLightController light = LuminismLightController();
      await tester.pumpWidget(_app(
        controller: light,
        drift: false,
        child: const PrismBendSurface(child: SizedBox(width: 200, height: 100)),
      ));
      final Offset start = tester.getCenter(find.byType(PrismBendSurface));
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump();
      expect(light.isPressed, isTrue);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(light.isPressed, isFalse);
      await gesture.up();
    });
  });

  group('prism band', () {
    const Size size = Size(200, 100);

    test('faces a light to the right', () {
      expect(prismBandRotation(size, const Offset(1000, 50)),
          closeTo(-66 * math.pi / 180, 1e-9));
    });

    test('faces a light above', () {
      expect(
        prismBandRotation(size, const Offset(100, -1000)),
        closeTo(-math.pi / 2 - 66 * math.pi / 180, 1e-9),
      );
    });
  });
}
