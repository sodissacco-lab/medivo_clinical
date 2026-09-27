import 'package:flutter/material.dart';

import '../../differentials/ddx_engine.dart';
import '../../services/account_controller.dart';
import '../../services/ddx_service.dart';
import '../../services/published_index.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';
import '../open_content.dart';

/// Differential diagnosis (blueprint §11): enter symptoms, signs and simple
/// results; see possible conditions grouped by clinical relevance, each
/// linked to its disease page. Clinical support, not a diagnosis.
class DdxScreen extends StatefulWidget {
  const DdxScreen({super.key});

  @override
  State<DdxScreen> createState() => _DdxScreenState();
}

class _DdxScreenState extends State<DdxScreen> {
  static const _groups = [
    'General',
    'Head and nervous system',
    'Chest and breathing',
    'Heart and circulation',
    'Abdomen',
    'Urinary and genital',
    'Skin, joints and muscles',
    'Patient context and tests',
  ];

  DdxIndex? _index;
  bool _fromDevice = false;
  bool _loading = true;
  String? _error;
  bool _includeDrafts = false;
  final List<String> _selected = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await DdxService.load(includeDrafts: _includeDrafts);
      if (!mounted) return;
      setState(() {
        _index = r.index;
        _fromDevice = r.fromDevice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load. Connect to the internet once; after that it also works offline.';
      });
    }
  }

  void _toggle(String key) => setState(() {
        if (!_selected.remove(key)) _selected.add(key);
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index = _index;
    return Scaffold(
      appBar: medivoAppBar(context, 'Differential diagnosis'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : index == null
              ? ListView(padding: const EdgeInsets.all(16), children: [
                  FormMessage(message: _error ?? 'Not available.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Try again')),
                ])
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Text(
                        'Clinical support only: suggests conditions to consider. It does not make a '
                        'diagnosis; use your examination, tests and judgement.',
                        style: MedivoText.bodySm.copyWith(color: p.muted),
                      ),
                      if (_fromDevice)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Offline: using the list saved on this device.',
                              style: MedivoText.bodySm.copyWith(color: p.brand)),
                        ),
                      ListenableBuilder(
                        listenable: AccountController.instance,
                        builder: (context, _) => PublishedIndex.isStaff
                            ? SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _includeDrafts,
                                onChanged: (v) {
                                  setState(() => _includeDrafts = v);
                                  _load();
                                },
                                title: Text('Include unreviewed conditions (staff preview)',
                                    style: MedivoText.bodySm.copyWith(color: p.ink)),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Add a symptom, sign or result (e.g. fever, neck stiffness)',
                          prefixIcon: const Icon(Icons.add),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_search.clear)),
                        ),
                      ),
                      if (_search.text.trim().length >= 2) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final f in index.search(_search.text, exclude: _selected.toSet()).take(10))
                            ActionChip(
                              label: Text(f.name),
                              onPressed: () {
                                _toggle(f.key);
                                _search.clear();
                              },
                            ),
                        ]),
                      ],
                      const SizedBox(height: 12),
                      if (_selected.isNotEmpty) ...[
                        Text('ENTERED', style: MedivoText.label.copyWith(color: p.muted)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final k in _selected)
                            InputChip(
                              label: Text(index.findings[k]?.name ?? k),
                              onDeleted: () => _toggle(k),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear'),
                            onPressed: () => setState(_selected.clear),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _results(context, index),
                        const SizedBox(height: 16),
                      ],
                      Text('BROWSE BY BODY SYSTEM', style: MedivoText.label.copyWith(color: p.muted)),
                      for (final g in _groups)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(g, style: MedivoText.body.copyWith(color: p.ink)),
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            children: [
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final f in index.findings.values.where((f) => f.group == g).toList()
                                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                                  FilterChip(
                                    label: Text(f.name),
                                    selected: _selected.contains(f.key),
                                    onSelected: (_) => _toggle(f.key),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _results(BuildContext context, DdxIndex index) {
    final p = context.palette;
    final results = index.rank(_selected);
    if (results.isEmpty) {
      return Text(
        index.conditions.isEmpty
            ? 'No conditions have been clinically approved yet.'
            : 'No condition in Medivo\'s list fits these findings. Add more findings, or use the clinical algorithms.',
        style: MedivoText.body.copyWith(color: p.muted),
      );
    }
    const titles = {
      DdxGroup.mustNotMiss: 'MUST NOT MISS',
      DdxGroup.mostConsistent: 'MOST CONSISTENT',
      DdxGroup.alsoConsider: 'ALSO CONSIDER',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in DdxGroup.values)
          if (results.any((r) => r.group == group)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(titles[group]!,
                  style: MedivoText.label.copyWith(
                      color: group == DdxGroup.mustNotMiss ? p.alert : p.muted, fontWeight: FontWeight.w800)),
            ),
            for (final r in results.where((r) => r.group == group))
              _ResultCard(result: r, index: index, onAdd: _toggle),
          ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.index, required this.onAdd});

  final DdxResult result;
  final DdxIndex index;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = result.condition;
    final danger = result.group == DdxGroup.mustNotMiss;
    String name(String k) => index.findings[k]?.name ?? k;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger ? p.alert.withValues(alpha: 0.06) : p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger ? p.alert : p.line, width: danger ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.name, style: MedivoText.heading.copyWith(color: p.ink))),
              if (!c.isPublished)
                Text(c.status.replaceAll('_', ' ').toUpperCase(), style: MedivoText.label.copyWith(color: p.muted)),
            ],
          ),
          Text('${c.category} · ${c.commonness} in Uganda', style: MedivoText.bodySm.copyWith(color: p.muted)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Fits: ', style: MedivoText.bodySm.copyWith(color: p.brand, fontWeight: FontWeight.w700)),
            TextSpan(text: result.matched.map(name).join(', '), style: MedivoText.bodySm.copyWith(color: p.ink)),
          ])),
          if (result.lookFor.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Also check for (tap to add):', style: MedivoText.bodySm.copyWith(color: p.muted)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in result.lookFor)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(name(k)),
                  onPressed: () => onAdd(k),
                ),
            ]),
          ],
          if (c.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            ContentLinkChips(codes: c.links),
          ],
        ],
      ),
    );
  }
}
