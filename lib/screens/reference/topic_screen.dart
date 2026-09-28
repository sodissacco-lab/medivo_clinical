import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/content_options.dart';
import '../../offline/offline_service.dart';
import '../../services/account_controller.dart';
import '../../services/clinical_content_loader.dart';
import '../../services/library_service.dart';
import '../../services/reference_repository.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/bookmark_button.dart';
import '../../widgets/form_message.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/medivo_app_bar.dart';
import '../../widgets/medivo_panel.dart';
import '../open_content.dart';

/// Reading page for one published topic (blueprint §9, §10, §13, §14),
/// with a Contents bar to jump between sections and the full review
/// record (§31) at the end.
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.code});

  final String code;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  late Future<({OfflineItem? item, TopicSource source})> _future;
  final Map<int, GlobalKey> _sectionKeys = {};
  bool _siUnits = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _retry() => setState(() => _future = _load());

  /// Status of an unpublished version shown to content staff as a preview.
  String? _previewStatus;

  /// Published content for everyone; content staff also get a preview of
  /// the latest draft when nothing is published yet.
  Future<({OfflineItem? item, TopicSource source})> _load() async {
    final content = await ClinicalContentLoader.load(widget.code);
    _previewStatus = content?.previewStatus;
    final item = content?.item;
    if (item != null) unawaited(LibraryService.instance.recordView(item.code, item.title, item.type));
    return (item: content?.item, source: content?.source ?? TopicSource.online);
  }

  void _jumpTo(int index) {
    final context = _sectionKeys[index]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 300), alignment: 0.02);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({OfflineItem? item, TopicSource source})>(
      future: _future,
      builder: (context, snapshot) {
        final item = snapshot.data?.item;
        return Scaffold(
          appBar: medivoAppBar(
              context, item == null ? 'Topic' : (contentTypes[item.type] ?? 'Topic'),
              actions: [if (item != null) BookmarkButton(code: item.code, title: item.title, type: item.type)]),
          body: SafeArea(child: _body(context, snapshot)),
        );
      },
    );
  }

  Widget _body(BuildContext context,
      AsyncSnapshot<({OfflineItem? item, TopicSource source})> snapshot) {
    final p = context.palette;
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError || snapshot.data?.item == null) {
      final offline = snapshot.hasError;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormMessage(
            message: offline
                ? 'This topic is not saved on this device and there is no internet '
                    'connection. Turn on its pack in the Offline library to read it offline.'
                : 'This topic is not available. It may have been withdrawn.',
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _retry, child: const Text('Try again')),
        ],
      );
    }

    final item = snapshot.data!.item!;
    final source = snapshot.data!.source;
    final sections = splitSections(item.body)
        .where((s) =>
            s.title == null || _previewStatus != null || !s.title!.toLowerCase().startsWith('reviewer notes'))
        .toList();
    final namedSections = [
      for (var i = 0; i < sections.length; i++)
        if (sections[i].title != null) i,
    ];
    final hasUnitColumns =
        item.body.contains('(SI)') && item.body.contains('(Conventional)');
    final hide = hasUnitColumns ? (_siUnits ? '(Conventional)' : '(SI)') : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_previewStatus != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'STAFF PREVIEW · ${_previewStatus!.replaceAll('_', ' ').toUpperCase()} · '
                    'Not clinically approved. Hidden from users until published.',
                    style: MedivoText.bodySm.copyWith(color: p.ink),
                  ),
                ),
              Text(item.title, style: MedivoText.title.copyWith(color: p.ink)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.category != null)
                    Text(item.category!, style: MedivoText.bodySm.copyWith(color: p.muted)),
                  if (item.versionLabel != null)
                    Text('Version ${item.versionLabel}',
                        style: MedivoText.bodySm.copyWith(color: p.muted)),
                  _SourceBadge(source: source),
                ],
              ),
              if (item.summary != null) ...[
                const SizedBox(height: 12),
                Text(item.summary!, style: MedivoText.body.copyWith(color: p.ink)),
              ],
              if (hasUnitColumns) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('SI units')),
                      ButtonSegment(value: false, label: Text('Conventional')),
                    ],
                    selected: {_siUnits},
                    onSelectionChanged: (v) => setState(() => _siUnits = v.first),
                  ),
                ),
              ],
              if (namedSections.length > 2) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final i in namedSections)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(sections[i].title!),
                            onPressed: () => _jumpTo(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              for (var i = 0; i < sections.length; i++)
                KeyedSubtree(
                  key: _sectionKeys.putIfAbsent(i, GlobalKey.new),
                  child: MarkdownView(text: sections[i].text, hideColumnsContaining: hide),
                ),
              if (_linkCodes(item).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('RELATED', style: MedivoText.label.copyWith(color: p.muted)),
                const SizedBox(height: 8),
                ContentLinkChips(codes: _linkCodes(item), exclude: item.code),
              ],
              const SizedBox(height: 24),
              if (_previewStatus == null) AboutPanel(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linked emergency protocols, calculators, algorithms and topics.
List<String> _linkCodes(OfflineItem item) => [
      for (final key in ['calculators', 'related'])
        ...((item.metadata[key] as List?) ?? const []).map((e) => e.toString()),
    ];

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final TopicSource source;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final device = source == TopicSource.device;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(device ? Icons.offline_pin_outlined : Icons.cloud_outlined,
            size: 16, color: device ? p.brand : p.muted),
        const SizedBox(width: 4),
        Text(device ? 'Saved on this device' : 'Reading online',
            style: MedivoText.bodySm.copyWith(color: device ? p.brand : p.muted)),
      ],
    );
  }
}

/// Sources, review record and the safety statement (blueprint §3, §31).
class AboutPanel extends StatelessWidget {
  const AboutPanel({super.key, required this.item});

  final OfflineItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <(String, String)>[
      if (item.authorName != null) ('Author', item.authorName!),
      if (item.approverName != null) ('Clinical approval', item.approverName!),
      if (item.publishedAt != null) ('Published', formatLongDate(item.publishedAt!)),
      if (item.lastReviewedAt != null) ('Last reviewed', formatLongDate(item.lastReviewedAt!)),
      if (item.nextReviewAt != null) ('Next review', formatLongDate(item.nextReviewAt!)),
      ('Content ID', item.code),
    ];
    final isStaff = contentStaffRoles.contains(AccountController.instance.profile?.role ?? '');

    return MedivoPanel(
      title: 'ABOUT THIS CONTENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.sources != null) ...[
            Text('SOURCES', style: MedivoText.label.copyWith(color: p.muted)),
            const SizedBox(height: 4),
            MarkdownView(text: item.sources!),
            const SizedBox(height: 8),
          ],
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(label, style: MedivoText.bodySm.copyWith(color: p.muted)),
                  ),
                  Expanded(
                    child: Text(value, style: MedivoText.bodySm.copyWith(color: p.ink)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Medivo Clinical supports clinical judgement and does not replace it. '
            'Always consider the individual patient and current national guidelines.',
            style: MedivoText.bodySm.copyWith(color: p.muted),
          ),
          if (isStaff) ...[
            const SizedBox(height: 8),
            Text('To change this topic, open it in the Content studio and start a revision.',
                style: MedivoText.bodySm.copyWith(color: p.muted)),
          ],
        ],
      ),
    );
  }
}