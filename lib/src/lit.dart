import 'package:flutter/widgets.dart';

import 'light.dart';

/// How far outside a widget's edge a hovering pointer still leads its
/// light, in logical pixels.
const double pointerReach = 60;

/// How strongly a pointer at [local] leads the light of a widget of [size]:
/// 1 inside it, easing to 0 at [pointerReach] outside its edge.
@visibleForTesting
double pointerInfluence(Offset local, Size size) {
  final double dx = local.dx < 0
      ? -local.dx
      : (local.dx > size.width ? local.dx - size.width : 0);
  final double dy = local.dy < 0
      ? -local.dy
      : (local.dy > size.height ? local.dy - size.height : 0);
  final double t = (1 - Offset(dx, dy).distance / pointerReach).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t); // smoothstep, so the edge is soft
}

/// Gives a widget's state the shared light: where it is, and when to
/// repaint because the light moved or the widget scrolled under it.
mixin LitState<T extends StatefulWidget> on State<T> {
  LuminismLightController? _light;
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _light = LuminismLight.maybeOf(context);
    _scroll = Scrollable.maybeOf(context)?.position;
  }

  /// Notifies when the light moves or this widget scrolls.
  Listenable get lightRepaint =>
      Listenable.merge(<Listenable?>[_light, _scroll]);

  /// Where the light is, in this widget's own coordinates.
  ///
  /// A hovering pointer only leads the light of widgets under it or within
  /// [pointerReach] of their edge, so moving the mouse doesn't stir the
  /// whole screen. Without a [LuminismLight] above, a fixed light hangs
  /// over the top centre.
  Offset lightIn(Size size) {
    final RenderObject? box = context.findRenderObject();
    final LuminismLightController? light = _light;
    if (light == null || box is! RenderBox || !box.attached || !box.hasSize) {
      return Offset(size.width / 2, -size.height / 2);
    }
    final Offset ambient = box.globalToLocal(light.position);
    final Offset? pointer = light.pointer;
    if (pointer == null) return ambient;
    final Offset local = box.globalToLocal(pointer);
    final double influence =
        light.pointerWeight * pointerInfluence(local, size);
    return influence == 0 ? ambient : Offset.lerp(ambient, local, influence)!;
  }
}
