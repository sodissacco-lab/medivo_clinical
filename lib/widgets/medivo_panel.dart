import 'package:flutter/material.dart';

import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';

/// A bordered card with a small capitalised label, e.g. ACCOUNT.
class MedivoPanel extends StatelessWidget {
  const MedivoPanel({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: MedivoText.label.copyWith(color: p.muted)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
