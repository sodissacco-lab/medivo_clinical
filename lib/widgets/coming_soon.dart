import 'package:flutter/material.dart';

import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';

/// Placeholder shown where a module will be built in a later phase.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.phase,
    required this.message,
  });

  final IconData icon;
  final int phase;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: p.tint, shape: BoxShape.circle),
              child: Icon(icon, color: p.brand, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Coming in Phase $phase',
                textAlign: TextAlign.center,
                style: MedivoText.heading.copyWith(color: p.ink)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: MedivoText.bodySm.copyWith(color: p.muted)),
          ],
        ),
      ),
    );
  }
}
