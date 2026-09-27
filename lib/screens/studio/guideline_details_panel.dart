import 'package:flutter/material.dart';

import '../../data/guideline_library.dart';
import '../../services/content_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/medivo_panel.dart';

/// Content studio: the structured details every guideline needs before it
/// can be approved (blueprint §18): issuer, edition, official link and
/// licence status. The database refuses approval without a link and a
/// publishable licence status.
class GuidelineDetailsPanel extends StatefulWidget {
  const GuidelineDetailsPanel({
    super.key,
    required this.version,
    required this.editable,
    required this.onSaved,
  });

  final ContentVersion version;
  final bool editable;
  final VoidCallback onSaved;

  @override
  State<GuidelineDetailsPanel> createState() => _GuidelineDetailsPanelState();
}

class _GuidelineDetailsPanelState extends State<GuidelineDetailsPanel> {
  late final Map<String, TextEditingController> _text;
  String? _jurisdiction;
  String? _group;
  String? _licence;
  bool _busy = false;
  String? _message;

  static const _textFields = {
    'issuer': 'Issued by',
    'edition': 'Edition',
    'year': 'Year',
    'url': 'Official link (https://…)',
    'licence_source': 'Licence holder (as in the licence register)',
  };

  @override
  void initState() {
    super.initState();
    final meta = widget.version.metadata;
    _text = {
      for (final key in _textFields.keys)
        key: TextEditingController(text: meta[key]?.toString() ?? ''),
    };
    _jurisdiction = meta['jurisdiction'] as String? ?? widget.version.category;
    _group = meta['group'] as String?;
    _licence = meta['licence_status'] as String?;
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _groups => _jurisdiction == 'International'
      ? internationalGuidelineGroups
      : ugandaGuidelineGroups;

  Future<void> _save() async {
    final url = _text['url']!.text.trim();
    if (url.isNotEmpty && !RegExp(r'^https?://').hasMatch(url)) {
      setState(() => _message = 'The official link must start with https:// or http://');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final meta = Map<String, dynamic>.from(widget.version.metadata);
      for (final entry in _text.entries) {
        final value = entry.value.text.trim();
        if (value.isEmpty) {
          meta.remove(entry.key);
        } else {
          meta[entry.key] = value;
        }
      }
      meta['jurisdiction'] = _jurisdiction;
      meta['group'] = _group;
      meta['licence_status'] = _licence;
      meta.removeWhere((key, value) => value == null);
      await ContentService.saveMetadata(widget.version.id, meta);
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _message = contentError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ready = _text['url']!.text.trim().isNotEmpty && publishableLicences.contains(_licence);
    return MedivoPanel(
      title: 'GUIDELINE DETAILS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ready
                ? 'Ready: has an official link and a licence status that allows publication.'
                : 'Needs an official link and a licence status of "Summary and official link", '
                    '"Open licence" or "Permission granted" before approval.',
            style: MedivoText.bodySm.copyWith(color: ready ? p.brand : p.alert),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _jurisdiction,
            decoration: const InputDecoration(labelText: 'Library'),
            items: const [
              DropdownMenuItem(value: 'Uganda', child: Text('Uganda')),
              DropdownMenuItem(value: 'International', child: Text('International')),
            ],
            onChanged: widget.editable
                ? (v) => setState(() {
                      _jurisdiction = v;
                      if (!_groups.contains(_group)) _group = null;
                    })
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_jurisdiction),
            initialValue: _groups.contains(_group) ? _group : null,
            decoration: const InputDecoration(labelText: 'Section'),
            items: [for (final g in _groups) DropdownMenuItem(value: g, child: Text(g))],
            onChanged: widget.editable ? (v) => setState(() => _group = v) : null,
          ),
          for (final entry in _textFields.entries) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _text[entry.key],
              enabled: widget.editable,
              keyboardType: entry.key == 'url' ? TextInputType.url : TextInputType.text,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: entry.value),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: licenceLabels.containsKey(_licence) ? _licence : null,
            decoration: const InputDecoration(labelText: 'Licence status'),
            items: [
              for (final e in licenceLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: widget.editable ? (v) => setState(() => _licence = v) : null,
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: MedivoText.bodySm.copyWith(color: p.alert)),
          ],
          if (widget.editable) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save details'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
