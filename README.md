<h1 align="center">Luminism ✨</h1>

<p align="center">
  <a href="https://pub.dev/packages/luminism"><img src="https://img.shields.io/pub/v/luminism.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/luminism/score"><img src="https://img.shields.io/pub/likes/luminism" alt="pub likes"></a>
  <a href="https://pub.dev/packages/luminism/score"><img src="https://img.shields.io/pub/points/luminism" alt="pub points"></a>
  <a href="https://github.com/RitickSaha/luminism/actions/workflows/ci.yml"><img src="https://github.com/RitickSaha/luminism/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

A Flutter package for surfaces lit by one shared light. The light drifts on
its own and follows the phone as it turns, like the sheen on a card in a
wallet app. Two materials share it:

- **Luminism**: surfaces glow from within, brightest toward the light, and
  cast their own color instead of grey shadows.
- **Prism-bend**: calm, clear surfaces whose edges split the light into a
  soft spectrum on the side facing it.

<p align="center">
  <img src="https://raw.githubusercontent.com/RitickSaha/luminism/main/screenshots/light.webp" alt="Luminism and Prism-bend in dark and light themes, with the light drifting across the surfaces" width="100%"/>
</p>

<p align="center"><sub>Luminism and Prism-bend, dark and light, as the light drifts (sped up 1.5×).</sub></p>

## Features

- One light for the whole app, shared by every surface below it
- The light drifts on its own, so the screen feels alive even at rest
- Turning the phone steers the light at once, led by the gyroscope
- Surfaces move under the light as they scroll
- On desktop and the web, a hovering mouse lights the surface under it
- Two materials, each with a surface and a matching switch
- Light and dark versions that follow your app's theme
- Respects "reduce motion", and repaints only backgrounds, never content

## Getting started

```sh
flutter pub add luminism
```

```dart
import 'package:luminism/luminism.dart';
```

### iOS

The motion sensors need a usage description, or the app crashes when it
starts reading them. Add this to `ios/Runner/Info.plist`:

```xml
<key>NSMotionUsageDescription</key>
<string>Tilting your phone moves the light across the screen.</string>
```

Android and the web need nothing extra. If you'd rather not use the
sensors, pass `sensors: false` to `LuminismLight`; the light still drifts
and moves with scroll.

## Usage

### One light over your app

Put a `LuminismLight` above everything, so every surface shares it:

```dart
MaterialApp(
  builder: (context, child) => LuminismLight(child: child!),
  home: const HomeScreen(),
)
```

### Luminism surface

The surface glows in the hue of `color`. Only the hue is used: the style
picks lightness and saturation for light and dark themes, so any color
looks right in both.

```dart
LuminSurface(
  color: Colors.deepOrange,
  child: const Text('5.2 km'),
)
```

### Primary button

`bright: true` gives a saturated fill for the one action that matters most
on the screen:

```dart
GestureDetector(
  onTap: startWorkout,
  child: LuminSurface(
    color: Colors.deepOrange,
    bright: true,
    child: const Center(child: Text('Start a workout')),
  ),
)
```

### Prism-bend surface

A clear surface whose edge splits the light into a spectrum. The spectrum
covers the same length of edge wherever the light is, and turns with it.

```dart
PrismBendSurface(
  child: const Text('7h 40m'),
)
```

### Switches

Each material has a switch lit by the same light:

```dart
LuminSwitch(
  value: quiet,
  onChanged: (value) => setState(() => quiet = value),
)

PrismBendSwitch(
  value: quiet,
  onChanged: (value) => setState(() => quiet = value),
)
```

`LuminSwitch` glows in its `color` (mint by default) when on.
`PrismBendSwitch` fills with a spectrum that turns to face the light. Both
are 48 × 48 touch targets, work with the keyboard, and tell screen readers
whether they're on. Pass `onChanged: null` to disable them.

### Steering the light yourself

Simulators have no gyroscope. Steer the light with a controller instead:

```dart
final light = LuminismLightController();

LuminismLight(controller: light, child: app);

light.tilt = const Offset(0.6, -0.2); // -1 to 1 on each axis
```

The controller is a `ChangeNotifier`, so you can also listen to it and read
where the light is (`position`, in screen coordinates).

See the [example app](example/lib/main.dart) for all of the above.

## How the light moves

The light sits above the screen, like a lamp in the room:

| Input | What happens |
| --- | --- |
| Drift | The light moves slowly on its own, like a phone held in the hand. |
| Turning the phone | The light moves at once, by how far the phone turned, like the sheen on a card in a wallet app. Held still, it eases back to the centre, so how you hold the phone doesn't matter. The gyroscope leads; phones without one use the accelerometer. |
| Scroll | Surfaces travel under the light, so their glow and edges shift. |
| Mouse and trackpad | On desktop and the web, a hovering pointer lights the surface under it, fading out within 60 px of its edge. Other surfaces keep the ambient light. |
| Touch | Never moves the light, so tapping stays calm. |
| Reduce motion | The light rests near the top of the screen. |

## Parameters

### `LuminismLight`

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `child` | `Widget` | | **Required.** The subtree the light shines on. |
| `controller` | `LuminismLightController?` | | Reads the light or steers it by hand. One is created if you don't pass it. |
| `drift` | `bool` | `true` | Whether the light drifts on its own. |
| `sensors` | `bool` | `true` | Whether the motion sensors steer it. Used on Android, iOS and the web; never under `flutter test`. |
| `driftSpeed` | `double` | `0.5` | How fast the light drifts, in radians per second along its path. |
| `driftAmplitude` | `Offset` | `(0.32, 0.2)` | How far it drifts, as a fraction of the screen's width and height. |
| `tiltStrength` | `Offset` | `(0.45, 0.35)` | How far a full tilt moves it, as a fraction of the screen's width and height. |
| `followPointer` | `bool` | `true` | Whether a hovering mouse or trackpad lights the surface under it. |

### `LuminSurface`

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `color` | `Color` | | **Required.** The hue of the glow. Only the hue is used. |
| `child` | `Widget?` | | The content. |
| `bright` | `bool` | `false` | A bright, saturated fill, for primary buttons. |
| `borderRadius` | `double` | `22` | The corner radius. |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(16)` | Space around the child. |
| `brightness` | `Brightness?` | | Overrides the theme's brightness. |

### `PrismBendSurface`

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `child` | `Widget?` | | The content. |
| `color` | `Color?` | | The fill. Defaults to near-white, or graphite in dark themes. |
| `edgeWidth` | `double` | `1.5` | The width of the spectrum edge. |
| `borderRadius` | `double` | `22` | The corner radius. |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(16)` | Space around the child. |
| `brightness` | `Brightness?` | | Overrides the theme's brightness. |

### `LuminSwitch` and `PrismBendSwitch`

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `value` | `bool` | | **Required.** Whether the switch is on. |
| `onChanged` | `ValueChanged<bool>?` | | **Required.** Called with the new value when tapped. `null` disables the switch. |
| `color` | `Color` | mint | `LuminSwitch` only. The hue of the glow when on. |
| `brightness` | `Brightness?` | | Overrides the theme's brightness. |

## Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/RitickSaha/luminism/main/screenshots/overview.png" alt="The example app: Luminism dark and light, then Prism-bend dark and light" width="100%"/>
</p>

## Platforms

| Platform | What moves the light |
| --- | --- |
| Android, iOS | Drift, scroll, and the gyroscope (or accelerometer) as the phone turns. |
| Web | Drift, scroll and mouse hover; motion sensors where the browser allows them. |
| Desktop | Drift, scroll and mouse hover. |

Surfaces also work without a `LuminismLight` above them: they're lit from
above, and the light doesn't move.

## Performance

The light repaints only the surfaces' backgrounds: their content sits in a
`RepaintBoundary`, so text and images are never repainted by it. The light
stops ticking when nothing moves (with drift off and the phone still), and
the sensors pause while the app is in the background.

## Social handles

- _Official_
  - [_GitHub_](https://www.github.com/riticksaha)
  - [_Instagram_](https://www.instagram.com/theflutterfoundry/)
  - [_Twitter_](https://twitter.com/flutterfoundry/)
  - [_YouTube_](https://www.youtube.com/channel/UCH7gICVJpoZPRV6h9O6Xu4g)
- _Personal_
  - [Instagram](https://www.instagram.com/riticksaha_/)
  - [Twitter](https://www.twitter.com/rsahatwt/)

<img src="https://raw.githubusercontent.com/RitickSaha/glassmorphism/master/images/theFlutterFoundary.jpeg" align="left" height="48" width="48">

[The Flutter Foundry 💙](https://www.instagram.com/theflutterfoundry)

<br clear="left">

If you found this project useful, please consider giving it a ⭐️ on GitHub
and sharing it with your friends.

## Contributing

Suggestions and bug reports are welcome. Please open a
[GitHub issue](https://github.com/RitickSaha/luminism/issues).

Before sending a pull request, run:

```sh
dart format lib test example/lib example/test
flutter analyze
flutter test
```

## License

[MIT](LICENSE)
