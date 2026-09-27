import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../interactions/interaction_engine.dart';
import '../../services/account_controller.dart';
import '../../services/interaction_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';
import '../../widgets/medivo_panel.dart';
import '../studio/studio_widgets.dart';
import 'interaction_checker_screen.dart';

const Map<String, String> _statusLabels = {
  'draft': 'Drafts',
  'in_review': 'In review',
  'approved': 'Approved',
  'published': 'Published',
  'retired': 'Retired',
};

/// Content staff: review the drug interaction list (blueprint §15, §30).
class InteractionReviewScreen extends StatefulWidget {
  const InteractionReviewScreen({super.key});

  @override
  State<InteractionReviewScreen> createState() => _InteractionReviewScreenState();
}

class _InteractionReviewScreenState extends State<InteractionReviewScreen> {
  String _status = 'draft';
  late Future<List<DrugInteraction>> _future;
  Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    _reload();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final rows = await Supabase.instance.client.from('interaction_terms').select('key, name');
      if (mounted) setState(() => _names = {for (final r in rows) r['key'] as String: r['name'] as String});
    } catch (_) {}
  }

  void _reload() => setState(() => _future = InteractionService.listByStatus(_status));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Interaction review'),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                for (final e in _statusLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _status == e.key,
                      onSelected: (_) {
                        _status = e.key;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DrugInteraction>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    const FormMessage(message: 'Could not load. Check your connection.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Try again')),
                  ]);
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Text('Nothing here.', style: MedivoText.body.copyWith(color: p.muted)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: p.line),
                    itemBuilder: (context, i) {
                      final x = items[i];
                      return ListTile(
                        leading: Icon(Icons.warning_amber_rounded, color: severityColour(p, x.severity)),
                        title: Text('${_names[x.termA] ?? x.termA} + ${_names[x.termB] ?? x.termB}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: MedivoText.body.copyWith(color: p.ink)),
                        subtitle: Text('${x.code} · ${severityLabels[x.severity]} · ${x.summary}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: MedivoText.bodySm.copyWith(color: p.muted)),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => InteractionEditScreen(id: x.id, names: _names),
                          ));
                          _reload();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One interaction entry: edit while draft; move it through review.
class InteractionEditScreen extends StatefulWidget {
  const InteractionEditScreen({super.key, required this.id, required this.names});

  final String id;
  final Map<String, String> names;

  @override
  State<InteractionEditScreen> createState() => _InteractionEditScreenState();
}

class _InteractionEditScreenState extends State<InteractionEditScreen> {
  static const _fields = {
    'summary': 'Summary (one line)',
    'mechanism': 'Mechanism',
    'consequence': 'Potential consequence',
    'action': 'Clinical action',
    'monitoring': 'Monitoring',
    'suggested_sources': 'Sources to verify against',
  };

  DrugInteraction? _x;
  List<InteractionEvent> _history = const [];
  final Map<String, TextEditingController> _text = {
    for (final k in _fields.keys) k: TextEditingController(),
  };
  String _severity = 'moderate';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final x = await InteractionService.get(widget.id);
      final history = await InteractionService.history(widget.id);
      _text['summary']!.text = x.summary;
      _text['mechanism']!.text = x.mechanism ?? '';
      _text['consequence']!.text = x.consequence ?? '';
      _text['action']!.text = x.action ?? '';
      _text['monitoring']!.text = x.monitoring ?? '';
      _text['suggested_sources']!.text = x.suggestedSources ?? '';
      if (!mounted) return;
      setState(() {
        _x = x;
        _history = history;
        _severity = x.severity.name;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load: $e');
    }
  }

  String get _role => AccountController.instance.profile?.role ?? '';
  bool get _isReviewer => _role == 'medical_reviewer' || _role == 'super_admin';

  Future<void> _saveDraft() async {
    final x = _x!;
    if (_text['summary']!.text.trim().isEmpty) {
      setState(() => _error = 'The summary cannot be empty.');
      return;
    }
    await _guard(() async {
      await InteractionService.saveDraft(x, {
        'severity': _severity,
        for (final e in _text.entries) e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      });
      _snack('Saved');
    });
  }

  Future<void> _act(String action) async {
    String? note;
    String? verified;
    if (action == 'approve') {
      verified = await _ask('Verified against',
          'Which reference did you check this entry against? (e.g. BNF 88, Liverpool HIV checker, date)',
          initial: _x!.verifiedAgainst);
      if (verified == null) return;
    }
    if (action == 'request_changes') {
      note = await _ask('Request changes', 'What needs to change?');
      if (note == null) return;
    }
    await _guard(() async {
      if (action == 'submit') {
        await InteractionService.saveDraft(_x!, {
          'severity': _severity,
          for (final e in _text.entries) e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        });
      }
      final status = await InteractionService.transition(_x!.id, action, note: note, verifiedAgainst: verified);
      _snack('Now: ${_statusLabels[status] ?? status}');
    });
  }

  Future<void> _guard(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
      await _load();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _ask(String title, String prompt, {String? initial}) {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: prompt),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final x = _x;
    return Scaffold(
      appBar: medivoAppBar(context, x?.code ?? 'Interaction'),
      body: x == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : FormMessage(message: _error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text('${widget.names[x.termA] ?? x.termA} + ${widget.names[x.termB] ?? x.termB}',
                    style: MedivoText.title.copyWith(color: p.ink)),
                const SizedBox(height: 4),
                Text('Status: ${_statusLabels[x.status] ?? x.status}',
                    style: MedivoText.bodySm.copyWith(color: p.muted)),
                if (x.verifiedAgainst != null)
                  Text('Verified against: ${x.verifiedAgainst}',
                      style: MedivoText.bodySm.copyWith(color: p.brand)),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  FormMessage(message: _error!),
                ],
                const SizedBox(height: 12),
                MedivoPanel(
                  title: 'NEXT STEP',
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    if (x.status == 'draft') ...[
                      OutlinedButton(onPressed: _busy ? null : _saveDraft, child: const Text('Save draft')),
                      FilledButton(onPressed: _busy ? null : () => _act('submit'), child: const Text('Submit for review')),
                    ],
                    if (x.status == 'in_review' && _isReviewer) ...[
                      FilledButton(onPressed: _busy ? null : () => _act('approve'), child: const Text('Approve')),
                      OutlinedButton(onPressed: _busy ? null : () => _act('request_changes'), child: const Text('Request changes')),
                    ],
                    if (x.status == 'approved' && _isReviewer) ...[
                      FilledButton(onPressed: _busy ? null : () => _act('publish'), child: const Text('Publish')),
                      OutlinedButton(onPressed: _busy ? null : () => _act('request_changes'), child: const Text('Request changes')),
                    ],
                    if (x.status == 'published' && _isReviewer)
                      OutlinedButton(onPressed: _busy ? null : () => _act('retire'), child: const Text('Retire')),
                    if (x.status == 'retired')
                      OutlinedButton(onPressed: _busy ? null : () => _act('reopen'), child: const Text('Reopen as draft')),
                    if ((x.status == 'in_review' || x.status == 'approved') && !_isReviewer)
                      Text('Waiting for a medical reviewer.', style: MedivoText.bodySm.copyWith(color: p.muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                MedivoPanel(
                  title: x.status == 'draft' ? 'EDIT' : 'CONTENT',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _severity,
                        decoration: const InputDecoration(labelText: 'Severity'),
                        items: [
                          for (final s in InteractionSeverity.values)
                            DropdownMenuItem(value: s.name, child: Text(severityLabels[s]!)),
                        ],
                        onChanged: x.status == 'draft' ? (v) => setState(() => _severity = v!) : null,
                      ),
                      for (final e in _fields.entries) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _text[e.key],
                          enabled: x.status == 'draft',
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(labelText: e.value),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MedivoPanel(
                  title: 'HISTORY',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final h in _history)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${formatDate(h.at)} · ${h.action.replaceAll('_', ' ')}'
                            '${h.actorName != null ? ' · ${h.actorName}' : ''}'
                            '${h.note != null ? '\n${h.note}' : ''}',
                            style: MedivoText.bodySm.copyWith(color: p.ink),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
