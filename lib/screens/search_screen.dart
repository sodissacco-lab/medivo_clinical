import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';
import '../widgets/medivo_app_bar.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: medivoAppBar(context, 'Search'),
      body: const ComingSoon(
        icon: Icons.search,
        phase: 6,
        message: 'One search across diseases, drugs, tests, guidelines and calculators, '
            'understanding abbreviations and synonyms such as HTN, high BP and Hb.',
      ),
    );
  }
}
