import 'dart:async';

import 'package:flutter/material.dart';

import '../data/content_options.dart';
import '../services/search_service.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/medivo_app_bar.dart';
import 'open_content.dart';

/// Universal search (blueprint §6, §34): one box for diseases, drugs, tests,
/// radiology, guidelines and more, understanding abbreviations, lay terms,
/// spelling variants and brand names.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _examples = [
    'Hypertension', 'HTN', 'high BP', 'amlodipine', 'fever',
    'malaria', 'Hb', 'anaemia', 'creatinine', 'chest pain',
  ];

  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  bool _loading = false;
  SearchOutcome? _outcome;
  String? _type; // null = all types
  List<String> _recent = const [];
  String _lastRecorded = '';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final recent = await SearchService.recent();
    if (mounted) setState(() => _recent = recent);
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    setState(() {});
    if (SearchService.normalise(text).length < 2) {
      setState(() {
        _outcome = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(text));
  }

  Future<void> _run(String text) async {
    final id = ++_requestId;
    setState(() => _loading = true);
    final outcome = await SearchService.search(text);
    if (!mounted || id != _requestId) return; // a newer search has started
    setState(() {
      _outcome = outcome;
      _loading = false;
    });
  }

  Future<void> _record() async {
    final q = _controller.text.trim();
    if (q.length < 2 || q.toLowerCase() == _lastRecorded) return;
    _lastRecorded = q.toLowerCase();
    await SearchService.record(q, _outcome?.results.length ?? 0);
    await _loadRecent();
  }

  void _searchFor(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _debounce?.cancel();
    _run(text).then((_) => _record());
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _outcome = null;
      _loading = false;
    });
    SearchService.focusNode.requestFocus();
  }

  Future<void> _open(SearchResult result) async {
    SearchService.focusNode.unfocus();
    unawaited(_record());
    await openContent(context, result.code);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final outcome = _outcome;
    final all = outcome?.results ?? const <SearchResult>[];
    final shown = _type == null ? all : all.where((r) => r.type == _type).toList();
    final typesFound = <String>{for (final r in all) r.type};

    return Scaffold(
      appBar: medivoAppBar(context, 'Search'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: SearchService.focusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (text) {
                _debounce?.cancel();
                _run(text).then((_) => _record());
              },
              decoration: InputDecoration(
                hintText: 'Search diseases, drugs, tests, guidelines…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          if (_loading) LinearProgressIndicator(minHeight: 2, color: p.brand),
          if (outcome != null && typesFound.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _typeChip(null, 'All (${all.length})'),
                  for (final type in contentTypes.keys)
                    if (typesFound.contains(type))
                      _typeChip(type,
                          '${contentTypePlurals[type] ?? type} (${all.where((r) => r.type == type).length})'),
                ],
              ),
            ),
          Expanded(
            child: outcome == null
                ? _StartPanel(
                    recent: _recent,
                    examples: _examples,
                    onPick: _searchFor,
                    onClearRecent: () async {
                      await SearchService.clearRecent();
                      await _loadRecent();
                    },
                  )
                : _ResultsList(
                    outcome: outcome,
                    results: shown,
                    query: _controller.text.trim(),
                    onOpen: _open,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String? type, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _type == type,
        onSelected: (_) => setState(() => _type = type),
      ),
    );
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.recent,
    required this.examples,
    required this.onPick,
    required this.onClearRecent,
  });

  final List<String> recent;
  final List<String> examples;
  final ValueChanged<String> onPick;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('RECENT SEARCHES', style: MedivoText.label.copyWith(color: p.muted)),
              ),
              TextButton(onPressed: onClearRecent, child: const Text('Clear')),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in recent)
                ActionChip(
                  avatar: Icon(Icons.history, size: 18, color: p.muted),
                  label: Text(q),
                  onPressed: () => onPick(q),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Text('TRY SEARCHING', style: MedivoText.label.copyWith(color: p.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in examples) ActionChip(label: Text(q), onPressed: () => onPick(q)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Search understands abbreviations (HTN, Hb, DM), everyday words '
          '(high BP, sugar, running stomach), British and American spellings '
          '(anaemia, anemia) and common brand names.',
          style: MedivoText.bodySm.copyWith(color: p.muted),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.outcome,
    required this.results,
    required this.query,
    required this.onOpen,
  });

  final SearchOutcome outcome;
  final List<SearchResult> results;
  final String query;
  final ValueChanged<SearchResult> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final header = <Widget>[
      if (outcome.fromDevice)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.tint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: p.brand, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No internet. Showing topics saved on this device only.',
                  style: MedivoText.bodySm.copyWith(color: p.ink),
                ),
              ),
            ],
          ),
        ),
      if (outcome.expandedTo.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Also searching: ${outcome.expandedTo.join(', ')}',
            style: MedivoText.bodySm.copyWith(color: p.muted),
          ),
        ),
    ];

    if (results.isEmpty) {
      return ListView(
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.search_off, color: p.muted, size: 40),
                const SizedBox(height: 12),
                Text('No results for “$query”', style: MedivoText.heading.copyWith(color: p.ink),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  outcome.fromDevice
                      ? 'Connect to the internet to search the full library, '
                          'or save more packs in the Offline library.'
                      : 'Check the spelling, or try a shorter or more general term. '
                          'Some topics are still being clinically reviewed.',
                  style: MedivoText.bodySm.copyWith(color: p.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length + 1,
      separatorBuilder: (context, index) =>
          index == 0 ? const SizedBox.shrink() : Divider(height: 1, color: p.line, indent: 16),
      itemBuilder: (context, index) {
        if (index == 0) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: header);
        final r = results[index - 1];
        final typeLabel = contentTypes[r.type] ?? r.type;
        final meta = [typeLabel, if (r.category != null && r.category!.isNotEmpty) r.category!];
        final hint = switch (r.matched) {
          'search term' => 'Matched a search term',
          'synonym' => 'Matched a synonym',
          'category' => 'Matched the category',
          'text' => 'Mentioned in the text',
          _ => null,
        };
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(r.title, style: MedivoText.heading.copyWith(color: p.ink)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(meta.join(' · '), style: MedivoText.bodySm.copyWith(color: p.brand)),
              if (r.summary != null && r.summary!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(r.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MedivoText.bodySm.copyWith(color: p.muted)),
              ],
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint,
                    style: MedivoText.bodySm.copyWith(color: p.muted, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
          trailing: r.savedOffline
              ? Tooltip(
                  message: 'Saved on this device',
                  child: Icon(Icons.offline_pin_outlined, color: p.brand, size: 20),
                )
              : Icon(Icons.chevron_right, color: p.muted),
          onTap: () => onOpen(r),
        );
      },
    );
  }
}