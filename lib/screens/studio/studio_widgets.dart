import 'package:flutter/material.dart';

import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';

/// Coloured label for a workflow stage.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color background, Color foreground) = switch (status) {
      'published' => (p.brand, Theme.of(context).colorScheme.onPrimary),
      'approved' => (p.tint, p.brand),
      'editor_review' || 'peer_review' || 'clinical_approval' => (p.accent, const Color(0xFF14201F)),
      'archived' || 'superseded' => (p.line, p.muted),
      _ => (p.surface, p.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status == 'draft' ? p.line : background),
      ),
      child: Text(label.toUpperCase(),
          style: MedivoText.label.copyWith(color: foreground, letterSpacing: 0.4)),
    );
  }
}

String formatDate(DateTime? date) {
  if (date == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
