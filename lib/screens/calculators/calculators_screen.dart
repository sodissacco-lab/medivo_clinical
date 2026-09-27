import 'package:flutter/material.dart';

import '../../calculators/calc_engine.dart';
import '../../calculators/calculator_registry.dart';
import '../../services/account_controller.dart';
import '../../services/calculator_catalog.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/medivo_app_bar.dart';
import 'calculator_screen.dart';

/// All calculators by blueprint §12 group: General, Emergency,
/// Paediatrics, Obstetrics.
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  final _filter = TextEditingController();
  String? _category;

  @override
  void initState() {
    super.initState();
    CalculatorCatalog.instance.refresh();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  bool _matches(Calculator c) {
    final q = _filter.text.trim().toLowerCase();
    if (_category != null && c.category != _category) return false;
    if (q.isEmpty) return true;
    return c.title.toLowerCase().contains(q) || c.synonyms.any((s) => s.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Calculators'),
      body: ListenableBuilder(
        listenable: Listenable.merge([CalculatorCatalog.instance, AccountController.instance]),
        builder: (context, _) {
          final catalog = CalculatorCatalog.instance;
          final visible = catalog.visible;
          final shown = visible.where(_matches).toList();

          if (!catalog.loaded && visible.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (visible.isEmpty) return _NoneYet(onRetry: catalog.refresh);

          return RefreshIndicator(
            onRefresh: catalog.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (catalog.isStaff)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'Staff view: calculators marked PREVIEW are not yet clinically approved '
                      'and are hidden from users.',
                      style: MedivoText.bodySm.copyWith(color: p.ink),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _filter,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Filter calculators',
                      prefixIcon: const Icon(Icons.filter_list),
                      suffixIcon: _filter.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Clear',
                              onPressed: () => setState(_filter.clear),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final c in <String?>[null, ...calculatorCategories])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c ?? 'All'),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final category in calculatorCategories)
                  if (shown.any((c) => c.category == category)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(category.toUpperCase(), style: MedivoText.label.copyWith(color: p.muted)),
                    ),
                    for (final calc in shown.where((c) => c.category == category))
                      ListTile(
                        title: Text(calc.title, style: MedivoText.heading.copyWith(color: p.ink)),
                        subtitle: Text(calc.purpose,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MedivoText.bodySm.copyWith(color: p.muted)),
                        trailing: catalog.isPublished(calc.code)
                            ? Icon(Icons.chevron_right, color: p.muted)
                            : Chip(
                                label: const Text('PREVIEW'),
                                labelStyle: MedivoText.label.copyWith(color: p.ink),
                                visualDensity: VisualDensity.compact,
                              ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => CalculatorScreen(calculator: calc)),
                        ),
                      ),
                  ],
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No calculator matches.',
                        textAlign: TextAlign.center, style: MedivoText.body.copyWith(color: p.muted)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoneYet extends StatelessWidget {
  const _NoneYet({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_outlined, color: p.muted, size: 40),
            const SizedBox(height: 12),
            Text('Calculators are being clinically checked',
                textAlign: TextAlign.center, style: MedivoText.heading.copyWith(color: p.ink)),
            const SizedBox(height: 6),
            Text('Each calculator appears here once its formula and interpretation have been approved.',
                textAlign: TextAlign.center, style: MedivoText.bodySm.copyWith(color: p.muted)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Check again')),
          ],
        ),
      ),
    );
  }
}