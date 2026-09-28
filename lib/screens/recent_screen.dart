import 'package:flutter/material.dart';

import '../data/content_options.dart';
import '../services/library_service.dart';
import '../services/search_service.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/medivo_app_bar.dart';
import 'open_content.dart';

/// Recent history (blueprint §26): recently viewed, kept on this phone.
class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  static String _when(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Today $hm';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $hm';
    return '${t.day}/${t.month}/${t.year}';
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes recently viewed items and recent searches from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await LibraryService.instance.clearHistory();
      await SearchService.clearRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final library = LibraryService.instance;
    return Scaffold(
      appBar: medivoAppBar(context, 'Recent', actions: [
        TextButton(onPressed: () => _confirmClear(context), child: const Text('Clear history')),
      ]),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final items = library.recent;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, color: p.muted, size: 40),
                  const SizedBox(height: 12),
                  Text('Nothing viewed yet', style: MedivoText.heading.copyWith(color: p.ink)),
                  const SizedBox(height: 6),
                  Text('Topics, calculators, protocols and guidelines you open appear here.',
                      textAlign: TextAlign.center, style: MedivoText.bodySm.copyWith(color: p.muted)),
                ]),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, i) => Divider(height: 1, color: p.line, indent: 16),
            itemBuilder: (context, i) {
              final r = items[i];
              return Dismissible(
                key: ValueKey('rv-${r.code}'),
                onDismissed: (_) => library.removeRecent(r.code),
                background: Container(color: p.line),
                child: ListTile(
                  leading: Icon(library.isSaved(r.code) ? Icons.star : Icons.history,
                      color: library.isSaved(r.code) ? p.accent : p.muted),
                  title: Text(r.title, style: MedivoText.body.copyWith(color: p.ink)),
                  subtitle: Text('${contentTypes[r.type] ?? 'Topic'} · ${_when(r.viewedAt)}',
                      style: MedivoText.bodySm.copyWith(color: p.muted)),
                  onTap: () => openContent(context, r.code),
                ),
              );
            },
          );
        },
      ),
    );
  }
}