import 'dart:io' show Platform;

/// Whether code runs under `flutter test`, where no sensor plugins exist.
bool get isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
