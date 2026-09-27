import 'package:flutter/material.dart';

import '../../data/emergency_protocols.dart';
import '../../services/clinical_content_loader.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/medivo_app_bar.dart';
import '../open_content.dart';
import '../reference/topic_screen.dart';

/// A clinical algorithm drawn as a flowchart (blueprint §17):
/// SYMPTOM → RED FLAGS (YES → emergency pathway) → INVESTIGATIONS →
/// DIFFERENTIAL → CONFIRMATION → MANAGEMENT → FOLLOW-UP.
class AlgorithmScreen extends StatefulWidget {
  const AlgorithmScreen({super.key, required this.code, this.fallbackTitle});

  final String code;
  final String? fallbackTitle;

  @override
  State<AlgorithmScreen> createState() => _AlgorithmScreenState();
}

class _AlgorithmScreenState extends State<AlgorithmScreen> {
  late Future<LoadedContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ClinicalContentLoader.load(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.fallbackTitle ?? protocolEntry(widget.code)?.title ?? 'Algorithm';
    return Scaffold(
      appBar: medivoAppBar(context, title),
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
                      ? 'This pathway is not saved on this device and there is no internet. '
                          'Save the Algorithms pack in the Offline library.'
                      : 'This pathway is not available yet.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _future = ClinicalContentLoader.load(widget.code)),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          return _Flowchart(content: content);
        },
      ),
    );
  }
}

class _Flowchart extends StatelessWidget {
  const _Flowchart({required this.content});

  final LoadedContent content;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = content.item;
    final sections = [
      for (final s in splitSections(item.body))
        if (s.title != null && (content.isPreview || !s.title!.toLowerCase().startsWith('reviewer notes'))) s,
    ];

    final nodes = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      final lower = s.title!.toLowerCase();
      if (i > 0) {
        final afterFlags = sections[i - 1].title!.toLowerCase().contains('red flag');
        nodes.add(_Arrow(label: afterFlags ? 'NO red flags' : null));
      }
      if (lower.contains('red flag')) {
        nodes.add(_RedFlagNode(section: s));
      } else {
        nodes.add(_Node(
          section: s,
          highlight: lower.startsWith('presenting'),
          muted: lower.startsWith('reviewer'),
        ));
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
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
                  'Not clinically approved. Hidden from users until published.',
                  style: MedivoText.bodySm.copyWith(color: p.ink),
                ),
              ),
            Text(item.title, style: MedivoText.title.copyWith(color: p.ink)),
            if (item.summary != null) ...[
              const SizedBox(height: 4),
              Text(item.summary!, style: MedivoText.bodySm.copyWith(color: p.muted)),
            ],
            const SizedBox(height: 12),
            ...nodes,
            const SizedBox(height: 16),
            if (!content.isPreview) AboutPanel(item: item),
          ],
        ),
      ),
    );
  }
}

String _bodyOf(MarkdownSection s) => s.text.split('\n').skip(1).join('\n').trim();

class _Node extends StatelessWidget {
  const _Node({required this.section, this.highlight = false, this.muted = false});

  final MarkdownSection section;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final body = _bodyOf(section);
    final colour = muted ? p.accent : p.brand;
    return Container(
      decoration: BoxDecoration(
        color: highlight ? p.tint : p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? p.brand : p.line, width: highlight ? 2 : 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(section.title!.toUpperCase(),
              style: MedivoText.label.copyWith(color: colour, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          MarkdownView(text: body),
          if (!muted) ...[
            ContentLinkChips(codes: codesIn(body)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Red flags: each flag with its YES branch to the emergency pathway.
class _RedFlagNode extends StatelessWidget {
  const _RedFlagNode({required this.section});

  final MarkdownSection section;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lines = _bodyOf(section).split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Container(
      decoration: BoxDecoration(
        color: p.alert.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.alert, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: p.alert, size: 18),
              const SizedBox(width: 6),
              Text('ASSESS RED FLAGS', style: MedivoText.label.copyWith(color: p.alert, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines) _flag(context, line),
        ],
      ),
    );
  }

  Widget _flag(BuildContext context, String line) {
    final p = context.palette;
    final text = line.trim().replaceFirst(RegExp(r'^[-*•]\s*'), '');
    final parts = text.split('→');
    final sign = parts.first.trim();
    final action = parts.length > 1 ? parts.sublist(1).join('→').trim() : null;
    final codes = codesIn(text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarkdownView(text: '- $sign'),
          if (action != null)
            Container(
              margin: const EdgeInsets.only(left: 24, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.alert.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'YES → ',
                      style: MedivoText.bodySm.copyWith(color: p.alert, fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: action.replaceAll('**', ''),
                      style: MedivoText.bodySm.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          if (codes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: ContentLinkChips(codes: codes),
            ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: label == null ? 32 : 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (label != null)
            Text(label!, style: MedivoText.label.copyWith(color: p.brand, letterSpacing: 0.6)),
          Icon(Icons.arrow_downward, color: p.brand, size: 22),
        ],
      ),
    );
  }
}
