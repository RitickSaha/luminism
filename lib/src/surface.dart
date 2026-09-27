import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'lit.dart';

/// Where a painter finds the light, in its own coordinates.
typedef LightFinder = Offset Function(Size size);

/// Shared behaviour of the lit surfaces: repaints the background when the
/// light moves or the surface scrolls under it, without repainting the
/// content.
class _LitSurface extends StatefulWidget {
  const _LitSurface({
    required this.painterBuilder,
    required this.padding,
    required this.child,
  });

  final CustomPainter Function(LightFinder lightIn, Listenable repaint)
      painterBuilder;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  State<_LitSurface> createState() => _LitSurfaceState();
}

class _LitSurfaceState extends State<_LitSurface> with LitState<_LitSurface> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: widget.painterBuilder(lightIn, lightRepaint),
      // Content doesn't repaint when only the light moves.
      child: RepaintBoundary(
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}

/// The brightness a lit widget should use.
Brightness litBrightness(BuildContext context, Brightness? override) =>
    override ?? Theme.of(context).brightness;

/// A surface that glows from within, brightest toward the light, and casts
/// its own [color] instead of a grey shadow. Part of the Luminism style.
///
/// ```dart
/// LuminSurface(
///   color: Colors.deepOrange,
///   child: Text('5.2 km'),
/// )
/// ```
class LuminSurface extends StatelessWidget {
  /// Creates a glowing surface tinted by [color].
  const LuminSurface({
    super.key,
    required this.color,
    this.child,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(16),
    this.bright = false,
    this.brightness,
  });

  /// The hue of the glow. Only its hue is used; the style picks lightness
  /// and saturation for the current [Brightness].
  final Color color;

  /// The content of the surface.
  final Widget? child;

  /// The corner radius.
  final double borderRadius;

  /// Space around [child].
  final EdgeInsetsGeometry padding;

  /// Uses a bright, saturated fill, for primary buttons.
  final bool bright;

  /// Overrides the theme's brightness.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final bool dark = litBrightness(context, brightness) == Brightness.dark;
    return _LitSurface(
      padding: padding,
      painterBuilder: (lightIn, repaint) => _LuminPainter(
        lightIn: lightIn,
        repaint: repaint,
        hue: HSLColor.fromColor(color).hue,
        radius: borderRadius,
        dark: dark,
        bright: bright,
      ),
      child: child,
    );
  }
}

class _LuminPainter extends CustomPainter {
  _LuminPainter({
    required this.lightIn,
    required Listenable repaint,
    required this.hue,
    required this.radius,
    required this.dark,
    required this.bright,
  }) : super(repaint: repaint);

  final LightFinder lightIn;
  final double hue;
  final double radius;
  final bool dark;
  final bool bright;

  Color _c(double s, double l, double a) =>
      HSLColor.fromAHSL(a, hue, s, l).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final Offset light = lightIn(size);

    // Shadows are colored light: the surface casts its own hue.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 12)).deflate(6),
      Paint()
        ..color =
            _c(0.95, dark ? 0.56 : 0.62, bright ? 0.8 : (dark ? 0.7 : 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // The body glows from within: one broad, soft wash of light, sized by
    // the surface's longest side so thin surfaces don't get a pinpoint.
    final double reach = math.max(size.longestSide * 1.25, 240);
    final List<Color> body = bright
        ? <Color>[_c(1, 0.72, 1), _c(0.95, 0.58, 1)]
        : dark
            ? <Color>[_c(0.62, 0.3, 0.96), _c(0.45, 0.14, 0.96)]
            : <Color>[_c(1, 0.97, 0.96), _c(0.72, 0.87, 0.96)];
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.radial(light, reach, body, const <double>[0, 1]),
    );

    // The rim catches the light, fading gently around the edge.
    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.radial(
          light,
          math.max(size.longestSide * 0.9, 180),
          <Color>[
            _c(1, dark || bright ? 0.86 : 1, 0.9),
            _c(0.7, dark ? 0.55 : 0.75, 0.15),
          ],
          const <double>[0, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_LuminPainter old) =>
      old.hue != hue ||
      old.radius != radius ||
      old.dark != dark ||
      old.bright != bright ||
      old.lightIn != lightIn;
}

/// The spectrum colors of Prism-bend, for light and dark themes.
const List<Color> prismSpectrumLight = <Color>[
  Color(0xFFFF9FC6), Color(0xFFFFD27A), Color(0xFF9FF0C9), //
  Color(0xFF8FC6FF), Color(0xFFC6A5FF),
];

/// The spectrum colors of Prism-bend in dark themes.
const List<Color> prismSpectrumDark = <Color>[
  Color(0xFFFF6FAE), Color(0xFFFFC247), Color(0xFF5EF0B0), //
  Color(0xFF5AA9FF), Color(0xFFB58CFF),
];

/// The angle from the middle of a [size] box toward [light], in radians.
double angleToward(Size size, Offset light) =>
    math.atan2(light.dy - size.height / 2, light.dx - size.width / 2);

/// The rotation that turns Prism-bend's spectrum band to face [light],
/// for a surface of [size].
///
/// The band spans 22° to 110° of the sweep, so its middle (66°) is turned
/// toward the light.
@visibleForTesting
double prismBandRotation(Size size, Offset light) =>
    angleToward(size, light) - 66 * math.pi / 180;

/// A calm, clear surface whose edge splits the light into a soft spectrum
/// on the side facing the light. Part of the Prism-bend style.
///
/// ```dart
/// PrismBendSurface(child: Text('7h 40m'))
/// ```
class PrismBendSurface extends StatelessWidget {
  /// Creates a surface with a spectrum edge.
  const PrismBendSurface({
    super.key,
    this.child,
    this.color,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(16),
    this.edgeWidth = 1.5,
    this.brightness,
  });

  /// The content of the surface.
  final Widget? child;

  /// The fill. Defaults to a near-white or graphite for the brightness.
  final Color? color;

  /// The corner radius.
  final double borderRadius;

  /// Space around [child].
  final EdgeInsetsGeometry padding;

  /// The width of the spectrum edge.
  final double edgeWidth;

  /// Overrides the theme's brightness.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final bool dark = litBrightness(context, brightness) == Brightness.dark;
    return _LitSurface(
      padding: padding,
      painterBuilder: (lightIn, repaint) => _PrismPainter(
        lightIn: lightIn,
        repaint: repaint,
        fill:
            color ?? (dark ? const Color(0xFF16181E) : const Color(0xFFFBFCFE)),
        radius: borderRadius,
        edgeWidth: edgeWidth,
        dark: dark,
      ),
      child: child,
    );
  }
}

class _PrismPainter extends CustomPainter {
  _PrismPainter({
    required this.lightIn,
    required Listenable repaint,
    required this.fill,
    required this.radius,
    required this.edgeWidth,
    required this.dark,
  }) : super(repaint: repaint);

  final LightFinder lightIn;
  final Color fill;
  final double radius;
  final double edgeWidth;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Shadows stay soft and neutral; color is saved for light.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 12)).deflate(8),
      Paint()
        ..color = dark ? const Color(0x99000000) : const Color(0x59141828)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final List<Color> s = dark ? prismSpectrumDark : prismSpectrumLight;
    final Color edge = dark ? const Color(0xFF2A2E37) : const Color(0xFFD8DCE4);
    canvas.drawRRect(
      rrect.deflate(edgeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..shader = SweepGradient(
          colors: <Color>[edge, ...s, edge, edge],
          stops: const <double>[
            0, 22 / 360, 44 / 360, 66 / 360, 88 / 360, 110 / 360, 140 / 360,
            1, //
          ],
          transform: GradientRotation(prismBandRotation(size, lightIn(size))),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PrismPainter old) =>
      old.fill != fill ||
      old.radius != radius ||
      old.edgeWidth != edgeWidth ||
      old.dark != dark ||
      old.lightIn != lightIn;
}
