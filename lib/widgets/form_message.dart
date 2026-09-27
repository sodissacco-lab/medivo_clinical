import 'package:flutter/material.dart';

import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';

/// An error or information message shown above a form's button.
class FormMessage extends StatelessWidget {
  const FormMessage({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colour = isError ? p.alert : p.brand;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? p.surfaceRaised : p.tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: colour, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: MedivoText.bodySm.copyWith(color: p.ink)),
          ),
        ],
      ),
    );
  }
}
