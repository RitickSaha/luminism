import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminism/luminism.dart';
import 'package:luminism_example/main.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows Luminism, then Prism-bend', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const LuminismDemoApp(sensors: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LuminSurface), findsWidgets);
    expect(find.byType(LuminSwitch), findsOneWidget);
    expect(find.byType(PrismBendSurface), findsNothing);

    await tester.tap(find.text('Prism-bend'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PrismBendSurface), findsWidgets);
    expect(find.byType(PrismBendSwitch), findsOneWidget);
    expect(find.byType(LuminSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cycles system, light and dark themes', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const LuminismDemoApp(sensors: false));
    await tester.pump();
    for (final String next in <String>[
      'Theme: light',
      'Theme: dark',
      'Theme: system'
    ]) {
      await tester.tap(find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip!.startsWith('Theme:')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip(next), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the tilt pad steers the light', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const LuminismDemoApp(sensors: false));
    await tester.pump();
    await tester.tap(find.byTooltip('Tilt pad'));
    // The sheet starts opening on the next frame; the light drifts forever,
    // so pump for a fixed time instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final Rect pad = tester.getRect(find.byKey(const Key('tilt-pad')));
    await tester.tapAt(pad.centerRight - const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 100));
    final LuminismLightController light =
        LuminismLight.maybeOf(tester.element(find.byType(HomeScreen)))!;
    expect(light.tilt.dx, greaterThan(0.8));
  });

  testWidgets('the primary button responds', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const LuminismDemoApp(sensors: false));
    await tester.pump();
    await tester.tap(find.text('Start a workout'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Workout started'), findsOneWidget);
  });
}
