# Luminism

Surfaces lit by one shared light that drifts and follows the phone's tilt.
Two materials share the light:

- **Luminism**: surfaces glow from within, brightest toward the light, and
  cast their own color instead of grey shadows.
- **Prism-bend**: calm, clear surfaces whose edges split the light into a
  soft spectrum on the side facing the light.

Each material comes with a surface and a matching switch, in light and dark
versions that follow your app's theme.

## How the light moves

The light sits above the screen, like a lamp in the room, and these move
it:

| Input | What happens |
| --- | --- |
| Drift | The light moves slowly on its own, like a phone held in the hand. |
| Tilt | Turning the phone moves the light at once, like the sheen on a card in a wallet app. The gyroscope leads; phones without one use the accelerometer. Held still, the light eases back to the centre. |
| Scroll | Surfaces travel under the light, so their glow and edges shift. |
| Mouse and trackpad | On desktop and the web, a hovering pointer lights the surface under it (and fades out within 60 px of its edge). Other surfaces keep the ambient light. Touch never moves it. |

With "reduce motion" on, the light rests at the top of the screen.

## Platform setup

**iOS**: the motion sensors need a usage description, or the app crashes
when it starts reading them. Add this to `ios/Runner/Info.plist`:

```xml
<key>NSMotionUsageDescription</key>
<string>Tilting your phone moves the light across the screen.</string>
```

**Android**: nothing to add.

If you'd rather not use the sensors, pass `sensors: false` to
`LuminismLight`; the light still drifts and moves with scroll.

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

Each material has a switch lit by the same light:

```dart
LuminSwitch(value: quiet, onChanged: (v) => setState(() => quiet = v))
PrismBendSwitch(value: quiet, onChanged: (v) => setState(() => quiet = v))
```

`LuminSwitch` glows in its `color` (mint by default) when on.
`PrismBendSwitch` fills with a spectrum that turns to face the light. Both
are 48 × 48 touch targets, work with the keyboard, and tell screen readers
whether they're on.

### Options

| `LuminismLight` | Default | |
| --- | --- | --- |
| `drift` | `true` | Whether the light drifts on its own. |
| `sensors` | `true` | Whether the motion sensors steer it. Used on Android, iOS and the web; never under `flutter test`. |
| `driftSpeed`, `driftAmplitude` | `0.5`, `(0.32, 0.2)` | How fast and how far it drifts. |
| `tiltStrength` | `(0.45, 0.35)` | How far a full tilt moves it. |
| `followPointer` | `true` | Whether a hovering mouse or trackpad lights the surface under it. |
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
a tilt pad for simulators. It runs on Android, iOS, the web and macOS.
