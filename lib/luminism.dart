/// Luminism: surfaces lit by one shared light that drifts and follows the
/// phone's tilt.
///
/// Two materials share the light:
///
/// * [LuminSurface] and [LuminSwitch] – Luminism: surfaces that glow from
///   within and cast colored light instead of grey shadows.
/// * [PrismBendSurface] and [PrismBendSwitch] – Prism-bend: calm surfaces
///   whose edges split the light into a spectrum that turns as the light
///   moves.
///
/// Wrap your app in a [LuminismLight] so everything shares one light.
library;

export 'src/light.dart';
export 'src/surface.dart' show LuminSurface, PrismBendSurface;
export 'src/switch.dart';
