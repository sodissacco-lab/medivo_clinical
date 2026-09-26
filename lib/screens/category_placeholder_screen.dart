import 'package:flutter/material.dart';

import '../data/home_categories.dart';
import '../widgets/coming_soon.dart';
import '../widgets/medivo_app_bar.dart';

/// Opened from a Home card until that module is built.
class CategoryPlaceholderScreen extends StatelessWidget {
  const CategoryPlaceholderScreen({super.key, required this.category});

  final HomeCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: medivoAppBar(context, category.title),
      body: ComingSoon(
        icon: category.icon,
        phase: category.phase,
        message: category.summary,
      ),
    );
  }
}
