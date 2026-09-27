## 0.1.0

- First release: `LuminismLight`, with two materials that share its light:
  - Luminism: `LuminSurface` and `LuminSwitch`.
  - Prism-bend: `PrismBendSurface` and `PrismBendSwitch`.
- Light and dark versions that follow the app's theme.
- Prism-bend's spectrum covers the same length of edge wherever the light
  is, so it stays compact at corners and on short sides.
- The light drifts on its own, moves with scroll and follows the phone as
  it turns: the gyroscope leads, so it keeps up like a card in a wallet
  app, with the accelerometer as a fallback. On desktop and the web a hovering mouse or trackpad lights
  the surface under it, while the others keep the ambient light; touch never
  moves it. It rests with "reduce motion" on.
- Example app for Android, iOS, the web and macOS.
