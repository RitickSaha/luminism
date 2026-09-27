# Luminism

Surfaces lit by one shared light that drifts, follows the phone's tilt and
answers touch. Two materials share the light:

- **Luminism**: surfaces glow from within, brightest toward the light, and
  cast their own color instead of grey shadows.
- **Prism-bend**: calm, clear surfaces whose edges split the light into a
  soft spectrum on the side facing the light.

Both come in light and dark versions and follow your app's theme.

## How the light moves

Phones have no hover. The light sits above the screen, like a lamp in the
room, and four things move it:

| Input | What happens |
| --- | --- |
| Drift | The light moves slowly on its own, like a phone held in the hand. |
| Tilt | The motion sensors steer the light, smoothed so it never jitters. |
| Scroll | Surfaces travel under the light, so their glow and edges shift. |
| Touch | Pressing a surface pulls the light to the finger, then it drifts back. |

With "reduce motion" on, the light rests at the top of the screen.

## Usage

Put one light over your app:

```dart
import 'package:luminism/luminism.dart';

MaterialApp(
  builder: (context, child) => LuminismLight(child: child!),
  home: const HomeScreen(),
)
```

Then use either material anywhere below it:

```dart
LuminSurface(
  color: Colors.deepOrange, // only the hue is used
  child: const Text('5.2 km'),
)

LuminSurface(
  color: Colors.deepOrange,
  bright: true, // a saturated fill for primary buttons
  child: const Text('Start a workout'),
)

PrismBendSurface(child: const Text('7h 40m'))
```

### Options

| `LuminismLight` | Default | |
| --- | --- | --- |
| `drift` | `true` | Whether the light drifts on its own. |
| `sensors` | `true` | Whether the motion sensors steer it. Used on Android, iOS and the web; never under `flutter test`. |
| `driftSpeed`, `driftAmplitude` | `0.5`, `(0.32, 0.2)` | How fast and how far it drifts. |
| `tiltStrength` | `(0.45, 0.35)` | How far a full tilt moves it. |
| `controller` | | A `LuminismLightController` to read the light or steer it by hand. |

Steer the light yourself, for example on a simulator without a gyroscope:

```dart
final light = LuminismLightController();
LuminismLight(controller: light, child: app);
light.tilt = const Offset(0.6, -0.2); // -1..1 on each axis
```

Both surfaces take `borderRadius`, `padding` and `brightness` (to override
the theme). `PrismBendSurface` also takes a fill `color` and `edgeWidth`.

## Performance

The light only repaints the surfaces' backgrounds: their content sits in a
`RepaintBoundary`. Sensors pause while the app is in the background.

## Example

`example/` is a phone demo with both materials, light and dark themes, and
a tilt pad for simulators.
