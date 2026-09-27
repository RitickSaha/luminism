import 'package:flutter/widgets.dart';

import 'light.dart';

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
  /// Without a [LuminismLight] above, a fixed light hangs over the top
  /// centre.
  Offset lightIn(Size size) {
    final RenderObject? box = context.findRenderObject();
    final LuminismLightController? light = _light;
    if (light == null || box is! RenderBox || !box.attached || !box.hasSize) {
      return Offset(size.width / 2, -size.height / 2);
    }
    return box.globalToLocal(light.position);
  }
}
