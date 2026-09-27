import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import 'light.dart';

/// Where a surface finds the light, in its own coordinates.
typedef _LightFinder = Offset Function(Size size);

/// Shared behaviour of the lit surfaces: finds the light, repaints when the
/// light moves or the surface scrolls under it, and lends the light to a
/// pressing finger.
class _LitSurface extends StatefulWidget {
  const _LitSurface({
    required this.painterBuilder,
    required this.padding,
    required this.child,
  });

  final CustomPainter Function(_LightFinder lightOf, Listenable repaint)
      painterBuilder;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  State<_LitSurface> createState() => _LitSurfaceState();
}

class _LitSurfaceState extends State<_LitSurface> {
  LuminismLightController? _light;
  ScrollPosition? _scroll;
  Offset? _downAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _light = LuminismLight.maybeOf(context);
    _scroll = Scrollable.maybeOf(context)?.position;
  }

  Offset _lightOf(Size size) {
    final RenderObject? box = context.findRenderObject();
    final LuminismLightController? light = _light;
    if (light == null || box is! RenderBox || !box.attached || !box.hasSize) {
      // No light above: a fixed light over the top centre.
      return Offset(size.width / 2, -size.height / 2);
    }
    return box.globalToLocal(light.position);
  }

  void _release() {
    _downAt = null;
    _light?.release();
  }

  @override
  Widget build(BuildContext context) {
    final Listenable repaint = Listenable.merge(<Listenable?>[_light, _scroll]);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _downAt = e.position;
        _light?.press(e.position);
      },
      onPointerMove: (e) {
        final Offset? down = _downAt;
        if (down == null) return;
        // A drag or scroll isn't a press: let the light go.
        if ((e.position - down).distance > kTouchSlop) {
          _release();
        } else {
          _light?.press(e.position);
        }
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: CustomPaint(
        painter: widget.painterBuilder(_lightOf, repaint),
        // Content doesn't repaint when only the light moves.
        child: RepaintBoundary(
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

Brightness _brightnessOf(BuildContext context, Brightness? override) =>
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
    final bool dark = _brightnessOf(context, brightness) == Brightness.dark;
    return _LitSurface(
      padding: padding,
      painterBuilder: (lightOf, repaint) => _LuminPainter(
        lightOf: lightOf,
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
    required this.lightOf,
    required Listenable repaint,
    required this.hue,
    required this.radius,
    required this.dark,
    required this.bright,
  }) : super(repaint: repaint);

  final _LightFinder lightOf;
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
    final Offset light = lightOf(size);
    final Alignment center = Alignment(
      light.dx / size.width * 2 - 1,
      light.dy / size.height * 2 - 1,
    );

    // Shadows are colored light: the surface casts its own hue.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 12)).deflate(6),
      Paint()
        ..color =
            _c(0.95, dark ? 0.56 : 0.62, bright ? 0.8 : (dark ? 0.7 : 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // The body glows from within, brightest toward the light.
    final List<Color> body = bright
        ? <Color>[_c(1, 0.78, 1), _c(0.95, 0.58, 1)]
        : dark
            ? <Color>[_c(0.72, 0.34, 0.96), _c(0.45, 0.13, 0.96)]
            : <Color>[_c(1, 0.98, 0.96), _c(0.7, 0.88, 0.96)];
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: center,
          radius: 1.3,
          colors: body,
          stops: const <double>[0, 0.62],
        ).createShader(rect),
    );

    // The rim catches the light.
    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = RadialGradient(
          center: center,
          radius: 0.9,
          colors: <Color>[
            _c(1, dark || bright ? 0.86 : 1, 0.95),
            _c(0.7, dark ? 0.55 : 0.75, 0.18),
          ],
          stops: const <double>[0, 0.7],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LuminPainter old) =>
      old.hue != hue ||
      old.radius != radius ||
      old.dark != dark ||
      old.bright != bright ||
      old.lightOf != lightOf;
}

/// The spectrum colors of Prism-bend's edge, for light and dark themes.
const List<Color> _spectrumLight = <Color>[
  Color(0xFFFF9FC6), Color(0xFFFFD27A), Color(0xFF9FF0C9), //
  Color(0xFF8FC6FF), Color(0xFFC6A5FF),
];
const List<Color> _spectrumDark = <Color>[
  Color(0xFFFF6FAE), Color(0xFFFFC247), Color(0xFF5EF0B0), //
  Color(0xFF5AA9FF), Color(0xFFB58CFF),
];

/// The rotation that turns Prism-bend's spectrum band to face [light],
/// for a surface of [size].
///
/// The band spans 22° to 110° of the sweep, so its middle (66°) is turned
/// toward the light.
@visibleForTesting
double prismBandRotation(Size size, Offset light) {
  final double toward =
      math.atan2(light.dy - size.height / 2, light.dx - size.width / 2);
  return toward - 66 * math.pi / 180;
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
    final bool dark = _brightnessOf(context, brightness) == Brightness.dark;
    return _LitSurface(
      padding: padding,
      painterBuilder: (lightOf, repaint) => _PrismPainter(
        lightOf: lightOf,
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
    required this.lightOf,
    required Listenable repaint,
    required this.fill,
    required this.radius,
    required this.edgeWidth,
    required this.dark,
  }) : super(repaint: repaint);

  final _LightFinder lightOf;
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

    final List<Color> s = dark ? _spectrumDark : _spectrumLight;
    final Color edge = dark ? const Color(0xFF2A2E37) : const Color(0xFFD8DCE4);
    canvas.drawRRect(
      rrect.deflate(edgeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..shader = SweepGradient(
          colors: <Color>[edge, ...s, edge, edge],
          stops: const <double>[
            0,
            22 / 360,
            44 / 360,
            66 / 360,
            88 / 360,
            110 / 360,
            140 / 360,
            1,
          ],
          transform: GradientRotation(prismBandRotation(size, lightOf(size))),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PrismPainter old) =>
      old.fill != fill ||
      old.radius != radius ||
      old.edgeWidth != edgeWidth ||
      old.dark != dark ||
      old.lightOf != lightOf;
}
