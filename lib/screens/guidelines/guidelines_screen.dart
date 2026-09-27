import 'package:flutter/material.dart';

import '../../data/guideline_library.dart';
import '../../services/account_controller.dart';
import '../../services/published_index.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/medivo_app_bar.dart';
import 'guideline_screen.dart';

/// The Guideline library (blueprint §18): Uganda first, then other
/// approved sources. Each entry is a summary with the official link.
class GuidelinesScreen extends StatefulWidget {
  const GuidelinesScreen({super.key});

  @override
  State<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends State<GuidelinesScreen> {
  final _index = PublishedIndex.of('guideline');

  @override
  void initState() {
    super.initState();
    _index.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Guidelines'),
      body: ListenableBuilder(
        listenable: Listenable.merge([_index, AccountController.instance]),
        builder: (context, _) {
          // Published guidelines not in the fixed list go under "Other".
          final extra = [
            for (final t in _index.topics)
              if (!guidelineLibrary.any((g) => g.code == t.code))
                GuidelineEntry(t.code, t.title,
                    t.category == 'Uganda' ? 'National treatment guidelines' : 'Other approved sources'),
          ];
          final all = [...guidelineLibrary, ...extra];

          List<Widget> section(String heading, List<String> groups) => [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(heading, style: MedivoText.title.copyWith(color: p.ink)),
                ),
                for (final group in groups)
                  if (all.any((g) => g.group == group)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                      child: Text(group.toUpperCase(), style: MedivoText.label.copyWith(color: p.muted)),
                    ),
                    for (final entry in all.where((g) => g.group == group)) _tile(context, entry),
                  ],
              ];

          return RefreshIndicator(
            onRefresh: _index.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Summaries in Medivo\'s own words, with a link to each official document. '
                    'Full text appears only where the licence allows.',
                    style: MedivoText.bodySm.copyWith(color: p.muted),
                  ),
                ),
                ...section('Uganda', ugandaGuidelineGroups),
                ...section('International', internationalGuidelineGroups),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, GuidelineEntry entry) {
    final p = context.palette;
    final published = _index.isPublished(entry.code);
    final canOpen = _index.canOpen(entry.code);
    return ListTile(
      leading: Icon(Icons.menu_book_outlined, color: canOpen ? p.brand : p.muted),
      title: Text(entry.title, style: MedivoText.body.copyWith(color: canOpen ? p.ink : p.muted)),
      subtitle: published
          ? null
          : Text(PublishedIndex.isStaff ? 'PREVIEW · not yet approved' : 'Under review',
              style: MedivoText.bodySm.copyWith(color: p.muted)),
      trailing: Icon(Icons.chevron_right, color: p.muted),
      onTap: canOpen
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => GuidelineScreen(code: entry.code, fallbackTitle: entry.title),
              ))
          : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('This entry is still being reviewed.'),
              )),
    );
  }
}
