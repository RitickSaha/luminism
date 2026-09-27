import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminism/luminism.dart';
import 'package:luminism/src/lit.dart';
import 'package:luminism/src/surface.dart' show PrismBand;
import 'package:luminism/src/tilt.dart';

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

    testWidgets('touching a surface does not move the light', (tester) async {
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
      final TestGesture gesture = await tester.startGesture(
          tester.getBottomRight(find.byType(LuminSurface)) -
              const Offset(8, 8));
      await tester.pump(const Duration(milliseconds: 300));
      expect(light.position, rest);
      await gesture.up();
    });
  });

  group('pointer', () {
    test('influence is full inside and fades out past the edge', () {
      const Size size = Size(200, 100);
      expect(pointerInfluence(const Offset(100, 50), size), 1);
      expect(pointerInfluence(const Offset(-10, 50), size), greaterThan(0.9));
      expect(pointerInfluence(const Offset(-30, 50), size), closeTo(0.5, 0.01));
      expect(pointerInfluence(const Offset(-60, 50), size), 0);
      expect(pointerInfluence(const Offset(300, 300), size), 0);
    });

    testWidgets('lights only the surface under it', (tester) async {
      final LuminismLightController light = LuminismLightController();
      final GlobalKey<_ProbeState> near = GlobalKey<_ProbeState>();
      final GlobalKey<_ProbeState> far = GlobalKey<_ProbeState>();
      await tester.pumpWidget(_app(
        controller: light,
        drift: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          _Probe(key: near),
          const SizedBox(height: 200),
          _Probe(key: far),
        ]),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      final Offset ambient = light.position;
      final Offset target = tester.getCenter(find.byKey(near));

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: target);
      await mouse.moveTo(target);
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // The ambient light stays put; only the nearby surface follows the mouse.
      expect(light.position, ambient);
      expect(light.pointerWeight, closeTo(1, 0.01));
      expect(near.currentState!.lightGlobal(),
          offsetMoreOrLessEquals(target, epsilon: 1));
      expect(far.currentState!.lightGlobal(),
          offsetMoreOrLessEquals(ambient, epsilon: 1));

      await mouse.removePointer();
      for (int i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(light.pointer, isNull);
      expect(near.currentState!.lightGlobal(),
          offsetMoreOrLessEquals(ambient, epsilon: 1));
    });

    testWidgets('can be turned off', (tester) async {
      final LuminismLightController light = LuminismLightController();
      await tester.pumpWidget(MaterialApp(
        builder: (context, app) => LuminismLight(
          controller: light,
          drift: false,
          followPointer: false,
          child: app!,
        ),
        home: const SizedBox(),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      await mouse.moveTo(const Offset(700, 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(light.pointer, isNull);
      await mouse.removePointer();
    });
  });

  group('switches', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('toggle on tap in $b', (tester) async {
        bool lumin = false;
        bool prism = true;
        await tester.pumpWidget(_app(
          brightness: b,
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LuminSwitch(
                    value: lumin, onChanged: (v) => setState(() => lumin = v)),
                PrismBendSwitch(
                    value: prism, onChanged: (v) => setState(() => prism = v)),
              ],
            ),
          ),
        ));
        await tester.tap(find.byType(LuminSwitch));
        await tester.tap(find.byType(PrismBendSwitch));
        await tester.pump(const Duration(milliseconds: 300));
        expect(lumin, isTrue);
        expect(prism, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('does nothing when disabled', (tester) async {
      await tester.pumpWidget(_app(
        child: const LuminSwitch(value: false, onChanged: null),
      ));
      await tester.tap(find.byType(LuminSwitch));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tells screen readers whether it is on', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        child: PrismBendSwitch(value: true, onChanged: (_) {}),
      ));
      expect(
        tester.getSemantics(find.byType(PrismBendSwitch)),
        matchesSemantics(
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('is a 48 by 48 touch target', (tester) async {
      await tester.pumpWidget(_app(
        child: LuminSwitch(value: true, onChanged: (_) {}),
      ));
      expect(tester.getSize(find.byType(LuminSwitch)), const Size(48, 48));
    });
  });

  group('tilt tracker', () {
    const Duration frame = Duration(milliseconds: 20);

    test('follows the gyroscope at once', () {
      final TiltTracker t = TiltTracker();
      Duration now = Duration.zero;
      t.gyroscope(0, 0, now);
      // Turn the right edge away by half a full turn in 0.1 s.
      Offset tilt = Offset.zero;
      for (int i = 0; i < 5; i++) {
        now += frame;
        tilt = t.gyroscope(0, TiltTracker.fullTurn / 2 / 0.1, now);
      }
      expect(tilt.dx, closeTo(-0.5, 0.02));
      expect(tilt.dy, 0);
    });

    test('stops at a full tilt and turns back at once', () {
      final TiltTracker t = TiltTracker();
      Duration now = Duration.zero;
      t.gyroscope(0, 0, now);
      for (int i = 0; i < 20; i++) {
        now += frame;
        t.gyroscope(3, 0, now);
      }
      now += frame;
      final Offset tilt = t.gyroscope(-3, 0, now);
      expect(tilt.dy, closeTo(-1 + 3 * 0.02 / TiltTracker.fullTurn, 0.02));
    });

    test('eases back to the centre when held still', () {
      final TiltTracker t = TiltTracker();
      Duration now = Duration.zero;
      t.gyroscope(0, 0, now);
      now += frame;
      final Offset turned = t.gyroscope(0, 7, now);
      Offset tilt = turned;
      for (int i = 0; i < 1000; i++) {
        now += frame;
        tilt = t.gyroscope(0, 0, now);
      }
      expect(turned.dx, lessThan(-0.4));
      expect(tilt.dx.abs(), lessThan(0.01));
    });

    test('ignores a steady gyroscope bias', () {
      final TiltTracker t = TiltTracker();
      Duration now = Duration.zero;
      Offset tilt = Offset.zero;
      for (int i = 0; i < 1500; i++) {
        tilt = t.gyroscope(0.01, 0.01, now);
        now += frame;
      }
      expect(tilt.distance, lessThan(0.02));
    });

    test('falls back to the accelerometer without a gyroscope', () {
      final TiltTracker t = TiltTracker();
      Duration now = Duration.zero;
      expect(t.accelerometer(0, 0, now), Offset.zero);
      Offset? tilt;
      for (int i = 0; i < 20; i++) {
        now += frame;
        tilt = t.accelerometer(-1, 0, now);
      }
      expect(tilt!.dx, lessThan(-0.3));

      t.gyroscope(0, 0, now);
      expect(t.accelerometer(-1, 0, now + frame), isNull,
          reason: 'the gyroscope leads while it is heard from');
      expect(
          t.accelerometer(-1, 0, now + const Duration(seconds: 1)), isNotNull);
    });
  });

  group('prism band', () {
    const Size wide = Size(350, 100);
    final PrismBand band = PrismBand(wide, 22);
    const Offset right = Offset(2000, 50);
    const Offset above = Offset(175, -2000);
    const Offset corner = Offset(2000, -2000);

    // The point on the edge a ray from the centre at [angle] meets.
    Offset edgeAt(double angle) {
      final Offset d = Offset(math.cos(angle), math.sin(angle));
      final double t = math.min(
        (wide.width / 2) / d.dx.abs().clamp(1e-9, 1),
        (wide.height / 2) / d.dy.abs().clamp(1e-9, 1),
      );
      return wide.center(Offset.zero) + d * t;
    }

    // The straight-line length the band covers, ignoring rounded corners.
    double reach(Offset light) {
      final r = band.toward(wide, light);
      final List<double> stops = r.stops;
      Offset? last;
      double length = 0;
      for (int i = 0; i <= 60; i++) {
        final double a =
            r.rotation + 2 * math.pi * stops[stops.length - 2] * i / 60;
        final Offset p = edgeAt(a);
        if (last != null) length += (p - last).distance;
        last = p;
      }
      return length;
    }

    test('covers about the same length of edge wherever the light is', () {
      final double top = reach(above);
      expect(top, closeTo(band.length, band.length * 0.1));
      expect(reach(right), closeTo(top, top * 0.12));
      expect(reach(corner), closeTo(top, top * 0.12));
    });

    test('faces the light with its middle colour', () {
      for (final Offset light in <Offset>[right, above, corner]) {
        final r = band.toward(wide, light);
        final double middle = r.rotation + 2 * math.pi * r.stops[3];
        final double toward = math.atan2(light.dy - 50, light.dx - 175);
        final double d = (middle - toward) % (2 * math.pi);
        expect(math.min(d, 2 * math.pi - d), lessThan(0.02));
      }
    });

    test('has increasing stops that end with the plain edge', () {
      final List<double> stops = band.toward(wide, corner).stops;
      for (int i = 1; i < stops.length; i++) {
        expect(stops[i], greaterThanOrEqualTo(stops[i - 1]));
      }
      expect(stops.first, 0);
      expect(stops.last, 1);
      expect(stops[stops.length - 2], lessThan(1));
    });
  });
}

/// A 200 × 100 box that reports where it sees the light.
class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with LitState<_Probe> {
  Offset lightGlobal() {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(lightIn(box.size));
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 200, height: 100);
}
