import 'package:flutter/material.dart';

/// Medivo Clinical type scale, matching the brand system.
/// Colours are added where the style is used, e.g.
/// `MedivoText.body.copyWith(color: context.palette.ink)`.
class MedivoText {
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'IBMPlexMono';

  static const display = TextStyle(
      fontFamily: sans, fontSize: 40, height: 44 / 40, fontWeight: FontWeight.w800);
  static const title = TextStyle(
      fontFamily: sans, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700);
  static const heading = TextStyle(
      fontFamily: sans, fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700);
  static const body = TextStyle(
      fontFamily: sans, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const bodySm = TextStyle(
      fontFamily: sans, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const label = TextStyle(
      fontFamily: sans,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8);

  /// Doses, lab ranges and calculator results only.
  static const value = TextStyle(
      fontFamily: mono, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w500);
}
