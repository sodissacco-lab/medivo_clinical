import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/emergency_protocols.dart';
import '../../services/clinical_content_loader.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/elapsed_timer.dart';
import '../../widgets/form_message.dart';
import '../../widgets/markdown_view.dart';
import '../open_content.dart';
import '../reference/topic_screen.dart';

/// One emergency protocol as large numbered steps (blueprint §16):
/// Recognise, Call for help, Immediate treatment, Monitoring,
/// Additional treatment, Referral. Timer and tools on top.
class EmergencyProtocolScreen extends StatefulWidget {
  const EmergencyProtocolScreen({super.key, required this.code, this.fallbackTitle});

  final String code;
  final String? fallbackTitle;

  @override
  State<EmergencyProtocolScreen> createState() => _EmergencyProtocolScreenState();
}

class _EmergencyProtocolScreenState extends State<EmergencyProtocolScreen> {
  late Future<LoadedContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ClinicalContentLoader.load(widget.code);
    // Keep the screen on while a protocol is open (blueprint §16: fast).
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onAlert = Theme.of(context).colorScheme.onError;
    final title = widget.fallbackTitle ?? protocolEntry(widget.code)?.title ?? 'Emergency';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.alert,
        foregroundColor: onAlert,
        title: Text(title, style: MedivoText.heading.copyWith(color: onAlert)),
      ),
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
                      ? 'This protocol is not saved on this device and there is no internet. '
                          'Save the Emergency pack in the Offline library so protocols always open.'
                      : 'This protocol is not available yet.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _future = ClinicalContentLoader.load(widget.code)),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          return _ProtocolBody(content: content);
        },
      ),
    );
  }
}

class _ProtocolBody extends StatelessWidget {
  const _ProtocolBody({required this.content});

  final LoadedContent content;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = content.item;
    final sections = splitSections(item.body);
    final steps = [
      for (final s in sections)
        if (s.title != null && (content.isPreview || !s.title!.toLowerCase().startsWith('reviewer notes'))) s,
    ];
    final intro = sections.where((s) => s.title == null).map((s) => s.text).join('\n\n');
    final calculators = ((item.metadata['calculators'] as List?) ?? const []).map((e) => e.toString());
    final related = ((item.metadata['related'] as List?) ?? const []).map((e) => e.toString());
    final tools = [...calculators, ...related];

    return ListView(
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
        ElapsedTimer(cycleSeconds: item.code == 'EMR-001' ? 120 : null),
        if (tools.isNotEmpty) ...[
          const SizedBox(height: 12),
          ContentLinkChips(codes: tools, exclude: item.code),
        ],
        if (intro.isNotEmpty && content.isPreview) ...[
          const SizedBox(height: 8),
          MarkdownView(text: intro),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < steps.length; i++) _StepCard(section: steps[i], fallbackNumber: i + 1),
        const SizedBox(height: 12),
        if (!content.isPreview) AboutPanel(item: item),
      ],
    );
  }
}

/// A numbered step. The "Immediate treatment" step is highlighted.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.section, required this.fallbackNumber});

  final MarkdownSection section;
  final int fallbackNumber;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(section.title!);
    final number = match?.group(1) ?? '$fallbackNumber';
    final title = match?.group(2) ?? section.title!;
    final immediate = title.toLowerCase().startsWith('immediate');
    final reviewer = title.toLowerCase().startsWith('reviewer');
    final accent = immediate ? p.alert : (reviewer ? p.accent : p.brand);
    final body = section.text.split('\n').skip(1).join('\n').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: immediate ? p.alert.withValues(alpha: 0.07) : p.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: immediate ? p.alert : p.line, width: immediate ? 2 : 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!reviewer)
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accent,
                  child: Text(number,
                      style: MedivoText.heading.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              if (!reviewer) const SizedBox(width: 10),
              Expanded(
                child: Text(title.toUpperCase(),
                    style: MedivoText.heading.copyWith(color: accent, letterSpacing: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 1.08),
            ),
            child: MarkdownView(text: body),
          ),
        ],
      ),
    );
  }
}