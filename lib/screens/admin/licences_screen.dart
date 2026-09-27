import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/guideline_library.dart';
import '../../services/account_controller.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';

/// The licence register (blueprint §18): which sources Medivo may use,
/// and how. Content staff can read it; super administrators edit it.
class LicencesScreen extends StatefulWidget {
  const LicencesScreen({super.key});

  @override
  State<LicencesScreen> createState() => _LicencesScreenState();
}

class _LicencesScreenState extends State<LicencesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  bool get _canEdit => AccountController.instance.profile?.role == 'super_admin';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('content_licences').select().order('source');
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LicenceDialog(row: row),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Licence register'),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add source'),
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              const FormMessage(message: 'The licence register could not be loaded. Check your connection.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Try again')),
            ]);
          }
          final rows = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Only content that is appropriately licensed or otherwise legally usable may be '
                    'published. Record each permission here.',
                    style: MedivoText.bodySm.copyWith(color: p.muted),
                  ),
                ),
                for (final row in rows)
                  ListTile(
                    title: Text(row['source'] as String, style: MedivoText.heading.copyWith(color: p.ink)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(licenceLabels[row['status']] ?? '${row['status']}',
                            style: MedivoText.bodySm.copyWith(
                                color: row['status'] == 'refused'
                                    ? p.alert
                                    : (row['status'] == 'granted' || row['status'] == 'open_licence')
                                        ? p.brand
                                        : p.muted,
                                fontWeight: FontWeight.w700)),
                        if (row['covers'] != null)
                          Text(row['covers'] as String, style: MedivoText.bodySm.copyWith(color: p.ink)),
                        if (row['notes'] != null)
                          Text(row['notes'] as String, style: MedivoText.bodySm.copyWith(color: p.muted)),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: _canEdit ? const Icon(Icons.edit_outlined) : null,
                    onTap: _canEdit ? () => _edit(row) : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LicenceDialog extends StatefulWidget {
  const _LicenceDialog({this.row});

  final Map<String, dynamic>? row;

  @override
  State<_LicenceDialog> createState() => _LicenceDialogState();
}

class _LicenceDialogState extends State<_LicenceDialog> {
  late final TextEditingController _source;
  late final TextEditingController _covers;
  late final TextEditingController _permission;
  late final TextEditingController _notes;
  late String _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.row ?? const {};
    _source = TextEditingController(text: r['source'] as String? ?? '');
    _covers = TextEditingController(text: r['covers'] as String? ?? '');
    _permission = TextEditingController(text: r['permission_ref'] as String? ?? '');
    _notes = TextEditingController(text: r['notes'] as String? ?? '');
    _status = r['status'] as String? ?? 'to_confirm';
  }

  @override
  void dispose() {
    for (final c in [_source, _covers, _permission, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _blank(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_source.text.trim().isEmpty) {
      setState(() => _error = 'Enter the source name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final values = {
      'source': _source.text.trim(),
      'covers': _blank(_covers),
      'status': _status,
      'permission_ref': _blank(_permission),
      'notes': _blank(_notes),
    };
    try {
      final table = Supabase.instance.client.from('content_licences');
      if (widget.row == null) {
        await table.insert(values);
      } else {
        await table.update(values).eq('id', widget.row!['id'] as String);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not save. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.row == null ? 'Add source' : 'Edit licence'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _source, decoration: const InputDecoration(labelText: 'Source')),
            const SizedBox(height: 12),
            TextField(controller: _covers, decoration: const InputDecoration(labelText: 'What it covers')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final e in licenceLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _permission,
              decoration: const InputDecoration(labelText: 'Permission reference (letter, email, date)'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              FormMessage(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
