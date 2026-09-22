import 'package:flutter/material.dart';

/// Material 3 theme, light and dark. One seed color keeps both palettes in sync.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF2E6F6B);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
    return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: scheme.surface);
  }

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: scheme.surface);
  }

  /// A visibly different, playful accent used only inside child-mode screens, so a child can tell at a
  /// glance that they are in "their" part of the app.
  static ThemeData child(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFEF7C3B), brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: ThemeData(brightness: brightness).textTheme.apply(fontSizeFactor: 1.05),
    );
  }
}
