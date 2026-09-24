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
      textTheme: _scaleUp(ThemeData(brightness: brightness).textTheme),
    );
  }

  /// A 5% font-size bump for child-mode, done manually instead of via TextTheme.apply(fontSizeFactor:),
  /// because that helper trips an assertion in text_style.dart on any style in the base TextTheme whose
  /// fontSize is null.
  static TextTheme _scaleUp(TextTheme t) => TextTheme(
        displayLarge: _scaleStyle(t.displayLarge),
        displayMedium: _scaleStyle(t.displayMedium),
        displaySmall: _scaleStyle(t.displaySmall),
        headlineLarge: _scaleStyle(t.headlineLarge),
        headlineMedium: _scaleStyle(t.headlineMedium),
        headlineSmall: _scaleStyle(t.headlineSmall),
        titleLarge: _scaleStyle(t.titleLarge),
        titleMedium: _scaleStyle(t.titleMedium),
        titleSmall: _scaleStyle(t.titleSmall),
        bodyLarge: _scaleStyle(t.bodyLarge),
        bodyMedium: _scaleStyle(t.bodyMedium),
        bodySmall: _scaleStyle(t.bodySmall),
        labelLarge: _scaleStyle(t.labelLarge),
        labelMedium: _scaleStyle(t.labelMedium),
        labelSmall: _scaleStyle(t.labelSmall),
      );

  static TextStyle? _scaleStyle(TextStyle? style) {
    final double? size = style?.fontSize;
    return size == null ? style : style!.copyWith(fontSize: size * 1.05);
  }
}
