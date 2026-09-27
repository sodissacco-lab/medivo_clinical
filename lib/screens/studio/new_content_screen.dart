import 'package:flutter/material.dart';

import '../../data/content_options.dart';
import '../../data/content_templates.dart';
import '../../services/content_service.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';

/// Starts a new topic. Returns the new draft's id to the caller.
class NewContentScreen extends StatefulWidget {
  const NewContentScreen({super.key});

  @override
  State<NewContentScreen> createState() => _NewContentScreenState();
}

class _NewContentScreenState extends State<NewContentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController(text: contentCodePrefixes['disease']);
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _synonyms = TextEditingController();
  String _type = 'disease';
  String? _fixedCategory;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _category.dispose();
    _synonyms.dispose();
    super.dispose();
  }

  void _changeType(String? type) {
    if (type == null) return;
    setState(() {
      final oldPrefix = contentCodePrefixes[_type] ?? '';
      if (_code.text.isEmpty || _code.text == oldPrefix) {
        _code.text = contentCodePrefixes[type] ?? '';
      }
      _type = type;
      _fixedCategory = null;
    });
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final versionId = await ContentService.create(
        type: _type,
        code: _code.text,
        title: _title.text,
        category: fixedCategories.containsKey(_type) ? _fixedCategory : _category.text,
        synonyms: _synonyms.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      // Start the draft from the blueprint template for this type.
      await ContentService.saveDraft(
        versionId: versionId,
        title: _title.text,
        summary: '',
        body: templateFor(_type),
        sources: '',
        changeNote: 'First draft',
      );
      if (!mounted) return;
      Navigator.of(context).pop(versionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = contentError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'New topic'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Type of content'),
                        items: [
                          for (final entry in contentTypes.entries)
                            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                        ],
                        onChanged: _busy ? null : _changeType,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Content code',
                          helperText: 'Permanent ID, e.g. DIS-INF-011. It can never be reused.',
                        ),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty || text == contentCodePrefixes[_type]) {
                            return 'Enter the full content code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                      ),
                      const SizedBox(height: 16),
                      if (fixedCategories.containsKey(_type))
                        DropdownButtonFormField<String>(
                          key: ValueKey('category-$_type'),
                          initialValue: _fixedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: [
                            for (final category in fixedCategories[_type]!)
                              DropdownMenuItem(value: category, child: Text(category)),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _fixedCategory = value),
                          validator: (value) => value == null ? 'Choose a category' : null,
                        )
                      else
                        TextFormField(
                          controller: _category,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Category (optional)',
                            helperText: 'e.g. Antibiotics, Haematology, Chest X-ray',
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _synonyms,
                        decoration: const InputDecoration(
                          labelText: 'Search terms (optional)',
                          helperText: 'Separate with commas, e.g. HTN, high BP',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'The topic starts as a draft laid out with the standard headings for its type. '
                        'It is only shown to users after '
                        'medical editor check, peer review, clinical approval and publication.',
                        style: MedivoText.bodySm.copyWith(color: p.muted),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        FormMessage(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _create,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Create draft'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}