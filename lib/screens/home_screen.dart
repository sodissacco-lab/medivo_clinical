import 'package:flutter/material.dart';

import '../data/home_categories.dart';
import '../offline/offline_service.dart';
import '../services/account_controller.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/medivo_mark.dart';
import 'algorithms/algorithms_screen.dart';
import 'calculators/calculators_screen.dart';
import 'category_placeholder_screen.dart';
import 'emergency/emergency_hub_screen.dart';
import 'guidelines/guidelines_screen.dart';
import 'offline_library_screen.dart';
import 'reference/reference_list_screen.dart';

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
                    ListenableBuilder(
                      listenable: AccountController.instance,
                      builder: (context, _) {
                        final name = AccountController.instance.profile?.firstName ?? '';
                        return Text(
                          name.isEmpty ? 'Welcome' : 'Welcome, $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MedivoText.heading.copyWith(color: p.ink),
                        );
                      },
                    ),
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

          // The single emergency button (blueprint §16)
          const _EmergencyButton(),
          const SizedBox(height: 12),

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

          // Offline status (blueprint §22)
          const _OfflineStatusLine(),
        ],
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onAlert = Theme.of(context).colorScheme.onError;
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: p.alert,
          foregroundColor: onAlert,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmergencyHubScreen()),
        ),
        icon: const Icon(Icons.emergency, size: 26),
        label: Text('EMERGENCY',
            style: MedivoText.heading.copyWith(color: onAlert, letterSpacing: 1.5)),
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
        onTap: () {
          final type = category.contentType;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => switch (type) {
                'calculator' => const CalculatorsScreen(),
                'emergency' => const EmergencyHubScreen(),
                'algorithm' => const AlgorithmsScreen(),
                'guideline' => const GuidelinesScreen(),
                null => CategoryPlaceholderScreen(category: category),
                _ => ReferenceListScreen(type: type),
              },
            ),
          );
        },
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


class _OfflineStatusLine extends StatelessWidget {
  const _OfflineStatusLine();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final offline = OfflineService.instance;
    if (!offline.supported) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: offline,
      builder: (context, _) {
        final last = offline.lastUpdated;
        final String text;
        final IconData icon;
        if (offline.syncing) {
          text = offline.total == 0
              ? 'Checking for content updates…'
              : 'Updating offline library: ${offline.done} of ${offline.total}';
          icon = Icons.cloud_sync_outlined;
        } else if (last == null) {
          text = 'Offline library not downloaded yet';
          icon = Icons.cloud_off_outlined;
        } else {
          text = 'Offline content last updated: ${formatLongDate(last)}';
          icon = Icons.offline_pin_outlined;
        }
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const OfflineLibraryScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: p.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: MedivoText.bodySm.copyWith(color: p.muted)),
                ),
                Icon(Icons.chevron_right, size: 18, color: p.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}