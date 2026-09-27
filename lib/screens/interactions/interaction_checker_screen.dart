import 'package:flutter/material.dart';

import '../../interactions/interaction_engine.dart';
import '../../services/account_controller.dart';
import '../../services/interaction_service.dart';
import '../../services/published_index.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';

/// Drug interaction checker (blueprint §15): choose two or more drugs and
/// see each interaction with mechanism, consequence, action, monitoring
/// and reference. Works offline with the list saved on the phone.
class InteractionCheckerScreen extends StatefulWidget {
  const InteractionCheckerScreen({super.key});

  @override
  State<InteractionCheckerScreen> createState() => _InteractionCheckerScreenState();
}

class _InteractionCheckerScreenState extends State<InteractionCheckerScreen> {
  static const _maxDrugs = 10;
  static const _examples = [
    ['warfarin', 'metronidazole'],
    ['rifampicin', 'dolutegravir'],
    ['efavirenz', 'levonorgestrel-implant'],
    ['lopinavir-ritonavir', 'simvastatin'],
  ];

  InteractionIndex? _index;
  bool _fromDevice = false;
  bool _loading = true;
  String? _error;
  bool _includeDrafts = false;
  final List<String> _selected = [];
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await InteractionService.load(includeDrafts: _includeDrafts);
      if (!mounted) return;
      setState(() {
        _index = result.index;
        _fromDevice = result.fromDevice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The interaction list could not be loaded. Connect to the internet once, '
            'then it will also work offline.';
      });
    }
  }

  void _add(String key) {
    if (_selected.contains(key) || _selected.length >= _maxDrugs) return;
    setState(() => _selected.add(key));
    _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index = _index;
    return Scaffold(
      appBar: medivoAppBar(context, 'Drug interactions'),
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
                      if (_fromDevice)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Icon(Icons.offline_pin_outlined, size: 16, color: p.brand),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Offline: using the list saved on this device.',
                                  style: MedivoText.bodySm.copyWith(color: p.brand)),
                            ),
                          ]),
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
                                title: Text('Include unreviewed entries (staff preview)',
                                    style: MedivoText.bodySm.copyWith(color: p.ink)),
                              )
                            : const SizedBox.shrink(),
                      ),
                      _picker(context, index),
                      const SizedBox(height: 12),
                      if (_selected.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in _selected)
                              InputChip(
                                label: Text(index.terms[key]?.name ?? key),
                                onDeleted: () => setState(() => _selected.remove(key)),
                              ),
                            if (_selected.length > 1)
                              ActionChip(
                                avatar: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Clear'),
                                onPressed: () => setState(_selected.clear),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      if (_selected.length < 2) _startHelp(context, index) else _results(context, index),
                    ],
                  ),
                ),
    );
  }

  Widget _picker(BuildContext context, InteractionIndex index) {
    return RawAutocomplete<InteractionTerm>(
      textEditingController: _field,
      focusNode: _focus,
      displayStringForOption: (t) => t.name,
      optionsBuilder: (value) {
        if (value.text.trim().length < 2) return const Iterable<InteractionTerm>.empty();
        return index.search(value.text, exclude: _selected.toSet()).take(8);
      },
      onSelected: (t) => _add(t.key),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: _selected.length < _maxDrugs,
        decoration: InputDecoration(
          hintText: _selected.isEmpty ? 'Add a drug (e.g. warfarin, TLD, Coartem)' : 'Add another drug',
          prefixIcon: const Icon(Icons.add),
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        final p = context.palette;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: p.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final t in options)
                    ListTile(
                      title: Text(t.name, style: MedivoText.body.copyWith(color: p.ink)),
                      subtitle: t.synonyms.isEmpty
                          ? null
                          : Text(t.synonyms.take(4).join(', '),
                              style: MedivoText.bodySm.copyWith(color: p.muted)),
                      onTap: () => onSelected(t),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _startHelp(BuildContext context, InteractionIndex index) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add two or more drugs to check them together.',
            style: MedivoText.body.copyWith(color: p.muted)),
        const SizedBox(height: 16),
        Text('TRY', style: MedivoText.label.copyWith(color: p.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pair in _examples)
              if (pair.every(index.terms.containsKey))
                ActionChip(
                  label: Text(pair.map((k) => index.terms[k]!.name).join(' + ')),
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(pair);
                  }),
                ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${index.drugs.length} drugs · ${index.interactions.length} reviewed interactions',
          style: MedivoText.bodySm.copyWith(color: p.muted),
        ),
      ],
    );
  }

  Widget _results(BuildContext context, InteractionIndex index) {
    final p = context.palette;
    final hits = index.check(_selected);
    if (hits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No interaction found', style: MedivoText.heading.copyWith(color: p.ink)),
            const SizedBox(height: 6),
            Text(
              'No interaction between these drugs is in Medivo\'s reviewed list. The list is not '
              'complete: check each drug\'s information and use clinical judgement.',
              style: MedivoText.bodySm.copyWith(color: p.muted),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${hits.length} ${hits.length == 1 ? 'INTERACTION' : 'INTERACTIONS'} FOUND',
            style: MedivoText.label.copyWith(color: p.muted)),
        const SizedBox(height: 8),
        for (final hit in hits) _HitCard(hit: hit, index: index),
        const SizedBox(height: 8),
        Text(
          'Decision support only. The list is not complete; check the drug information and use clinical judgement.',
          style: MedivoText.bodySm.copyWith(color: p.muted),
        ),
      ],
    );
  }
}

Color severityColour(MedivoPalette p, InteractionSeverity s) => switch (s) {
      InteractionSeverity.contraindicated || InteractionSeverity.major => p.alert,
      InteractionSeverity.moderate => p.accent,
      InteractionSeverity.minor => p.muted,
    };

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit, required this.index});

  final InteractionHit hit;
  final InteractionIndex index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final x = hit.interaction;
    final colour = severityColour(p, x.severity);
    final byClass = [x.termA, x.termB]
        .where((k) => index.terms[k]?.isClass ?? false)
        .map((k) => index.terms[k]!.name)
        .toList();
    Widget section(String title, String? text) => text == null || text.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: MedivoText.label.copyWith(color: p.muted)),
                const SizedBox(height: 2),
                Text(text, style: MedivoText.body.copyWith(color: p.ink)),
              ],
            ),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour, width: x.severity.index <= 1 ? 2 : 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: x.severity.index <= 1,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: colour),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(severityLabels[x.severity]!.toUpperCase(),
                        style: MedivoText.label.copyWith(color: colour, fontWeight: FontWeight.w800)),
                  ),
                  if (!x.isPublished) ...[
                    const SizedBox(width: 8),
                    Text('· ${x.status.replaceAll('_', ' ').toUpperCase()}',
                        style: MedivoText.label.copyWith(color: p.muted)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text('${hit.drugA.name} + ${hit.drugB.name}',
                  style: MedivoText.heading.copyWith(color: p.ink)),
              const SizedBox(height: 2),
              Text(x.summary, style: MedivoText.bodySm.copyWith(color: p.ink)),
            ],
          ),
          children: [
            if (byClass.isNotEmpty)
              Text('Matched through: ${byClass.join('; ')}',
                  style: MedivoText.bodySm.copyWith(color: p.muted, fontStyle: FontStyle.italic)),
            section('Mechanism', x.mechanism),
            section('Potential consequence', x.consequence),
            section('Clinical action', x.action),
            section('Monitoring', x.monitoring),
            section('Reference', x.verifiedAgainst ?? (x.isPublished ? null : 'Not yet verified. ${x.suggestedSources ?? ''}')),
            const SizedBox(height: 8),
            Text(x.code, style: MedivoText.bodySm.copyWith(color: p.muted)),
          ],
        ),
      ),
    );
  }
}
