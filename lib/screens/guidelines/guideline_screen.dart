import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/guideline_library.dart';
import '../../services/clinical_content_loader.dart';
import '../../services/library_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/bookmark_button.dart';
import '../../widgets/external_link.dart';
import '../../widgets/form_message.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/medivo_app_bar.dart';
import '../../widgets/medivo_panel.dart';
import '../open_content.dart';
import '../reference/topic_screen.dart';

/// One guideline: who issued it, which edition, the licence, a summary in
/// Medivo's own words, and a button to open the official document.
class GuidelineScreen extends StatefulWidget {
  const GuidelineScreen({super.key, required this.code, this.fallbackTitle});

  final String code;
  final String? fallbackTitle;

  @override
  State<GuidelineScreen> createState() => _GuidelineScreenState();
}

class _GuidelineScreenState extends State<GuidelineScreen> {
  late Future<LoadedContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Loads the content and adds it to Recent (blueprint §26).
  Future<LoadedContent?> _load() async {
    final content = await ClinicalContentLoader.load(widget.code);
    if (content != null) {
      _title = content.item.title;
      unawaited(LibraryService.instance.recordView(content.item.code, content.item.title, content.item.type));
      if (mounted) setState(() {});
    }
    return content;
  }

  String? _title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: medivoAppBar(context, 'Guideline', actions: [
        BookmarkButton(code: widget.code, title: _title ?? widget.fallbackTitle ?? 'Guideline', type: 'guideline'),
      ]),
      body: FutureBuilder<LoadedContent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = snapshot.data;
          if (snapshot.hasError || content == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FormMessage(
                  message: snapshot.hasError
                      ? 'This guideline is not saved on this device and there is no internet. '
                          'Save the Guidelines pack in the Offline library.'
                      : 'This guideline is not available yet.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          return _GuidelineBody(content: content);
        },
      ),
    );
  }
}

class _GuidelineBody extends StatelessWidget {
  const _GuidelineBody({required this.content});

  final LoadedContent content;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = content.item;
    final meta = item.metadata;
    String? field(String key) {
      final value = meta[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    final url = field('url');
    final licence = field('licence_status');
    final sections = [
      for (final s in splitSections(item.body))
        if (s.title != null &&
            (content.isPreview || !s.title!.toLowerCase().startsWith('reviewer notes')) &&
            s.title!.toLowerCase() != 'source')
          s,
    ];
    final related = ((meta['related'] as List?) ?? const []).map((e) => e.toString()).toList();
    final rows = <(String, String)>[
      if (field('issuer') != null) ('Issued by', field('issuer')!),
      if (field('edition') != null) ('Edition', field('edition')!),
      if (field('year') != null) ('Year', field('year')!),
      if (field('group') != null) ('Library section', '${field('jurisdiction') ?? ''} · ${field('group')}'),
      if (licence != null) ('Licence', licenceLabels[licence] ?? licence),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (content.isPreview)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'STAFF PREVIEW · ${content.previewStatus!.replaceAll('_', ' ').toUpperCase()} · '
                  'Not yet approved. Hidden from users until published.',
                  style: MedivoText.bodySm.copyWith(color: p.ink),
                ),
              ),
            Text(item.title, style: MedivoText.title.copyWith(color: p.ink)),
            const SizedBox(height: 12),
            MedivoPanel(
              title: 'ABOUT THIS GUIDELINE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(label, style: MedivoText.bodySm.copyWith(color: p.muted)),
                          ),
                          Expanded(child: Text(value, style: MedivoText.bodySm.copyWith(color: p.ink))),
                        ],
                      ),
                    ),
                  if (url != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => openExternalLink(context, url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open the official document'),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => copyLink(context, url),
                      icon: const Icon(Icons.link),
                      label: const Text('Copy link'),
                    ),
                    Text('Opens outside Medivo and needs internet.',
                        textAlign: TextAlign.center, style: MedivoText.bodySm.copyWith(color: p.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final s in sections) MarkdownView(text: s.text),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('IN MEDIVO', style: MedivoText.label.copyWith(color: p.muted)),
              const SizedBox(height: 8),
              ContentLinkChips(codes: related, exclude: item.code),
            ],
            const SizedBox(height: 24),
            if (!content.isPreview) AboutPanel(item: item),
          ],
        ),
      ),
    );
  }
}