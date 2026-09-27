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

    // The body glows from within: one soft wash of light, sized by the
    // surface's longest side so thin surfaces don't get a pinpoint.
    final double reach = math.max(size.longestSide * 0.94, 180);
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

/// Where Prism-bend's spectrum band sits on the edge of a rounded rectangle.
///
/// A sweep gradient spreads colour by angle from the centre, so a band of
/// fixed angle covers far more edge near the corners and short sides of a
/// wide surface. The band is measured along the edge instead: it covers the
/// same length wherever the light is, with its middle facing the light.
@visibleForTesting
class PrismBand {
  /// Measures the edge of a [size] rectangle with corners of [radius].
  factory PrismBand(Size size, double radius) {
    final Rect rect = Offset.zero & size;
    final ui.PathMetric edge = (Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))))
        .computeMetrics()
        .first;
    final Offset centre = rect.center;
    final List<double> angles = <double>[];
    for (int i = 0; i <= _samples; i++) {
      final Offset p =
          edge.getTangentForOffset(edge.length * i / _samples)!.position -
              centre;
      final double a = math.atan2(p.dy, p.dx);
      if (angles.isEmpty) {
        angles.add(a);
      } else {
        // Unwrap, so the angles run on smoothly past ±π.
        final double d = a - angles.last;
        angles.add(angles.last + d - 2 * math.pi * (d / (2 * math.pi)).round());
      }
    }
    // Sweep gradients turn clockwise; walk the edge the same way.
    return PrismBand._(
      edge.length,
      angles.last > angles.first ? angles : angles.reversed.toList(),
    );
  }

  PrismBand._(this.perimeter, this._angles);

  static const int _samples = 240;

  /// Where each colour sits along the band, from 0 to 1: a fade in, the
  /// spectrum, and a fade out. The middle colour (at [_middle]) faces the
  /// light.
  static const List<double> _at = <double>[
    0, 22 / 140, 44 / 140, 66 / 140, 88 / 140, 110 / 140, 1, //
  ];
  static const double _middle = 66 / 140;

  /// The length of the edge.
  final double perimeter;

  /// The angle from the centre of evenly spaced points along the edge,
  /// clockwise, and increasing.
  final List<double> _angles;

  /// The length of edge the band covers: about a quarter of it.
  double get length => (perimeter * 0.24).clamp(110.0, 220.0);

  /// The sweep rotation and gradient stops that place the band's colours on
  /// the edge facing [light]. The stops end with 1, for the plain edge.
  ({double rotation, List<double> stops}) toward(Size size, Offset light) {
    final double middle = _stepAt(angleToward(size, light));
    final double span = length / perimeter * _samples;
    final List<double> angles = <double>[
      for (final double f in _at) _angleAt(middle + (f - _middle) * span),
    ];
    final double start = angles.first;
    return (
      rotation: start,
      stops: <double>[
        for (final double a in angles) (a - start) / (2 * math.pi),
        1,
      ],
    );
  }

  /// Where along the edge, in samples, a ray from the centre at [angle]
  /// meets it.
  double _stepAt(double angle) {
    final double first = _angles.first;
    final double a = first + (angle - first) % (2 * math.pi);
    int i = 0;
    while (i < _samples - 1 && _angles[i + 1] < a) {
      i++;
    }
    final double lo = _angles[i];
    final double hi = _angles[i + 1];
    return i + (hi == lo ? 0 : ((a - lo) / (hi - lo)).clamp(0.0, 1.0));
  }

  /// The angle from the centre of the point [step] samples along the edge.
  double _angleAt(double step) {
    final int turns = (step / _samples).floor();
    final double s = step - turns * _samples;
    final int i = s.floor().clamp(0, _samples - 1);
    final double lo = _angles[i];
    final double hi = _angles[i + 1];
    return lo + (hi - lo) * (s - i) + turns * 2 * math.pi;
  }
}

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

  // Measuring the edge is the costly part, so it's kept while the size holds.
  PrismBand? _band;
  Size? _bandSize;

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
    final Size edgeSize = rrect.deflate(edgeWidth / 2).outerRect.size;
    if (_band == null || _bandSize != size) {
      _bandSize = size;
      _band = PrismBand(edgeSize, math.max(radius - edgeWidth / 2, 0));
    }
    final ({double rotation, List<double> stops}) band = _band!.toward(
      edgeSize,
      lightIn(size) - Offset(edgeWidth / 2, edgeWidth / 2),
    );
    canvas.drawRRect(
      rrect.deflate(edgeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..shader = SweepGradient(
          colors: <Color>[edge, ...s, edge, edge],
          stops: band.stops,
          transform: GradientRotation(band.rotation),
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
