import 'package:flutter/material.dart';

/// Typography expressed in logical pixels.
///
/// Flutter applies the user's text scaling through [MediaQuery]. Font sizes
/// must therefore remain stable instead of being multiplied by screen size.
abstract final class AppTextTheme {
  static const _family = 'Montserrat';

  static const light = TextTheme(
    displayLarge: TextStyle(fontFamily: _family, fontSize: 32),
    displayMedium: TextStyle(fontFamily: _family, fontSize: 28),
    displaySmall: TextStyle(fontFamily: _family, fontSize: 24),
    headlineLarge: TextStyle(fontFamily: _family, fontSize: 22),
    headlineMedium: TextStyle(fontFamily: _family, fontSize: 20),
    headlineSmall: TextStyle(fontFamily: _family, fontSize: 18),
    titleLarge: TextStyle(fontFamily: _family, fontSize: 18),
    titleMedium: TextStyle(fontFamily: _family, fontSize: 16),
    titleSmall: TextStyle(fontFamily: _family, fontSize: 14),
    bodyLarge: TextStyle(fontFamily: _family, fontSize: 16),
    bodyMedium: TextStyle(fontFamily: _family, fontSize: 14),
    bodySmall: TextStyle(fontFamily: _family, fontSize: 12),
    labelLarge: TextStyle(fontFamily: _family, fontSize: 14),
    labelMedium: TextStyle(fontFamily: _family, fontSize: 12),
    labelSmall: TextStyle(fontFamily: _family, fontSize: 11),
  );

  static const dark = light;
}
