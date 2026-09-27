import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luminism/luminism.dart';

void main() => runApp(const LuminismDemoApp());

/// The two materials the demo can show.
enum SurfaceStyle { luminism, prismBend }

class LuminismDemoApp extends StatefulWidget {
  const LuminismDemoApp({super.key, this.sensors = true});

  /// Whether the phone's motion sensors steer the light.
  final bool sensors;

  @override
  State<LuminismDemoApp> createState() => _LuminismDemoAppState();
}

class _LuminismDemoAppState extends State<LuminismDemoApp> {
  final LuminismLightController _light = LuminismLightController();
  ThemeMode _themeMode = ThemeMode.system;
  SurfaceStyle _material = SurfaceStyle.luminism;

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness b) => ThemeData(
        brightness: b,
        fontFamily: 'Figtree',
        colorSchemeSeed: const Color(0xFF3346D3),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luminism',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      // One light for the whole app.
      builder: (context, child) => LuminismLight(
        controller: _light,
        sensors: widget.sensors,
        child: child!,
      ),
      home: HomeScreen(
        light: _light,
        material: _material,
        themeMode: _themeMode,
        onMaterial: (m) => setState(() => _material = m),
        onThemeMode: (m) => setState(() => _themeMode = m),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.light,
    required this.material,
    required this.themeMode,
    required this.onMaterial,
    required this.onThemeMode,
  });

  final LuminismLightController light;
  final SurfaceStyle material;
  final ThemeMode themeMode;
  final ValueChanged<SurfaceStyle> onMaterial;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool lumin = material == SurfaceStyle.luminism;
    final Color background = lumin
        ? (dark ? const Color(0xFF0D0E13) : const Color(0xFFEEF0F5))
        : (dark ? const Color(0xFF0B0C10) : const Color(0xFFEDF0F5));
    final Color ink = dark ? const Color(0xFFF1F2F6) : const Color(0xFF111318);
    final TextTheme text =
        Theme.of(context).textTheme.apply(bodyColor: ink, displayColor: ink);

    Widget surface(
        {required Color hue,
        required Widget child,
        bool primary = false,
        EdgeInsets? padding}) {
      final EdgeInsets p = padding ?? const EdgeInsets.all(16);
      if (lumin) {
        return LuminSurface(
            color: hue, bright: primary, padding: p, child: child);
      }
      return PrismBendSurface(
        color: primary
            ? (dark ? const Color(0xFFF1F2F6) : const Color(0xFF111318))
            : null,
        padding: p,
        child: child,
      );
    }

    Color onPrimary() => lumin
        ? const Color(0xFF1A0D05)
        : (dark ? const Color(0xFF0B0C10) : Colors.white);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SegmentedButton<SurfaceStyle>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<SurfaceStyle>>[
                          ButtonSegment<SurfaceStyle>(
                              value: SurfaceStyle.luminism,
                              label: Text('Luminism')),
                          ButtonSegment<SurfaceStyle>(
                              value: SurfaceStyle.prismBend,
                              label: Text('Prism-bend')),
                        ],
                        selected: <SurfaceStyle>{material},
                        onSelectionChanged: (s) => onMaterial(s.first),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Theme: ${themeMode.name}',
                      onPressed: () => onThemeMode(ThemeMode.values[
                          (themeMode.index + 1) % ThemeMode.values.length]),
                      icon: Icon(
                        switch (themeMode) {
                          ThemeMode.system => Icons.brightness_auto,
                          ThemeMode.light => Icons.light_mode,
                          ThemeMode.dark => Icons.dark_mode,
                        },
                        color: ink,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tilt pad',
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => TiltPad(light: light),
                      ),
                      icon: Icon(Icons.screen_rotation_alt, color: ink),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: <Widget>[
                    Text('Saturday evening',
                        style: text.bodyMedium
                            ?.copyWith(color: ink.withAlpha(170))),
                    Text('Good evening, Maya',
                        style: text.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    surface(
                      hue: const Color(0xFFFF7A1A),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('EVENING RUN',
                              style: text.labelMedium?.copyWith(
                                  letterSpacing: 1, color: ink.withAlpha(190))),
                          Text('5.2 km',
                              style: text.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text('32 min · 6′09″ per km',
                              style: text.bodyMedium
                                  ?.copyWith(color: ink.withAlpha(190))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                            child: surface(
                                hue: const Color(0xFF6B4DFF),
                                child: _Stat(
                                    label: 'Sleep',
                                    value: '7h 40m',
                                    text: text,
                                    ink: ink))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: surface(
                                hue: const Color(0xFF12C8A0),
                                child: _Stat(
                                    label: 'Focus',
                                    value: '3 sessions',
                                    text: text,
                                    ink: ink))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Workout started')),
                        );
                      },
                      child: surface(
                        hue: const Color(0xFFFF7A1A),
                        primary: true,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('Start a workout',
                              style: text.titleMedium?.copyWith(
                                  color: onPrimary(),
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    surface(
                      hue: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                              child:
                                  Text('Quiet hours', style: text.titleMedium)),
                          _QuietSwitch(lumin: lumin),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('THIS WEEK',
                        style: text.labelMedium?.copyWith(
                            letterSpacing: 1, color: ink.withAlpha(160))),
                    const SizedBox(height: 10),
                    for (final (String day, String value, Color hue)
                        in const <(String, String, Color)>[
                      ('Tue · Yoga', '45 min', Color(0xFFD14DFF)),
                      ('Thu · Run', '4.1 km', Color(0xFFFF7A1A)),
                      ('Sat · Ride', '18 km', Color(0xFF12B7C8)),
                      ('Sun · Swim', '1.2 km', Color(0xFF3D7BFF)),
                    ]) ...<Widget>[
                      surface(
                        hue: hue,
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text(day, style: text.titleMedium)),
                            Text(value,
                                style: text.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: surface(
                    hue: const Color(0xFF4D63FF),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Icon(Icons.home_rounded,
                            color: lumin ? const Color(0xFF8E9BFF) : ink),
                        Icon(Icons.show_chart_rounded,
                            color: ink.withAlpha(130)),
                        Icon(Icons.add_rounded, color: ink.withAlpha(130)),
                        Icon(Icons.person_outline_rounded,
                            color: ink.withAlpha(130)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.text,
      required this.ink});

  final String label;
  final String value;
  final TextTheme text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: text.bodyMedium?.copyWith(color: ink.withAlpha(190))),
        const SizedBox(height: 2),
        Text(value,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _QuietSwitch extends StatefulWidget {
  const _QuietSwitch({required this.lumin});

  /// Whether to use the Luminism switch rather than the Prism-bend one.
  final bool lumin;

  @override
  State<_QuietSwitch> createState() => _QuietSwitchState();
}

class _QuietSwitchState extends State<_QuietSwitch> {
  bool _on = true;

  void _set(bool v) => setState(() => _on = v);

  @override
  Widget build(BuildContext context) => widget.lumin
      ? LuminSwitch(value: _on, onChanged: _set)
      : PrismBendSwitch(value: _on, onChanged: _set);
}

/// Steers the light by hand, for simulators and emulators without a
/// gyroscope.
class TiltPad extends StatefulWidget {
  const TiltPad({super.key, required this.light});

  final LuminismLightController light;

  @override
  State<TiltPad> createState() => _TiltPadState();
}

class _TiltPadState extends State<TiltPad> {
  static const double _size = 180;

  void _set(Offset local) {
    const double r = _size / 2;
    Offset t = (local - const Offset(r, r)) / (r - 16);
    if (t.distance > 1) t = t / t.distance;
    setState(() => widget.light.tilt = t);
  }

  @override
  Widget build(BuildContext context) {
    final Offset t = widget.light.tilt;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Drag to tilt. On a phone, the gyroscope does this for you.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            GestureDetector(
              onPanDown: (d) => _set(d.localPosition),
              onPanUpdate: (d) => _set(d.localPosition),
              child: Container(
                key: const Key('tilt-pad'),
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline),
                ),
                child: Align(
                  alignment: Alignment(
                      t.dx * (1 - 32 / _size), t.dy * (1 - 32 / _size)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: colors.primary, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => widget.light.tilt = Offset.zero),
              child: const Text('Hold level'),
            ),
          ],
        ),
      ),
    );
  }
}
