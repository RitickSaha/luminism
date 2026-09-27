import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

/// The position of the light that every Luminism surface shares.
///
/// Read [position] to find the light, set [tilt] to steer it by hand (for
/// simulators, demos and tests), and call [press] and [release] to lend the
/// light to a finger. A [LuminismLight] drives the controller.
class LuminismLightController extends ChangeNotifier {
  Offset _position = Offset.zero;
  Offset _tiltTarget = Offset.zero;
  Offset _tilt = Offset.zero;
  Offset? _press;
  Offset? _lastPress;
  double _pressWeight = 0;
  VoidCallback? _wake;

  /// Where the light is, in global (screen) coordinates.
  Offset get position => _position;

  /// How far the phone is tilted, from -1 to 1 on each axis.
  ///
  /// The motion sensors set this while [LuminismLight.sensors] is on. Set it
  /// yourself to steer the light without sensors.
  Offset get tilt => _tiltTarget;
  set tilt(Offset value) {
    final Offset clamped = Offset(
      value.dx.clamp(-1.0, 1.0),
      value.dy.clamp(-1.0, 1.0),
    );
    if (clamped == _tiltTarget) return;
    _tiltTarget = clamped;
    _wake?.call();
  }

  /// Pulls the light toward [globalPosition], as when a finger presses a
  /// surface.
  void press(Offset globalPosition) {
    _press = globalPosition;
    _lastPress = globalPosition;
    _wake?.call();
  }

  /// Lets the light drift back after a [press].
  void release() {
    if (_press == null) return;
    _press = null;
    _wake?.call();
  }

  /// Whether a finger is currently holding the light.
  bool get isPressed => _press != null;

  void _setPosition(Offset value) {
    if ((value - _position).distanceSquared < 0.0001) return;
    _position = value;
    notifyListeners();
  }
}

/// Lights every [LuminSurface] and [PrismBendSurface] below it with one
/// light source.
///
/// The light sits above the screen and drifts slowly on its own, like a
/// phone held in the hand. Tilting the phone steers it, and pressing a
/// surface briefly pulls it to the finger. With "reduce motion" on, the
/// light rests near the top of the screen.
///
/// Place it inside your app so it covers every screen:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => LuminismLight(child: child!),
/// )
/// ```
class LuminismLight extends StatefulWidget {
  /// Creates a light for the surfaces below it.
  const LuminismLight({
    super.key,
    required this.child,
    this.controller,
    this.drift = true,
    this.sensors = true,
    this.driftSpeed = 0.5,
    this.driftAmplitude = const Offset(0.32, 0.2),
    this.tiltStrength = const Offset(0.45, 0.35),
  });

  /// The subtree the light shines on.
  final Widget child;

  /// Controls the light. One is created if you don't pass it.
  final LuminismLightController? controller;

  /// Whether the light drifts on its own.
  final bool drift;

  /// Whether the phone's motion sensors steer the light.
  ///
  /// Sensors are only used on Android, iOS and the web, and never under
  /// `flutter test`.
  final bool sensors;

  /// How fast the light drifts, in radians per second along its path.
  final double driftSpeed;

  /// How far the light drifts, as a fraction of the screen's width and
  /// height.
  final Offset driftAmplitude;

  /// How far a full tilt moves the light, as a fraction of the screen's
  /// width and height.
  final Offset tiltStrength;

  /// The closest light's controller, or null if there is none.
  static LuminismLightController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_LightScope>()?.controller;

  @override
  State<LuminismLight> createState() => _LuminismLightState();
}

class _LuminismLightState extends State<LuminismLight>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late LuminismLightController _controller =
      widget.controller ?? LuminismLightController();
  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<AccelerometerEvent>? _sensor;
  Duration _last = Duration.zero;
  double _t = 0;
  bool _reduceMotion = false;
  Offset? _gravity;
  Offset? _baseline;

  bool get _sensorsSupported =>
      !isFlutterTest &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller._wake = _wake;
    _syncSensors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _wake();
  }

  @override
  void didUpdateWidget(LuminismLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller._wake = null;
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? LuminismLightController();
      _controller._wake = _wake;
    }
    if (widget.sensors != oldWidget.sensors) _syncSensors();
    _wake();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensor?.cancel();
    _ticker.dispose();
    _controller._wake = null;
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sensors cost battery; only listen while the app is on screen.
    if (state == AppLifecycleState.resumed) {
      _sensor?.resume();
    } else if (_sensor != null && !_sensor!.isPaused) {
      _sensor!.pause();
    }
  }

  void _syncSensors() {
    final bool want = widget.sensors && _sensorsSupported;
    if (want && _sensor == null) {
      _sensor = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onAccelerometer, onError: (Object _) {}, cancelOnError: false);
    } else if (!want && _sensor != null) {
      _sensor!.cancel();
      _sensor = null;
      _gravity = null;
      _baseline = null;
    }
  }

  // Gravity, smoothed, compared with a baseline that slowly follows it: the
  // light responds to tilting, not to how you happen to hold the phone.
  void _onAccelerometer(AccelerometerEvent e) {
    final Offset a = Offset(e.x, e.y);
    final Offset g = _gravity == null ? a : _gravity! + (a - _gravity!) * 0.15;
    final Offset b =
        _baseline == null ? g : _baseline! + (g - _baseline!) * 0.004;
    _gravity = g;
    _baseline = b;
    final Offset d = g - b;
    _controller.tilt = Offset(d.dx / 3.5, -d.dy / 3.5);
  }

  void _wake() {
    if (!mounted || _ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final double dt = _last == Duration.zero
        ? 0
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final LuminismLightController c = _controller;
    final bool drifting = widget.drift && !_reduceMotion;
    if (drifting) _t += dt * widget.driftSpeed;

    // Low-pass filter, so tilt never jitters.
    final double k = _reduceMotion ? 1 : 1 - math.exp(-dt * 8);
    c._tilt += (c._tiltTarget - c._tilt) * k;

    final double target = c._press != null ? 1 : 0;
    final double pk =
        _reduceMotion ? 1 : 1 - math.exp(-dt * (c._press != null ? 16 : 5));
    c._pressWeight += (target - c._pressWeight) * pk;
    if ((target - c._pressWeight).abs() < 0.001) c._pressWeight = target;

    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      final Size size = box.size;
      // Without drift the light rests at the top centre.
      final double driftX =
          drifting ? widget.driftAmplitude.dx * math.cos(_t) : 0;
      final double driftY =
          drifting ? widget.driftAmplitude.dy * math.sin(_t * 1.3) : 0;
      Offset light = box.localToGlobal(Offset(
        size.width * (0.5 + driftX + widget.tiltStrength.dx * c._tilt.dx),
        size.height * (0.3 + driftY + widget.tiltStrength.dy * c._tilt.dy),
      ));
      final Offset? pressed = c._lastPress;
      if (pressed != null && c._pressWeight > 0) {
        light = Offset.lerp(light, pressed, c._pressWeight)!;
      }
      c._setPosition(light);
    }

    final bool settled = !drifting &&
        (c._tiltTarget - c._tilt).distanceSquared < 1e-6 &&
        c._pressWeight == target;
    if (settled) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) =>
      _LightScope(controller: _controller, child: widget.child);
}

class _LightScope extends InheritedWidget {
  const _LightScope({required this.controller, required super.child});

  final LuminismLightController controller;

  @override
  bool updateShouldNotify(_LightScope oldWidget) =>
      controller != oldWidget.controller;
}
