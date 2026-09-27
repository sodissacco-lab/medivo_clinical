import 'dart:math' as math;

/// The calculator engine (blueprint §12):
/// INPUT → VALIDATION → CALCULATION → RESULT → INTERPRETATION → REFERENCE.
///
/// Everything here is plain, deterministic Dart with no Flutter imports, so
/// every formula can be unit-tested (see test/calculators_test.dart).
/// No calculation is ever produced by AI.

/// How worrying a result is. Drives the colour of the result panel.
enum Severity { normal, info, caution, danger }

/// A unit a number can be entered in, and how to convert it to the base
/// unit the formula uses. The FIRST unit in a list is the base unit.
class UnitOption {
  const UnitOption(this.label, [this.toBase = 1]);

  final String label;

  /// Multiply an entered value by this to get the base unit.
  final double toBase;
}

typedef Condition = bool Function(CalcValues values);

abstract class CalcInput {
  const CalcInput({
    required this.id,
    required this.label,
    this.help,
    this.optional = false,
    this.visibleWhen,
  });

  final String id;
  final String label;
  final String? help;
  final bool optional;

  /// Only shown (and only validated) when this returns true.
  final Condition? visibleWhen;

  bool isVisible(CalcValues values) => visibleWhen?.call(values) ?? true;
}

/// A number typed by the user, with allowed range in the BASE unit.
class NumberInput extends CalcInput {
  const NumberInput({
    required super.id,
    required super.label,
    required this.units,
    required this.min,
    required this.max,
    this.integer = false,
    this.hint,
    super.help,
    super.optional,
    super.visibleWhen,
  });

  final List<UnitOption> units;
  final double min;
  final double max;
  final bool integer;
  final String? hint;
}

class CalcOption {
  const CalcOption(this.label, this.value, [this.detail]);

  final String label;
  final int value;

  /// Extra words shown under the label, e.g. the full scoring description.
  final String? detail;
}

/// Pick one option. Short lists are shown as buttons, long ones as a list.
class ChoiceInput extends CalcInput {
  const ChoiceInput({
    required super.id,
    required super.label,
    required this.options,
    this.initial,
    super.help,
    super.optional,
    super.visibleWhen,
  });

  final List<CalcOption> options;
  final int? initial;
}

/// A yes/no question (value 1 = yes, 0 = no), defaulting to No.
class YesNoInput extends ChoiceInput {
  const YesNoInput({
    required super.id,
    required super.label,
    super.help,
    super.visibleWhen,
  }) : super(options: const [CalcOption('No', 0), CalcOption('Yes', 1)], initial: 0);
}

/// A calendar date, limited to [daysBack] before and [daysAhead] after today.
class DateInput extends CalcInput {
  const DateInput({
    required super.id,
    required super.label,
    this.daysBack = 400,
    this.daysAhead = 0,
    this.defaultToday = false,
    super.help,
    super.optional,
    super.visibleWhen,
  });

  final int daysBack;
  final int daysAhead;
  final bool defaultToday;
}

/// The values entered so far. Numbers are always stored in the BASE unit.
class CalcValues {
  CalcValues([Map<String, Object?>? values, DateTime? today])
      : _values = {...?values},
        today = dateOnly(today ?? DateTime.now());

  final Map<String, Object?> _values;

  /// Today's date (injectable so tests give the same answer every day).
  final DateTime today;

  Object? operator [](String id) => _values[id];
  void operator []=(String id, Object? value) => _values[id] = value;
  bool has(String id) => _values[id] != null;

  double? number(String id) => (_values[id] as num?)?.toDouble();
  double n(String id) => number(id)!;
  int? choice(String id) => _values[id] as int?;
  int c(String id) => choice(id)!;
  bool yes(String id) => _values[id] == 1;
  DateTime? date(String id) => _values[id] as DateTime?;
  DateTime d(String id) => date(id)!;
}

class Band {
  const Band(this.label, this.severity, [this.advice]);

  final String label;
  final Severity severity;
  final String? advice;
}

class ResultLine {
  const ResultLine(this.label, this.value);

  final String label;
  final String value;
}

class CalcResult {
  const CalcResult({
    required this.label,
    required this.value,
    this.unit,
    this.band,
    this.lines = const [],
    this.warnings = const [],
  });

  /// e.g. "BMI", "24.2", "kg/m²".
  final String label;
  final String value;
  final String? unit;

  /// The interpretation.
  final Band? band;
  final List<ResultLine> lines;
  final List<String> warnings;
}

/// What is wrong with the entries, if anything.
class CalcValidation {
  const CalcValidation({this.missing = const [], this.errors = const {}, this.crossError});

  /// Required inputs not yet filled in.
  final List<String> missing;

  /// Input id → message for values outside the allowed range.
  final Map<String, String> errors;

  /// A problem between inputs, e.g. a scan date before the LMP.
  final String? crossError;

  bool get ok => missing.isEmpty && errors.isEmpty && crossError == null;
}

class Calculator {
  const Calculator({
    required this.code,
    required this.title,
    required this.category,
    required this.purpose,
    required this.inputs,
    required this.compute,
    required this.formula,
    required this.reference,
    this.synonyms = const [],
    this.crossCheck,
    this.note,
  });

  /// Matches the content item code, e.g. CALC-GEN-001.
  final String code;
  final String title;

  /// General, Emergency, Paediatrics or Obstetrics (blueprint §12).
  final String category;
  final List<String> synonyms;
  final String purpose;
  final List<CalcInput> inputs;
  final CalcResult Function(CalcValues values) compute;
  final String? Function(CalcValues values)? crossCheck;
  final String formula;
  final String reference;

  /// Always shown with the result, e.g. "Adults only".
  final String? note;

  /// Starting values: choice defaults and dates that default to today.
  CalcValues initialValues([DateTime? today]) {
    final values = CalcValues(null, today);
    for (final input in inputs) {
      if (input is ChoiceInput && input.initial != null) values[input.id] = input.initial;
      if (input is DateInput && input.defaultToday) values[input.id] = values.today;
    }
    return values;
  }

  CalcValidation validate(CalcValues values) {
    final missing = <String>[];
    final errors = <String, String>{};
    for (final input in inputs) {
      if (!input.isVisible(values)) continue;
      final value = values[input.id];
      if (value == null) {
        if (!input.optional) missing.add(input.id);
        continue;
      }
      if (input is NumberInput) {
        final v = (value as num).toDouble();
        if (v < input.min - 1e-9 || v > input.max + 1e-9) {
          errors[input.id] = 'Enter a value from ${fmt(input.min, 2)} to ${fmt(input.max, 2)} '
              '${input.units.first.label}.';
        }
      }
      if (input is DateInput) {
        final days = dayDiff(values.today, value as DateTime);
        if (days > input.daysAhead) errors[input.id] = 'This date is too far in the future.';
        if (-days > input.daysBack) errors[input.id] = 'This date is too far in the past.';
      }
    }
    final cross = (missing.isEmpty && errors.isEmpty) ? crossCheck?.call(values) : null;
    return CalcValidation(missing: missing, errors: errors, crossError: cross);
  }

  /// Validates first; returns null until every entry is valid.
  CalcResult? run(CalcValues values) => validate(values).ok ? compute(values) : null;
}

// ---- Shared helpers --------------------------------------------------------

/// Formats a number with at most [decimals] places and never a trailing zero
/// (content standard: 5 mg, not 5.0 mg).
String fmt(double value, [int decimals = 1]) {
  var text = value.toStringAsFixed(decimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (text == '-0') text = '0';
  return text;
}

/// Rounds to [decimals] places, so bands use the same number that is shown.
double roundTo(double value, int decimals) {
  final factor = math.pow(10, decimals);
  return (value * factor).roundToDouble() / factor;
}

DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Whole days from [from] to [to] (positive when [to] is later).
int dayDiff(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inHours ~/ 24;

DateTime addDays(DateTime d, int days) => dateOnly(d).add(Duration(days: days));

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// e.g. "27 September 2026".
String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// e.g. "32 weeks 4 days".
String weeksDays(int totalDays) {
  final w = totalDays ~/ 7;
  final d = totalDays % 7;
  return '$w ${w == 1 ? 'week' : 'weeks'} $d ${d == 1 ? 'day' : 'days'}';
}

// Common units.
const kg = [UnitOption('kg'), UnitOption('lb', 0.45359237)];
const cm = [UnitOption('cm'), UnitOption('m', 100), UnitOption('in', 2.54)];
const mmolL = [UnitOption('mmol/L')];
const creatinineUnits = [UnitOption('µmol/L'), UnitOption('mg/dL', 88.4)];
const glucoseUnits = [UnitOption('mmol/L'), UnitOption('mg/dL', 1 / 18.016)];
const albuminUnits = [UnitOption('g/L'), UnitOption('g/dL', 10)];
const years = [UnitOption('years')];
const perMin = [UnitOption('/min')];
const mmHg = [UnitOption('mmHg')];

const sexInput = ChoiceInput(
  id: 'sex',
  label: 'Sex',
  options: [CalcOption('Male', 0), CalcOption('Female', 1)],
);
bool isFemale(CalcValues v) => v.c('sex') == 1;

/// Height in cm → body surface or weight inputs.
const heightInput = NumberInput(id: 'height', label: 'Height', units: cm, min: 40, max: 250);
const weightInput = NumberInput(id: 'weight', label: 'Weight', units: kg, min: 0.5, max: 350);
