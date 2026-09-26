import 'package:flutter/material.dart';

/// Medivo Clinical colour tokens, matching the brand system.
/// Read them anywhere with `context.palette`.
@immutable
class MedivoPalette extends ThemeExtension<MedivoPalette> {
  const MedivoPalette({
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.brand,
    required this.brandDeep,
    required this.accent,
    required this.tint,
    required this.alert,
    required this.line,
  });

  /// Page and screen background.
  final Color surface;

  /// Cards, sheets, search bar, category tiles.
  final Color surfaceRaised;

  /// Primary text.
  final Color ink;

  /// Secondary text: dates, captions, metadata.
  final Color muted;

  /// Medivo teal: primary actions, links, active tab.
  final Color brand;

  /// Headers and large brand fields (white text only).
  final Color brandDeep;

  /// Amber highlight. Never text on light grounds.
  final Color accent;

  /// Soft brand wash for selected rows and info panels.
  final Color tint;

  /// Reserved for Emergency, red flags and major interactions.
  final Color alert;

  /// Hairline dividers and card borders.
  final Color line;

  static const light = MedivoPalette(
    surface: Color(0xFFF7F5F0),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF14201F),
    muted: Color(0xFF52605E),
    brand: Color(0xFF0E5C57),
    brandDeep: Color(0xFF0A3F3C),
    accent: Color(0xFFE8A33D),
    tint: Color(0xFFD7EAE6),
    alert: Color(0xFFB8391F),
    line: Color(0xFFD9DDD8),
  );

  static const dark = MedivoPalette(
    surface: Color(0xFF0F1716),
    surfaceRaised: Color(0xFF182322),
    ink: Color(0xFFEEF2F0),
    muted: Color(0xFFA3B0AD),
    brand: Color(0xFF4FB8AC),
    brandDeep: Color(0xFF12504B),
    accent: Color(0xFFE8A33D),
    tint: Color(0xFF1F3A37),
    alert: Color(0xFFF07A5E),
    line: Color(0xFF2A3735),
  );

  @override
  MedivoPalette copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? muted,
    Color? brand,
    Color? brandDeep,
    Color? accent,
    Color? tint,
    Color? alert,
    Color? line,
  }) {
    return MedivoPalette(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      accent: accent ?? this.accent,
      tint: tint ?? this.tint,
      alert: alert ?? this.alert,
      line: line ?? this.line,
    );
  }

  @override
  MedivoPalette lerp(ThemeExtension<MedivoPalette>? other, double t) {
    if (other is! MedivoPalette) return this;
    return MedivoPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension MedivoPaletteContext on BuildContext {
  MedivoPalette get palette => Theme.of(this).extension<MedivoPalette>()!;
}
