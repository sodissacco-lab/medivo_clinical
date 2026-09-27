import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../differentials/ddx_engine.dart';
import '../../services/account_controller.dart';
import '../../services/ddx_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';
import '../../widgets/medivo_panel.dart';
import '../studio/studio_widgets.dart';

const Map<String, String> _statusLabels = {
  'draft': 'Drafts',
  'in_review': 'In review',
  'approved': 'Approved',
  'published': 'Published',
  'retired': 'Retired',
};

const Map<int, String> _weightLabels = {3: '3 · characteristic', 2: '2 · common', 1: '1 · supportive'};

/// Content staff: review the differential diagnosis knowledge base.
class DdxReviewScreen extends StatefulWidget {
  const DdxReviewScreen({super.key});

  @override
  State<DdxReviewScreen> createState() => _DdxReviewScreenState();
}

class _DdxReviewScreenState extends State<DdxReviewScreen> {
  String _status = 'draft';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = DdxService.listByStatus(_status));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Differential review'),
      body: Column(children: [
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
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
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return Center(child: Text('Nothing here.', style: MedivoText.body.copyWith(color: p.muted)));
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (context, i) => Divider(height: 1, color: p.line),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final mnm = r['must_not_miss'] == true;
                  return ListTile(
                    leading: Icon(mnm ? Icons.priority_high : Icons.medical_information_outlined,
                        color: mnm ? p.alert : p.brand),
                    title: Text(r['name'] as String, style: MedivoText.body.copyWith(color: p.ink)),
                    subtitle: Text('${r['category']} · ${r['commonness']}${mnm ? ' · must not miss' : ''}',
                        style: MedivoText.bodySm.copyWith(color: p.muted)),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => DdxConditionScreen(conditionKey: r['key'] as String),
                      ));
                      _reload();
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class DdxConditionScreen extends StatefulWidget {
  const DdxConditionScreen({super.key, required this.conditionKey});

  final String conditionKey;

  @override
  State<DdxConditionScreen> createState() => _DdxConditionScreenState();
}

class _DdxConditionScreenState extends State<DdxConditionScreen> {
  Map<String, dynamic>? _c;
  Map<String, int> _weights = {};
  Map<String, DdxFinding> _findings = {};
  List<DdxEvent> _history = const [];
  bool _busy = false;
  String? _error;
  String? _addKey;

  String get _role => AccountController.instance.profile?.role ?? '';
  bool get _isReviewer => _role == 'medical_reviewer' || _role == 'super_admin';
  bool get _draft => _c?['status'] == 'draft';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await DdxService.condition(widget.conditionKey);
      final w = await DdxService.weights(widget.conditionKey);
      final f = _findings.isEmpty ? await DdxService.allFindings() : _findings.values.toList();
      final h = await DdxService.history(widget.conditionKey);
      if (!mounted) return;
      setState(() {
        _c = c;
        _weights = w;
        _findings = {for (final x in f) x.key: x};
        _history = h;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load: $e');
    }
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

  Future<String?> _ask(String title, String hint, {String? initial}) {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLines: 3, autofocus: true, decoration: InputDecoration(hintText: hint)),
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

  Future<void> _act(String action) async {
    String? note;
    String? verified;
    if (action == 'approve') {
      verified = await _ask('Verified against', 'Reference you checked this profile against',
          initial: _c?['verified_against'] as String?);
      if (verified == null) return;
    }
    if (action == 'request_changes') {
      note = await _ask('Request changes', 'What needs to change?');
      if (note == null) return;
    }
    await _guard(() async {
      final s = await DdxService.transition(widget.conditionKey, action, note: note, verifiedAgainst: verified);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now: ${_statusLabels[s] ?? s}')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = _c;
    if (c == null) {
      return Scaffold(
        appBar: medivoAppBar(context, 'Condition'),
        body: Center(child: _error == null ? const CircularProgressIndicator() : FormMessage(message: _error!)),
      );
    }
    final status = c['status'] as String;
    final required = (c['required'] as List? ?? const [])
        .map((g) => (g as List).map((k) => _findings[k]?.name ?? '$k').join(' or '))
        .toList();
    final sorted = _weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final addable = _findings.values.where((f) => !_weights.containsKey(f.key)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: medivoAppBar(context, c['name'] as String),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('${c['category']} · ${_statusLabels[status] ?? status}',
              style: MedivoText.bodySm.copyWith(color: p.muted)),
          if (c['verified_against'] != null)
            Text('Verified against: ${c['verified_against']}', style: MedivoText.bodySm.copyWith(color: p.brand)),
          if (_error != null) ...[const SizedBox(height: 8), FormMessage(message: _error!)],
          const SizedBox(height: 12),
          MedivoPanel(
            title: 'NEXT STEP',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (status == 'draft')
                FilledButton(onPressed: _busy ? null : () => _act('submit'), child: const Text('Submit for review')),
              if (status == 'in_review' && _isReviewer) ...[
                FilledButton(onPressed: _busy ? null : () => _act('approve'), child: const Text('Approve')),
                OutlinedButton(onPressed: _busy ? null : () => _act('request_changes'), child: const Text('Request changes')),
              ],
              if (status == 'approved' && _isReviewer) ...[
                FilledButton(onPressed: _busy ? null : () => _act('publish'), child: const Text('Publish')),
                OutlinedButton(onPressed: _busy ? null : () => _act('request_changes'), child: const Text('Request changes')),
              ],
              if (status == 'published' && _isReviewer)
                OutlinedButton(onPressed: _busy ? null : () => _act('retire'), child: const Text('Retire')),
              if (status == 'retired')
                OutlinedButton(onPressed: _busy ? null : () => _act('reopen'), child: const Text('Reopen as draft')),
            ]),
          ),
          const SizedBox(height: 12),
          MedivoPanel(
            title: 'PROFILE',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: c['must_not_miss'] == true,
                onChanged: _draft && !_busy
                    ? (v) => _guard(() => DdxService.updateCondition(widget.conditionKey, {'must_not_miss': v}))
                    : null,
                title: Text('Must not miss (dangerous)', style: MedivoText.body.copyWith(color: p.ink)),
              ),
              DropdownButtonFormField<String>(
                initialValue: c['commonness'] as String?,
                decoration: const InputDecoration(labelText: 'How common in Uganda'),
                items: const [
                  DropdownMenuItem(value: 'common', child: Text('Common')),
                  DropdownMenuItem(value: 'uncommon', child: Text('Uncommon')),
                  DropdownMenuItem(value: 'rare', child: Text('Rare')),
                ],
                onChanged: _draft && !_busy
                    ? (v) => _guard(() => DdxService.updateCondition(widget.conditionKey, {'commonness': v}))
                    : null,
              ),
              const SizedBox(height: 12),
              Text('Suggested only when: ${required.isEmpty ? 'any finding fits' : required.map((g) => '($g)').join(' AND ')}',
                  style: MedivoText.bodySm.copyWith(color: p.muted)),
              const SizedBox(height: 4),
              Text('Links: ${((c['links'] as List?) ?? const []).join(', ')}',
                  style: MedivoText.bodySm.copyWith(color: p.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          MedivoPanel(
            title: 'FINDINGS AND WEIGHTS',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final e in sorted)
                Row(children: [
                  Expanded(child: Text(_findings[e.key]?.name ?? e.key, style: MedivoText.body.copyWith(color: p.ink))),
                  if (_draft)
                    DropdownButton<int>(
                      value: e.value,
                      underline: const SizedBox.shrink(),
                      items: [for (final w in _weightLabels.entries) DropdownMenuItem(value: w.key, child: Text(w.value))],
                      onChanged: _busy
                          ? null
                          : (v) => _guard(() => DdxService.setWeight(widget.conditionKey, e.key, v)),
                    )
                  else
                    Text(_weightLabels[e.value]!, style: MedivoText.bodySm.copyWith(color: p.muted)),
                  if (_draft)
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _busy ? null : () => _guard(() => DdxService.setWeight(widget.conditionKey, e.key, null)),
                    ),
                ]),
              if (_draft) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _addKey,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Add a finding'),
                      items: [for (final f in addable) DropdownMenuItem(value: f.key, child: Text(f.name))],
                      onChanged: (v) => setState(() => _addKey = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy || _addKey == null
                        ? null
                        : () {
                            final k = _addKey!;
                            _addKey = null;
                            _guard(() => DdxService.setWeight(widget.conditionKey, k, 2));
                          },
                    child: const Text('Add'),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          MedivoPanel(
            title: 'HISTORY',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            ]),
          ),
        ],
      ),
    );
  }
}
