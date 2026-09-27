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

    OutlineInputBorder border(Color colour, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colour, width: width),
        );

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const buttonText = TextStyle(
        fontFamily: MedivoText.sans, fontSize: 16, fontWeight: FontWeight.w700);

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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        labelStyle: TextStyle(color: p.muted),
        floatingLabelStyle: TextStyle(color: p.brand),
        helperStyle: TextStyle(color: p.muted),
        border: border(p.line),
        enabledBorder: border(p.line),
        focusedBorder: border(p.brand, 2),
        errorBorder: border(p.alert),
        focusedErrorBorder: border(p.alert, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          foregroundColor: p.brand,
          side: BorderSide(color: p.line),
          textStyle: buttonText,
        ),
      ),
      // Readable selected segments in both themes (e.g. Edit / Preview, SI / Conventional).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: p.ink,
          selectedForegroundColor: p.ink,
          selectedBackgroundColor: p.tint,
          side: BorderSide(color: p.line),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: p.tint,
        labelStyle: TextStyle(color: p.ink),
        side: BorderSide(color: p.line),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.brand),
      ),
    );
  }
}