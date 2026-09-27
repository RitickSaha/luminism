/// Luminism: surfaces lit by one shared light that drifts, follows the
/// phone's tilt and answers touch.
///
/// Two materials share the light:
///
/// * [LuminSurface] – Luminism: surfaces that glow from within and cast
///   colored light instead of grey shadows.
/// * [PrismBendSurface] – Prism-bend: calm surfaces whose edges split the
///   light into a spectrum that turns as the light moves.
///
/// Wrap your app in a [LuminismLight] so every surface shares one light.
library;

export 'src/light.dart';
export 'src/surface.dart' hide prismBandRotation;
