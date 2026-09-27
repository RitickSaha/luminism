import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Turns motion sensor readings into a tilt from -1 to 1 on each axis.
///
/// The gyroscope leads, like the sheen on a card in a wallet app: turning
/// the phone moves the light at once, by how far it turned. Held still, the
/// light eases back to the centre, so it responds to tilting, not to how the
/// phone happens to be held. Phones without a gyroscope fall back to the
/// accelerometer, which is slower and only sees tipping, not turning.
class TiltTracker {
  /// How far the phone turns, in radians, for a full tilt (about 16°).
  static const double fullTurn = 0.28;

  /// How long the light takes to settle back to the centre, in seconds.
  static const double settle = 4;

  /// How long after the last gyroscope reading the accelerometer takes over.
  static const Duration gyroTimeout = Duration(milliseconds: 500);

  Offset _turn = Offset.zero;
  Offset _bias = Offset.zero;
  Duration? _gyroAt;
  Offset? _gravity;
  Offset? _baseline;

  /// Whether the gyroscope has been heard from recently at [now].
  bool gyroActive(Duration now) =>
      _gyroAt != null && now - _gyroAt! < gyroTimeout;

  /// Adds a gyroscope reading, in rad/s around the device's x and y axes,
  /// taken at [now]. Returns the new tilt.
  Offset gyroscope(double x, double y, Duration now) {
    final Duration? last = _gyroAt;
    _gyroAt = now;
    if (last == null) return _tilt;
    final double dt = ((now - last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    Offset rate = Offset(y, x);
    // Gyroscopes read a small, steady rate even at rest. Learn it while the
    // phone is still, so the light doesn't creep.
    if ((rate - _bias).distance < 0.03) {
      _bias += (rate - _bias) * (1 - math.exp(-dt / 1.5));
    }
    rate -= _bias;
    final Offset turn = (_turn - rate * dt) * math.exp(-dt / settle);
    // Clamped, so turning back responds at once after turning too far.
    _turn = Offset(
      turn.dx.clamp(-fullTurn, fullTurn),
      turn.dy.clamp(-fullTurn, fullTurn),
    );
    return _tilt;
  }

  /// Adds an accelerometer reading in m/s², taken at [now]. Returns the new
  /// tilt, or null while the gyroscope leads.
  Offset? accelerometer(double x, double y, Duration now) {
    // Gravity, smoothed, compared with a baseline that slowly follows it.
    final Offset a = Offset(x, y);
    final Offset g = _gravity == null ? a : _gravity! + (a - _gravity!) * 0.3;
    final Offset b =
        _baseline == null ? g : _baseline! + (g - _baseline!) * 0.004;
    _gravity = g;
    _baseline = b;
    if (gyroActive(now)) return null;
    final Offset d = g - b;
    // 9.81 m/s² per radian near level, so this matches the gyroscope.
    return Offset(d.dx, -d.dy) / (9.81 * fullTurn);
  }

  Offset get _tilt => _turn / fullTurn;
}
