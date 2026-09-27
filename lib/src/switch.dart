import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lit.dart';
import 'surface.dart';

const Size _trackSize = Size(48, 28);
const double _knobRadius = 11;

/// Shared behaviour of the lit switches: toggling, animation, focus and
/// semantics. Each style supplies its own painter.
class _LitSwitch extends StatefulWidget {
  const _LitSwitch({
    required this.value,
    required this.onChanged,
    required this.painterBuilder,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final CustomPainter Function(
    Animation<double> position,
    LightFinder lightIn,
    Listenable repaint,
    bool focused,
  ) painterBuilder;

  @override
  State<_LitSwitch> createState() => _LitSwitchState();
}

class _LitSwitchState extends State<_LitSwitch>
    with LitState<_LitSwitch>, SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: widget.value ? 1 : 0,
  );
  late final CurvedAnimation _position =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(_LitSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final double target = widget.value ? 1 : 0;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.value = target;
      } else {
        _controller.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? _toggle : null,
          // A 48 × 48 touch target around the 48 × 28 track.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Opacity(
                opacity: _enabled ? 1 : 0.45,
                child: CustomPaint(
                  size: _trackSize,
                  painter: widget.painterBuilder(
                    _position,
                    lightIn,
                    Listenable.merge(<Listenable>[lightRepaint, _position]),
                    _focused,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Offset _knobCenter(double t) =>
    Offset(3 + _knobRadius + t * 20, _trackSize.height / 2);

/// A switch in the Luminism style: when on, the track and knob glow in
/// [color] and cast it around them.
class LuminSwitch extends StatelessWidget {
  /// Creates a glowing switch.
  const LuminSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.color = const Color(0xFF12C8A0),
    this.brightness,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when tapped. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// The hue of the glow when on. Only its hue is used.
  final Color color;

  /// Overrides the theme's brightness.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final bool dark = litBrightness(context, brightness) == Brightness.dark;
    final double hue = HSLColor.fromColor(color).hue;
    return _LitSwitch(
      value: value,
      onChanged: onChanged,
      painterBuilder: (position, lightIn, repaint, focused) =>
          _LuminSwitchPainter(
        position: position,
        lightIn: lightIn,
        repaint: repaint,
        focused: focused,
        hue: hue,
        dark: dark,
      ),
    );
  }
}

class _LuminSwitchPainter extends CustomPainter {
  _LuminSwitchPainter({
    required this.position,
    required this.lightIn,
    required Listenable repaint,
    required this.focused,
    required this.hue,
    required this.dark,
  }) : super(repaint: repaint);

  final Animation<double> position;
  final LightFinder lightIn;
  final bool focused;
  final double hue;
  final bool dark;

  Color _c(double s, double l, double a) =>
      HSLColor.fromAHSL(a, hue, s, l).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    final double t = position.value;
    final RRect track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );

    // On: the track glows and casts its color around it.
    if (t > 0) {
      canvas.drawRRect(
        track,
        Paint()
          ..color = _c(0.9, 0.5, 0.7 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    final Color off = dark ? const Color(0xFF2A2C36) : const Color(0xFFD6D9E3);
    final Color on = dark ? _c(0.6, 0.24, 1) : _c(0.7, 0.42, 1);
    canvas.drawRRect(track, Paint()..color = Color.lerp(off, on, t)!);

    // A soft sheen on the side facing the light.
    canvas.drawRRect(
      track,
      Paint()
        ..shader = ui.Gradient.radial(
          lightIn(size),
          math.max(size.longestSide * 2.5, 120),
          <Color>[
            Color.fromRGBO(255, 255, 255, dark ? 0.1 : 0.22),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
        ),
    );

    final Offset knob = _knobCenter(t);
    if (t > 0) {
      canvas.drawCircle(
        knob,
        _knobRadius + 2,
        Paint()
          ..color = _c(1, 0.65, 0.9 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      knob + const Offset(0, 1),
      _knobRadius,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    final Color knobOff = dark ? const Color(0xFF8B8F9C) : Colors.white;
    final Color knobOn = dark ? _c(0.95, 0.7, 1) : Colors.white;
    canvas.drawCircle(
        knob, _knobRadius, Paint()..color = Color.lerp(knobOff, knobOn, t)!);

    if (focused) {
      canvas.drawRRect(
        track.inflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _c(0.8, dark ? 0.7 : 0.4, 1),
      );
    }
  }

  @override
  bool shouldRepaint(_LuminSwitchPainter old) =>
      old.focused != focused ||
      old.hue != hue ||
      old.dark != dark ||
      old.lightIn != lightIn ||
      old.position != position;
}

/// A switch in the Prism-bend style: when on, the track fills with a
/// spectrum that turns to face the light.
class PrismBendSwitch extends StatelessWidget {
  /// Creates a spectrum switch.
  const PrismBendSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.brightness,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when tapped. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Overrides the theme's brightness.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final bool dark = litBrightness(context, brightness) == Brightness.dark;
    return _LitSwitch(
      value: value,
      onChanged: onChanged,
      painterBuilder: (position, lightIn, repaint, focused) =>
          _PrismSwitchPainter(
        position: position,
        lightIn: lightIn,
        repaint: repaint,
        focused: focused,
        dark: dark,
      ),
    );
  }
}

class _PrismSwitchPainter extends CustomPainter {
  _PrismSwitchPainter({
    required this.position,
    required this.lightIn,
    required Listenable repaint,
    required this.focused,
    required this.dark,
  }) : super(repaint: repaint);

  final Animation<double> position;
  final LightFinder lightIn;
  final bool focused;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = position.value;
    final Rect rect = Offset.zero & size;
    final RRect track =
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));
    canvas.drawRRect(
      track,
      Paint()..color = dark ? const Color(0xFF2A2E37) : const Color(0xFFD6DAE2),
    );
    if (t > 0) {
      final List<Color> s = dark ? prismSpectrumDark : prismSpectrumLight;
      canvas.drawRRect(
        track,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, t)
          ..shader = SweepGradient(
            colors: <Color>[...s, s.first],
            transform: GradientRotation(angleToward(size, lightIn(size))),
          ).createShader(rect),
      );
    }
    final Offset knob = _knobCenter(t);
    canvas.drawCircle(
      knob + const Offset(0, 1),
      _knobRadius,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(knob, _knobRadius, Paint()..color = Colors.white);

    if (focused) {
      canvas.drawRRect(
        track.inflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = dark ? const Color(0xFFB58CFF) : const Color(0xFF5A4BD6),
      );
    }
  }

  @override
  bool shouldRepaint(_PrismSwitchPainter old) =>
      old.focused != focused ||
      old.dark != dark ||
      old.lightIn != lightIn ||
      old.position != position;
}
