import 'package:flutter/material.dart';

import '../../data/content_options.dart';
import '../../services/account_controller.dart';
import '../../services/reference_repository.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';
import '../open_content.dart';

/// A browsable list of published topics of one type, with category
/// filters (blueprint §7, §13, §14) and a quick filter box.
class ReferenceListScreen extends StatefulWidget {
  const ReferenceListScreen({super.key, required this.type});

  final String type;

  @override
  State<ReferenceListScreen> createState() => _ReferenceListScreenState();
}

class _ReferenceListScreenState extends State<ReferenceListScreen> {
  final _filter = TextEditingController();
  late Future<({List<TopicSummary> topics, bool fromDevice})> _future;
  String? _category;

  @override
  void initState() {
    super.initState();
    _future = ReferenceRepository.list(widget.type);
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = ReferenceRepository.list(widget.type);
    setState(() => _future = future);
    await future;
  }

  List<String> _categoriesIn(List<TopicSummary> topics) {
    final present = <String, int>{};
    for (final t in topics) {
      final c = t.category;
      if (c != null && c.isNotEmpty) present[c] = (present[c] ?? 0) + 1;
    }
    final fixed = fixedCategories[widget.type] ?? const <String>[];
    final ordered = [
      for (final c in fixed)
        if (present.containsKey(c)) c,
      ...(present.keys.where((c) => !fixed.contains(c)).toList()..sort()),
    ];
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = contentTypePlurals[widget.type] ?? widget.type;

    return Scaffold(
      appBar: medivoAppBar(context, title),
      body: FutureBuilder<({List<TopicSummary> topics, bool fromDevice})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FormMessage(message: friendlyError(snapshot.error!)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _reload, child: const Text('Try again')),
              ],
            );
          }

          final result = snapshot.data!;
          final categories = _categoriesIn(result.topics);
          final shown = result.topics
              .where((t) => _category == null || t.category == _category)
              .where((t) => t.matches(_filter.text))
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TextField(
                  controller: _filter,
                  decoration: InputDecoration(
                    hintText: 'Filter ${title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.filter_list),
                    suffixIcon: _filter.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: _filter.clear,
                          ),
                  ),
                ),
                if (categories.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip('All', _category == null, () => setState(() => _category = null)),
                        for (final c in categories)
                          _chip(c, _category == c, () => setState(() => _category = c)),
                      ],
                    ),
                  ),
                ],
                if (result.fromDevice) ...[
                  const SizedBox(height: 12),
                  const FormMessage(
                    isError: false,
                    message: 'No internet connection. Showing the topics saved on this device.',
                  ),
                ],
                const SizedBox(height: 8),
                if (result.topics.isEmpty)
                  _EmptyState(type: widget.type, fromDevice: result.fromDevice)
                else if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Nothing matches your filter.',
                        textAlign: TextAlign.center,
                        style: MedivoText.body.copyWith(color: p.muted)),
                  )
                else
                  for (final topic in shown) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(topic.title,
                          style: MedivoText.body
                              .copyWith(color: p.ink, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          if (topic.category != null) topic.category!,
                          if (topic.summary != null) topic.summary!,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MedivoText.bodySm.copyWith(color: p.muted),
                      ),
                      trailing: topic.savedOffline
                          ? Tooltip(
                              message: 'Saved on this device',
                              child: Icon(Icons.offline_pin_outlined, color: p.brand, size: 20),
                            )
                          : Icon(Icons.chevron_right, color: p.muted),
                      onTap: () => openContent(context, topic.code),
                    ),
                    Divider(height: 1, color: p.line),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.type, required this.fromDevice});

  final String type;
  final bool fromDevice;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final role = AccountController.instance.profile?.role ?? '';
    final isStaff = contentStaffRoles.contains(role);
    final name = (contentTypePlurals[type] ?? type).toLowerCase();
    final message = fromDevice
        ? 'No $name are saved on this device yet. Connect to the internet, or turn on '
            'the matching pack in the Offline library.'
        : 'No $name have been published yet. Topics appear here once they pass '
            'clinical review and are published.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, color: p.muted, size: 40),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center, style: MedivoText.body.copyWith(color: p.muted)),
          if (isStaff && !fromDevice) ...[
            const SizedBox(height: 8),
            Text('Drafts and content in review are in the Content studio.',
                textAlign: TextAlign.center,
                style: MedivoText.bodySm.copyWith(color: p.muted)),
          ],
        ],
      ),
    );
  }
}