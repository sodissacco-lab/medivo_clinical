import 'package:flutter/material.dart';

import '../../data/content_options.dart';
import '../../services/account_controller.dart';
import '../../services/content_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/medivo_app_bar.dart';
import '../../widgets/medivo_panel.dart';
import '../open_content.dart';
import 'guideline_details_panel.dart';
import 'studio_widgets.dart';

/// One version of a topic: edit it while it is a draft, and move it
/// through review (blueprint §30) with its full history (§31).
class VersionScreen extends StatefulWidget {
  const VersionScreen({super.key, required this.versionId});

  final String versionId;

  @override
  State<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends State<VersionScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _body = TextEditingController();
  final _sources = TextEditingController();
  final _changeNote = TextEditingController();

  ContentVersion? _version;
  List<ReviewEvent> _history = const [];
  List<ContentVersion> _allVersions = const [];
  bool _loading = true;
  String? _loadError;
  bool _busy = false;
  bool _dirty = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _summary, _body, _sources, _changeNote]) {
      c.addListener(_markDirty);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _summary, _body, _sources, _changeNote]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && !_loading && mounted) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final version = await ContentService.get(widget.versionId);
      final results = await Future.wait([
        ContentService.history(version.itemId),
        ContentService.versionsOf(version.itemId),
      ]);
      _title.text = version.title;
      _summary.text = version.summary ?? '';
      _body.text = version.body;
      _sources.text = version.sources ?? '';
      _changeNote.text = version.changeNote ?? '';
      if (!mounted) return;
      setState(() {
        _version = version;
        _history = results[0] as List<ReviewEvent>;
        _allVersions = results[1] as List<ContentVersion>;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = contentError(e);
      });
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _save({bool quiet = false}) async {
    if (_title.text.trim().isEmpty) {
      _show('The title cannot be empty.');
      return false;
    }
    setState(() => _busy = true);
    try {
      await ContentService.saveDraft(
        versionId: widget.versionId,
        title: _title.text,
        summary: _summary.text,
        body: _body.text,
        sources: _sources.text,
        changeNote: _changeNote.text,
      );
      if (!mounted) return true;
      setState(() {
        _busy = false;
        _dirty = false;
      });
      if (!quiet) _show('Draft saved');
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _busy = false);
      _show(contentError(e));
      return false;
    }
  }

  Future<String?> _askForNote(String action) {
    final controller = TextEditingController();
    final mustHaveNote = actionsNeedingNote.contains(action);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(actionLabels[action] ?? action),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: mustHaveNote ? 'Note (required)' : 'Note (optional)',
            helperText: action == 'request_changes'
                ? 'Say exactly what needs to change'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (mustHaveNote && controller.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _run(String action) async {
    final version = _version;
    if (version == null) return;

    if (action == 'submit' && _dirty) {
      final saved = await _save(quiet: true);
      if (!saved) return;
    }

    // Every action is confirmed, and a note can be added to the record.
    final note = await _askForNote(action);
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ContentService.transition(version.id, action, note: note.isEmpty ? null : note);
      if (!mounted) return;
      _show('${actionHistoryLabels[action] ?? 'Done'}.');
      setState(() => _busy = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _show(contentError(e));
    }
  }

  Future<void> _setEssential(bool essential) async {
    final version = _version;
    if (version == null) return;
    setState(() => _busy = true);
    try {
      await ContentService.setEssential(version.itemId, essential);
      if (!mounted) return;
      _show(essential ? 'Added to the Essential Pack' : 'Removed from the Essential Pack');
      setState(() => _busy = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _show(contentError(e));
    }
  }

  Future<void> _startRevision() async {
    final version = _version;
    if (version == null) return;
    setState(() => _busy = true);
    try {
      final draftId = await ContentService.startRevision(version.itemId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => VersionScreen(versionId: draftId)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _show(contentError(e));
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Leave without saving your changes to this draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = _version;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: medivoAppBar(context, version?.code ?? 'Content'),
        body: SafeArea(child: _buildBody(context, version)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ContentVersion? version) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null || version == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormMessage(message: _loadError ?? 'Content not found.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }

    final p = context.palette;
    final editable = canEditDraft(version);
    final actions = availableActions(version);
    final canRevise = (version.status == 'published' || version.status == 'archived') &&
        contentStaffRoles.contains(_role());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(version: version),
                if (version.hasOpenReviewerNotes && version.status != 'published') ...[
                  const SizedBox(height: 12),
                  const FormMessage(
                    isError: false,
                    message: 'This version still contains a "Reviewer notes" section. '
                        'Each note must be resolved and the section removed before clinical approval.',
                  ),
                ],
                if (actions.isNotEmpty || canRevise || editable) ...[
                  const SizedBox(height: 16),
                  MedivoPanel(
                    title: 'NEXT STEP',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (editable)
                          OutlinedButton.icon(
                            onPressed: _busy || !_dirty ? null : () => _save(),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_dirty ? 'Save draft' : 'Saved'),
                          ),
                        for (final action in actions)
                          action == 'request_changes' || action == 'withdraw' || action == 'archive'
                              ? OutlinedButton(
                                  onPressed: _busy ? null : () => _run(action),
                                  child: Text(actionLabels[action] ?? action),
                                )
                              : FilledButton(
                                  onPressed: _busy ? null : () => _run(action),
                                  child: Text(actionLabels[action] ?? action),
                                ),
                        if (canRevise)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _startRevision,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Start a revision'),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _ReviewPanel(version: version),
                if (_role() == 'medical_reviewer' || _role() == 'super_admin') ...[
                  const SizedBox(height: 16),
                  MedivoPanel(
                    title: 'OFFLINE',
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: version.isEssential,
                      onChanged: _busy ? null : _setEssential,
                      title: Text('Include in the Essential Pack',
                          style: MedivoText.body.copyWith(color: p.ink)),
                      subtitle: Text(
                        'Downloaded by default to every phone once published.',
                        style: MedivoText.bodySm.copyWith(color: p.muted),
                      ),
                    ),
                  ),
                ],
                if (version.type == 'guideline') ...[
                  const SizedBox(height: 16),
                  GuidelineDetailsPanel(
                    key: ValueKey('gdl-${version.id}-${version.metadata.hashCode}'),
                    version: version,
                    editable: editable,
                    onSaved: _afterDetailsSaved,
                  ),
                ],
                if (_appViewTypes.contains(version.type)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => openContent(context, version.code),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View as users will see it'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                editable ? _editor(p) : _reader(p, version),
                if (_allVersions.length > 1) ...[
                  const SizedBox(height: 16),
                  _VersionsPanel(
                    versions: _allVersions,
                    currentId: version.id,
                    onOpen: (id) => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => VersionScreen(versionId: id)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _HistoryPanel(events: _history),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _role() => AccountController.instance.profile?.role ?? '';

  /// Content types with their own app layout, worth previewing as users see it.
  static const _appViewTypes = {'emergency', 'algorithm', 'guideline', 'calculator'};

  Future<void> _afterDetailsSaved() async {
    if (_dirty) await _save(quiet: true);
    _show('Details saved');
    await _load();
  }

  Widget _editor(MedivoPalette p) {
    final mono = TextStyle(fontFamily: MedivoText.mono, fontSize: 14, height: 1.5, color: p.ink);
    return MedivoPanel(
      title: 'EDIT DRAFT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summary,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Summary (optional)',
              helperText: 'One or two sentences shown in search results',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Edit'), icon: Icon(Icons.edit_outlined)),
                ButtonSegment(value: true, label: Text('Preview'), icon: Icon(Icons.visibility_outlined)),
              ],
              selected: {_preview},
              onSelectionChanged: (value) => setState(() => _preview = value.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_preview)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _body.text.trim().isEmpty
                  ? Text('(empty)', style: MedivoText.body.copyWith(color: p.muted))
                  : MarkdownView(text: _body.text),
            )
          else
            TextField(
              controller: _body,
              enabled: !_busy,
              minLines: 14,
              maxLines: null,
              style: mono,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Content',
                alignLabelWithHint: true,
                helperText: '## heading · **bold** · - bullet · | table |. Tap Preview to see it as readers will.',
                helperMaxLines: 2,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _sources,
            enabled: !_busy,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Sources',
              helperText: 'Guidelines and references this content is checked against',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _changeNote,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'What changed in this version',
            ),
          ),
        ],
      ),
    );
  }

  Widget _reader(MedivoPalette p, ContentVersion version) {
    final details = <MapEntry<String, String>>[
      if (version.synonyms.isNotEmpty) MapEntry('Search terms', version.synonyms.join(', ')),
      for (final entry in version.metadata.entries)
        if (entry.key != 'verify_against')
          MapEntry(_prettyKey(entry.key),
              entry.value is List ? (entry.value as List).join(', ') : '${entry.value}'),
    ];
    return MedivoPanel(
      title: 'CONTENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (version.summary != null) ...[
            Text(version.summary!, style: MedivoText.body.copyWith(color: p.ink)),
            const SizedBox(height: 12),
          ],
          version.body.isEmpty
              ? Text('(empty)', style: MedivoText.body.copyWith(color: p.muted))
              : MarkdownView(text: version.body),
          if (version.sources != null) ...[
            const SizedBox(height: 16),
            Text('SOURCES', style: MedivoText.label.copyWith(color: p.muted)),
            const SizedBox(height: 4),
            SelectableText(version.sources!, style: MedivoText.bodySm.copyWith(color: p.ink)),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('DETAILS', style: MedivoText.label.copyWith(color: p.muted)),
            const SizedBox(height: 4),
            for (final d in details)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${d.key}: ${d.value}',
                    style: MedivoText.bodySm.copyWith(color: p.ink)),
              ),
          ],
          if (version.changeNote != null) ...[
            const SizedBox(height: 16),
            Text('WHAT CHANGED', style: MedivoText.label.copyWith(color: p.muted)),
            const SizedBox(height: 4),
            Text(version.changeNote!, style: MedivoText.bodySm.copyWith(color: p.ink)),
          ],
        ],
      ),
    );
  }

  static String _prettyKey(String key) {
    final words = key.replaceAll('_', ' ');
    return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.version});

  final ContentVersion version;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(version.title, style: MedivoText.title.copyWith(color: p.ink)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(status: version.status, label: version.statusLabel),
            Text(
              [
                version.code,
                version.typeLabel,
                if (version.category != null) version.category!,
                version.versionText,
              ].join(' · '),
              style: MedivoText.bodySm.copyWith(color: p.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.version});

  final ContentVersion version;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <(String, String)>[
      ('Author', version.authorName ?? 'Not yet assigned'),
      ('Medical editor', version.editorName ?? '—'),
      ('Peer reviewer', version.peerReviewerName ?? '—'),
      ('Clinical approval', version.approverName ?? '—'),
      if (version.approvedAt != null) ('Approved', formatDate(version.approvedAt)),
      if (version.publisherName != null) ('Published by', version.publisherName!),
      if (version.publishedAt != null) ('Published', formatDate(version.publishedAt)),
      if (version.lastReviewedAt != null) ('Last reviewed', formatDate(version.lastReviewedAt)),
      if (version.nextReviewAt != null) ('Next review', formatDate(version.nextReviewAt)),
    ];
    return MedivoPanel(
      title: 'REVIEW',
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(label, style: MedivoText.bodySm.copyWith(color: p.muted)),
                  ),
                  Expanded(
                    child: Text(value, style: MedivoText.bodySm.copyWith(color: p.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionsPanel extends StatelessWidget {
  const _VersionsPanel({required this.versions, required this.currentId, required this.onOpen});

  final List<ContentVersion> versions;
  final String currentId;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MedivoPanel(
      title: 'ALL VERSIONS',
      child: Column(
        children: [
          for (final v in versions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              enabled: v.id != currentId,
              onTap: () => onOpen(v.id),
              title: Text(v.versionText, style: MedivoText.bodySm.copyWith(color: p.ink)),
              subtitle: Text(
                v.id == currentId ? 'You are viewing this version' : 'Updated ${formatDate(v.updatedAt)}',
                style: MedivoText.bodySm.copyWith(color: p.muted),
              ),
              trailing: StatusChip(status: v.status, label: v.statusLabel),
            ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.events});

  final List<ReviewEvent> events;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MedivoPanel(
      title: 'HISTORY',
      child: events.isEmpty
          ? Text('No history yet.', style: MedivoText.bodySm.copyWith(color: p.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.label,
                            style: MedivoText.bodySm
                                .copyWith(color: p.ink, fontWeight: FontWeight.w700)),
                        Text('${e.actorName ?? 'System'} · ${formatDate(e.createdAt)}',
                            style: MedivoText.bodySm.copyWith(color: p.muted)),
                        if (e.note != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('"${e.note}"',
                                style: MedivoText.bodySm.copyWith(color: p.ink)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}