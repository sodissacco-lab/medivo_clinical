import 'package:flutter/material.dart';

import '../../data/content_options.dart';
import '../../services/content_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import 'new_content_screen.dart';
import 'studio_widgets.dart';
import 'version_screen.dart';

/// Content Studio (blueprint §29): drafts, review queue, approved,
/// published and periodic review, for content staff only.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  int _refreshCount = 0;

  void _refresh() => setState(() => _refreshCount++);

  Future<void> _openVersion(String versionId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VersionScreen(versionId: versionId)),
    );
    _refresh();
  }

  Future<void> _newTopic() async {
    final versionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const NewContentScreen()),
    );
    if (versionId != null) await _openVersion(versionId);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Content studio', style: MedivoText.heading.copyWith(color: p.ink)),
          backgroundColor: p.surface,
          foregroundColor: p.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: p.brand,
            unselectedLabelColor: p.muted,
            indicatorColor: p.brand,
            tabs: const [
              Tab(text: 'Drafts'),
              Tab(text: 'In review'),
              Tab(text: 'Approved'),
              Tab(text: 'Published'),
              Tab(text: 'Review due'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newTopic,
          icon: const Icon(Icons.add),
          label: const Text('New topic'),
        ),
        body: TabBarView(
          children: [
            _VersionList(
              key: ValueKey('draft$_refreshCount'),
              load: () => ContentService.list(['draft']),
              empty: 'No drafts. Tap New topic to start one.',
              onOpen: _openVersion,
            ),
            _VersionList(
              key: ValueKey('review$_refreshCount'),
              load: () => ContentService.list(reviewStatuses),
              empty: 'Nothing is waiting for review.',
              onOpen: _openVersion,
            ),
            _VersionList(
              key: ValueKey('approved$_refreshCount'),
              load: () => ContentService.list(['approved']),
              empty: 'Nothing is approved and waiting to be published.',
              onOpen: _openVersion,
            ),
            _VersionList(
              key: ValueKey('published$_refreshCount'),
              load: () => ContentService.list(['published']),
              empty: 'Nothing has been published yet.',
              onOpen: _openVersion,
            ),
            _VersionList(
              key: ValueKey('due$_refreshCount'),
              load: ContentService.dueForReview,
              empty: 'No published content is due for periodic review in the next 30 days.',
              onOpen: _openVersion,
              showReviewDate: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionList extends StatefulWidget {
  const _VersionList({
    super.key,
    required this.load,
    required this.empty,
    required this.onOpen,
    this.showReviewDate = false,
  });

  final Future<List<ContentVersion>> Function() load;
  final String empty;
  final Future<void> Function(String versionId) onOpen;
  final bool showReviewDate;

  @override
  State<_VersionList> createState() => _VersionListState();
}

class _VersionListState extends State<_VersionList> {
  late Future<List<ContentVersion>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _reload() async {
    final future = widget.load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<List<ContentVersion>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormMessage(message: contentError(snapshot.error!)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _reload, child: const Text('Try again')),
            ],
          );
        }
        final versions = snapshot.data ?? const <ContentVersion>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: versions.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(32),
                  children: [
                    Text(widget.empty,
                        textAlign: TextAlign.center,
                        style: MedivoText.body.copyWith(color: p.muted)),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: versions.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: p.line),
                  itemBuilder: (context, index) {
                    final v = versions[index];
                    final yourTurn = v.status != 'draft' &&
                        v.status != 'published' &&
                        availableActions(v).any((a) => a != 'withdraw');
                    final detail = widget.showReviewDate
                        ? 'Review due ${formatDate(v.nextReviewAt)}'
                        : 'Updated ${formatDate(v.updatedAt)}';
                    return ListTile(
                      onTap: () => widget.onOpen(v.id),
                      title: Text(v.title,
                          style: MedivoText.body.copyWith(
                              color: p.ink, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${v.code} · ${v.typeLabel} · $detail'
                        '${yourTurn ? ' · Your turn' : ''}',
                        style: MedivoText.bodySm.copyWith(
                            color: yourTurn ? p.brand : p.muted,
                            fontWeight: yourTurn ? FontWeight.w700 : FontWeight.w400),
                      ),
                      trailing: StatusChip(status: v.status, label: v.statusLabel),
                    );
                  },
                ),
        );
      },
    );
  }
}
