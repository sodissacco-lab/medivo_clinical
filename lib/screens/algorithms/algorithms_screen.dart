import 'package:flutter/material.dart';

import '../../data/emergency_protocols.dart';
import '../../services/account_controller.dart';
import '../../services/published_index.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/medivo_app_bar.dart';
import 'algorithm_screen.dart';

/// Clinical algorithms (blueprint §17): symptom-based pathways.
class AlgorithmsScreen extends StatefulWidget {
  const AlgorithmsScreen({super.key});

  @override
  State<AlgorithmsScreen> createState() => _AlgorithmsScreenState();
}

class _AlgorithmsScreenState extends State<AlgorithmsScreen> {
  final _index = PublishedIndex.of('algorithm');

  @override
  void initState() {
    super.initState();
    _index.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Clinical algorithms'),
      body: ListenableBuilder(
        listenable: Listenable.merge([_index, AccountController.instance]),
        builder: (context, _) {
          final extra = [
            for (final t in _index.topics)
              if (!clinicalAlgorithms.any((e) => e.code == t.code))
                ProtocolEntry(t.code, t.title, Icons.account_tree_outlined),
          ];
          final entries = [...clinicalAlgorithms, ...extra];
          return RefreshIndicator(
            onRefresh: _index.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length + 1,
              separatorBuilder: (context, index) =>
                  index == 0 ? const SizedBox.shrink() : Divider(height: 1, color: p.line, indent: 72),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Start from the presenting symptom. Each pathway checks red flags first, '
                      'then tests, likely causes, management and follow-up.',
                      style: MedivoText.bodySm.copyWith(color: p.muted),
                    ),
                  );
                }
                final entry = entries[index - 1];
                final published = _index.isPublished(entry.code);
                final canOpen = _index.canOpen(entry.code);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: canOpen ? p.tint : p.surfaceRaised,
                    child: Icon(entry.icon, color: canOpen ? p.brand : p.muted),
                  ),
                  title: Text(entry.title,
                      style: MedivoText.heading.copyWith(color: canOpen ? p.ink : p.muted)),
                  subtitle: published
                      ? null
                      : Text(PublishedIndex.isStaff ? 'PREVIEW · not yet approved' : 'Under clinical review',
                          style: MedivoText.bodySm.copyWith(color: p.muted)),
                  trailing: Icon(Icons.chevron_right, color: p.muted),
                  onTap: canOpen
                      ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => AlgorithmScreen(code: entry.code, fallbackTitle: entry.title),
                          ))
                      : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('This pathway is still being clinically reviewed.'),
                          )),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
