import 'package:flutter/material.dart';

import '../../calculators/calc_engine.dart';
import '../../services/calculator_catalog.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/medivo_app_bar.dart';
import '../../widgets/medivo_panel.dart';
import '../reference/topic_screen.dart';

/// One calculator: inputs, live validation, result with interpretation,
/// formula and reference (blueprint §12).
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, required this.calculator});

  final Calculator calculator;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late CalcValues _values;
  final Map<String, TextEditingController> _text = {};
  final Map<String, int> _unit = {};

  Calculator get calc => widget.calculator;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() {
    _values = calc.initialValues();
    for (final input in calc.inputs.whereType<NumberInput>()) {
      (_text[input.id] ??= TextEditingController()).clear();
      _unit[input.id] = 0;
    }
  }

  void _setNumber(NumberInput input, String text) {
    final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
    final factor = input.units[_unit[input.id] ?? 0].toBase;
    setState(() => _values[input.id] = parsed == null ? null : parsed * factor);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final validation = calc.validate(_values);
    final result = validation.ok ? calc.compute(_values) : null;
    final published = CalculatorCatalog.instance.isPublished(calc.code);

    return Scaffold(
      appBar: medivoAppBar(context, calc.title),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (!published)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'STAFF PREVIEW · Not yet clinically approved. Hidden from users until its '
                  'content item ${calc.code} is published.',
                  style: MedivoText.bodySm.copyWith(color: p.ink),
                ),
              ),
            Text(calc.purpose, style: MedivoText.body.copyWith(color: p.ink)),
            if (calc.note != null) ...[
              const SizedBox(height: 6),
              Text(calc.note!, style: MedivoText.bodySm.copyWith(color: p.muted)),
            ],
            const SizedBox(height: 16),
            for (final input in calc.inputs)
              if (input.isVisible(_values)) _buildInput(context, input, validation),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(_reset),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (result != null)
              _ResultCard(result: result)
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  validation.crossError ??
                      (validation.errors.isNotEmpty
                          ? 'Correct the highlighted entries to see the result.'
                          : 'Complete every field to see the result.'),
                  style: MedivoText.body.copyWith(
                      color: validation.crossError != null ? p.alert : p.muted),
                ),
              ),
            const SizedBox(height: 16),
            MedivoPanel(
              title: 'HOW IT IS CALCULATED',
              child: Text(calc.formula, style: MedivoText.bodySm.copyWith(color: p.ink, height: 1.5)),
            ),
            const SizedBox(height: 12),
            MedivoPanel(
              title: 'REFERENCE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(calc.reference, style: MedivoText.bodySm.copyWith(color: p.ink, height: 1.5)),
                  if (published)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => TopicScreen(code: calc.code))),
                        child: const Text('Full specification and review details'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Calculated by tested code, not by AI. Decision support only: check the entries and '
              'use clinical judgement. ${calc.code}',
              style: MedivoText.bodySm.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, CalcInput input, CalcValidation validation) {
    final p = context.palette;
    final label = Text(input.label, style: MedivoText.heading.copyWith(color: p.ink));
    final help = input.help == null
        ? null
        : Text(input.help!, style: MedivoText.bodySm.copyWith(color: p.muted));

    Widget field;
    String? error;
    if (input is NumberInput) {
      final unitIndex = _unit[input.id] ?? 0;
      final unit = input.units[unitIndex];
      if (validation.errors.containsKey(input.id)) {
        error = 'Enter a value from ${fmt(input.min / unit.toBase, 2)} to '
            '${fmt(input.max / unit.toBase, 2)} ${unit.label}.';
      }
      field = TextField(
        controller: _text[input.id],
        keyboardType: TextInputType.numberWithOptions(decimal: !input.integer || unitIndex > 0),
        onChanged: (text) => _setNumber(input, text),
        decoration: InputDecoration(
          hintText: input.hint ?? (input.optional ? 'Optional' : null),
          errorText: error,
          suffixText: input.units.length == 1 ? unit.label : null,
          suffixIcon: input.units.length == 1
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButton<int>(
                    value: unitIndex,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var i = 0; i < input.units.length; i++)
                        DropdownMenuItem(value: i, child: Text(input.units[i].label)),
                    ],
                    onChanged: (i) {
                      if (i == null) return;
                      _unit[input.id] = i;
                      _setNumber(input, _text[input.id]!.text);
                    },
                  ),
                ),
        ),
      );
      return _InputBlock(label: label, help: help, field: field);
    }

    if (input is ChoiceInput) {
      final selected = _values.choice(input.id);
      final compact = input.options.length <= 5 &&
          input.options.every((o) => o.detail == null && o.label.length <= 12);
      if (compact) {
        field = SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              for (final o in input.options) ButtonSegment(value: o.value, label: Text(o.label)),
            ],
            selected: {if (selected != null) selected},
            onSelectionChanged: (s) =>
                setState(() => _values[input.id] = s.isEmpty ? selected : s.first),
          ),
        );
      } else {
        field = Column(
          children: [
            for (final o in input.options)
              _OptionTile(
                option: o,
                selected: selected == o.value,
                onTap: () => setState(() => _values[input.id] = o.value),
              ),
          ],
        );
      }
      return _InputBlock(label: label, help: help, field: field);
    }

    if (input is DateInput) {
      final value = _values.date(input.id);
      error = validation.errors[input.id];
      field = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(value == null ? 'Choose date' : formatDay(value)),
            onPressed: () async {
              final today = _values.today;
              final picked = await showDatePicker(
                context: context,
                initialDate: _local(value ?? today),
                firstDate: _local(addDays(today, -input.daysBack)),
                lastDate: _local(addDays(today, input.daysAhead)),
              );
              if (picked != null) setState(() => _values[input.id] = dateOnly(picked));
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error, style: MedivoText.bodySm.copyWith(color: p.alert)),
          ],
        ],
      );
      return _InputBlock(label: label, help: help, field: field);
    }
    return const SizedBox.shrink();
  }
}

/// A calendar date in local time, for the date picker.
DateTime _local(DateTime d) => DateTime(d.year, d.month, d.day);

class _InputBlock extends StatelessWidget {
  const _InputBlock({required this.label, required this.field, this.help});

  final Widget label;
  final Widget? help;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          if (help != null) ...[const SizedBox(height: 2), help!],
          const SizedBox(height: 8),
          field,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.onTap});

  final CalcOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? p.tint : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? p.brand : p.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? p.brand : p.muted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label, style: MedivoText.body.copyWith(color: p.ink)),
                        if (option.detail != null)
                          Text(option.detail!, style: MedivoText.bodySm.copyWith(color: p.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CalcResult result;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final band = result.band;
    final colour = switch (band?.severity) {
      Severity.danger => p.alert,
      Severity.caution => p.accent,
      Severity.normal => p.brand,
      _ => p.muted,
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: colour),
            Expanded(child: Padding(padding: const EdgeInsets.all(16), child: _content(p, band, colour))),
          ],
        ),
      ),
    );
  }

  Widget _content(MedivoPalette p, Band? band, Color colour) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.label.toUpperCase(), style: MedivoText.label.copyWith(color: p.muted)),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(result.value, style: MedivoText.display.copyWith(color: p.ink)),
              if (result.unit != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(result.unit!, style: MedivoText.body.copyWith(color: p.muted)),
                ),
            ],
          ),
          if (band != null) ...[
            const SizedBox(height: 8),
            Text(band.label, style: MedivoText.heading.copyWith(color: colour)),
            if (band.advice != null) ...[
              const SizedBox(height: 4),
              Text(band.advice!, style: MedivoText.body.copyWith(color: p.ink)),
            ],
          ],
          if (result.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: p.line),
            const SizedBox(height: 8),
            for (final line in result.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 5, child: Text(line.label, style: MedivoText.bodySm.copyWith(color: p.muted))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 6,
                        child: Text(line.value,
                            style: MedivoText.bodySm.copyWith(color: p.ink, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final w in result.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: p.muted),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w, style: MedivoText.bodySm.copyWith(color: p.ink))),
                  ],
                ),
              ),
          ],
        ],
    );
  }
}