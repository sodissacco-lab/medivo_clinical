import 'package:flutter/material.dart';

import 'medivo_palette.dart';
import 'medivo_text.dart';

class MedivoTheme {
  static ThemeData light() => _build(MedivoPalette.light, Brightness.light);
  static ThemeData dark() => _build(MedivoPalette.dark, Brightness.dark);

  static ThemeData _build(MedivoPalette p, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final onBrand = isLight ? Colors.white : const Color(0xFF0F1716);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.brand,
      onPrimary: onBrand,
      secondary: p.accent,
      onSecondary: const Color(0xFF14201F),
      error: p.alert,
      onError: onBrand,
      surface: p.surfaceRaised,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: MedivoText.sans,
      scaffoldBackgroundColor: p.surface,
      dividerColor: p.line,
      extensions: <ThemeExtension<dynamic>>[p],
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceRaised,
        indicatorColor: p.tint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
