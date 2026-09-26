import 'package:flutter/material.dart';

import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';

/// Flat Medivo app bar: page background, ink title, no shadow.
PreferredSizeWidget medivoAppBar(BuildContext context, String title) {
  final p = context.palette;
  return AppBar(
    title: Text(title, style: MedivoText.heading.copyWith(color: p.ink)),
    backgroundColor: p.surface,
    foregroundColor: p.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}
