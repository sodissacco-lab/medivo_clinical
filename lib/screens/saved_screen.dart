import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';
import '../widgets/medivo_app_bar.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: medivoAppBar(context, 'Saved'),
      body: const ComingSoon(
        icon: Icons.bookmark_border,
        phase: 12,
        message: 'Bookmark diseases, drugs, guidelines and calculators, '
            'and organise them into your own folders.',
      ),
    );
  }
}
