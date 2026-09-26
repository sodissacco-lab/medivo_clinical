import 'package:flutter/material.dart';

import '../data/home_categories.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/medivo_mark.dart';
import 'category_placeholder_screen.dart';

/// Home dashboard (blueprint §5–7): header, universal search, category cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Header
          Row(
            children: [
              const MedivoMark(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome', style: MedivoText.heading.copyWith(color: p.ink)),
                    Text('Clinical Companion',
                        style: MedivoText.bodySm.copyWith(color: p.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Me',
                onPressed: onOpenProfile,
                icon: Icon(Icons.account_circle_outlined, color: p.ink, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Universal search (opens the Search tab)
          _SearchBox(onTap: onOpenSearch),
          const SizedBox(height: 24),

          Text('BROWSE', style: MedivoText.label.copyWith(color: p.muted)),
          const SizedBox(height: 8),

                  GridView.extent(
            maxCrossAxisExtent: 220,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final category in homeCategories) _CategoryCard(category: category),
            ],
          ),
          const SizedBox(height: 24),

          // Offline status (the offline library arrives in Phase 4)
          Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 16, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Offline library not downloaded yet',
                    style: MedivoText.bodySm.copyWith(color: p.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: p.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Search disease, drug, symptom, test…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MedivoText.body.copyWith(color: p.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final HomeCategory category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final emergency = category.emergency;
    final background = emergency ? p.alert : p.surfaceRaised;
    final foreground = emergency ? Theme.of(context).colorScheme.onError : p.ink;
    final iconColour = emergency ? foreground : p.brand;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: emergency ? p.alert : p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryPlaceholderScreen(category: category),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(category.icon, color: iconColour, size: 28),
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MedivoText.body.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
