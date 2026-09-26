import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';
import '../widgets/medivo_app_bar.dart';

class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: medivoAppBar(context, 'Recent'),
      body: const ComingSoon(
        icon: Icons.history,
        phase: 12,
        message: 'Everything you have recently viewed, with the option to clear your history.',
      ),
    );
  }
}
