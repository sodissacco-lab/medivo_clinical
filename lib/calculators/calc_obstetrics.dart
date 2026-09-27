import 'calc_engine.dart';
import 'calc_general.dart' show bmiOf;

// Obstetric calculators (blueprint §12). Codes CALC-OBS-001 to 005.

const _pregnancyDays = 280;

/// Naegele's rule, adjusted for cycle length.
DateTime eddFromLmp(DateTime lmp, {int cycleDays = 28}) =>
    addDays(lmp, _pregnancyDays + (cycleDays - 28));

/// EDD from a dating scan.
DateTime eddFromScan(DateTime scanDate, int gaDaysAtScan) =>
    addDays(scanDate, _pregnancyDays - gaDaysAtScan);

/// Gestational age in days on [on], from an EDD.
int gaDaysFromEdd(DateTime edd, DateTime on) => _pregnancyDays - dayDiff(on, edd);

String trimester(int gaDays) {
  if (gaDays < 14 * 7) return 'First trimester';
  if (gaDays < 28 * 7) return 'Second trimester';
  return 'Third trimester';
}

List<String> gaWarnings(int gaDays) => [
      if (gaDays > 42 * 7) 'Beyond 42 weeks: check the dates.',
      if (gaDays >= 41 * 7 && gaDays <= 42 * 7) 'Post-dates (41 weeks or more): plan review for induction.',
      if (gaDays < 0) 'The pregnancy dates are in the future. Check the entries.',
    ];

// ---- EDD -------------------------------------------------------------------

bool _byLmp(CalcValues v) => v.choice('method') == 0;
bool _byScan(CalcValues v) => v.choice('method') == 1;

final eddCalculator = Calculator(
  code: 'CALC-OBS-001',
  title: 'Expected date of delivery (EDD)',
  category: 'Obstetrics',
  synonyms: ['edd', 'edc', 'due date', 'expected date of delivery', 'naegele', 'lnmp', 'lmp'],
  purpose: 'Calculates the expected date of delivery from the last menstrual period or a dating scan.',
  inputs: [
    const ChoiceInput(id: 'method', label: 'Date by', initial: 0, options: [
      CalcOption('Last menstrual period', 0),
      CalcOption('Dating ultrasound', 1),
    ]),
    DateInput(id: 'lmp', label: 'First day of last menstrual period', daysBack: 44 * 7, visibleWhen: _byLmp),
    NumberInput(
        id: 'cycle',
        label: 'Usual cycle length (optional)',
        units: const [UnitOption('days')],
        min: 21,
        max: 45,
        integer: true,
        optional: true,
        hint: '28 if not known',
        visibleWhen: _byLmp),
    DateInput(id: 'scan', label: 'Date of the scan', daysBack: 44 * 7, visibleWhen: _byScan),
    NumberInput(
        id: 'scan_weeks',
        label: 'Gestational age at the scan: weeks',
        units: const [UnitOption('weeks')],
        min: 4,
        max: 42,
        integer: true,
        visibleWhen: _byScan),
    NumberInput(
        id: 'scan_days',
        label: 'Gestational age at the scan: days',
        units: const [UnitOption('days')],
        min: 0,
        max: 6,
        integer: true,
        visibleWhen: _byScan),
  ],
  compute: (v) {
    final DateTime edd;
    if (_byScan(v)) {
      edd = eddFromScan(v.d('scan'), v.n('scan_weeks').round() * 7 + v.n('scan_days').round());
    } else {
      edd = eddFromLmp(v.d('lmp'), cycleDays: (v.number('cycle') ?? 28).round());
    }
    final gaToday = gaDaysFromEdd(edd, v.today);
    final toGo = dayDiff(v.today, edd);
    return CalcResult(
      label: 'EDD',
      value: formatDay(edd),
      lines: [
        if (gaToday >= 0) ResultLine('Gestational age today', weeksDays(gaToday)),
        if (gaToday >= 0) ResultLine('Trimester', trimester(gaToday)),
        ResultLine(toGo >= 0 ? 'Days until EDD' : 'Days past EDD', '${toGo.abs()}'),
      ],
      warnings: [
        ...gaWarnings(gaToday),
        if (_byLmp(v))
          'If the LMP is uncertain or the cycle irregular, date by ultrasound, ideally before 14 weeks.',
      ],
    );
  },
  formula: 'LMP: EDD = LMP + 280 days + (cycle length − 28) days (Naegele\'s rule).\n'
      'Scan: EDD = scan date + (280 − gestational age at scan in days).',
  reference: 'ACOG Committee Opinion 700: Methods for estimating the due date. Obstet Gynecol 2017;129:e150–4. '
      'WHO recommendations on antenatal care for a positive pregnancy experience, 2016.',
);

// ---- Gestational age -------------------------------------------------------

bool _fromLmp(CalcValues v) => v.choice('method') == 0;
bool _fromEdd(CalcValues v) => v.choice('method') == 1;

final gestationalAgeCalculator = Calculator(
  code: 'CALC-OBS-002',
  title: 'Gestational age',
  category: 'Obstetrics',
  synonyms: ['gestational age', 'ga', 'weeks pregnant', 'gestation', 'how many weeks'],
  purpose: 'Calculates gestational age on a chosen date from the LMP or a known EDD.',
  inputs: [
    const ChoiceInput(id: 'method', label: 'From', initial: 0, options: [
      CalcOption('Last menstrual period', 0),
      CalcOption('Known EDD', 1),
    ]),
    DateInput(id: 'lmp', label: 'First day of last menstrual period', daysBack: 44 * 7, visibleWhen: _fromLmp),
    DateInput(id: 'edd', label: 'Expected date of delivery', daysBack: 60, daysAhead: 300, visibleWhen: _fromEdd),
    const DateInput(id: 'on', label: 'Gestational age on', daysBack: 44 * 7, daysAhead: 300, defaultToday: true),
  ],
  crossCheck: (v) {
    if (_fromLmp(v) && dayDiff(v.d('lmp'), v.d('on')) < 0) {
      return 'The date to calculate for is before the LMP.';
    }
    return null;
  },
  compute: (v) {
    final edd = _fromEdd(v) ? v.d('edd') : eddFromLmp(v.d('lmp'));
    final ga = gaDaysFromEdd(edd, v.d('on'));
    return CalcResult(
      label: 'Gestational age',
      value: ga < 0 ? 'Not yet pregnant on this date' : weeksDays(ga),
      lines: [
        if (ga >= 0) ResultLine('Trimester', trimester(ga)),
        ResultLine('EDD', formatDay(edd)),
      ],
      warnings: gaWarnings(ga),
    );
  },
  formula: 'Gestational age = date − LMP, or 280 days − (EDD − date).',
  reference: 'ACOG Committee Opinion 700: Methods for estimating the due date. Obstet Gynecol 2017;129:e150–4.',
);

// ---- BMI in pregnancy -----------------------------------------------------

({double low, double high}) recommendedGain(double bmi) {
  if (bmi < 18.5) return (low: 12.5, high: 18.0);
  if (bmi < 25) return (low: 11.5, high: 16.0);
  if (bmi < 30) return (low: 7.0, high: 11.5);
  return (low: 5.0, high: 9.0);
}

final pregnancyBmiCalculator = Calculator(
  code: 'CALC-OBS-003',
  title: 'BMI in pregnancy and weight gain',
  category: 'Obstetrics',
  synonyms: ['bmi pregnancy', 'pregnancy weight gain', 'gestational weight gain', 'booking bmi', 'maternal obesity'],
  purpose: 'Classifies pre-pregnancy (or early booking) BMI and gives the recommended total weight gain.',
  inputs: const [
    NumberInput(
        id: 'weight',
        label: 'Pre-pregnancy or first-trimester weight',
        units: kg,
        min: 25,
        max: 250),
    NumberInput(id: 'height', label: 'Height', units: cm, min: 120, max: 210),
    NumberInput(
        id: 'current', label: 'Current weight (optional)', units: kg, min: 25, max: 280, optional: true),
  ],
  compute: (v) {
    final bmi = roundTo(bmiOf(v.n('weight'), v.n('height')), 1);
    final gain = recommendedGain(bmi);
    final String category;
    final Severity severity;
    if (bmi < 18.5) {
      category = 'Underweight';
      severity = Severity.caution;
    } else if (bmi < 25) {
      category = 'Normal range';
      severity = Severity.normal;
    } else if (bmi < 30) {
      category = 'Overweight';
      severity = Severity.caution;
    } else {
      category = 'Obese';
      severity = Severity.danger;
    }
    final current = v.number('current');
    return CalcResult(
      label: 'Booking BMI',
      value: fmt(bmi),
      unit: 'kg/m²',
      band: Band(category, severity,
          bmi >= 30 ? 'Higher risk of gestational diabetes, pre-eclampsia and complications at delivery.' : null),
      lines: [
        ResultLine('Recommended total gain', '${fmt(gain.low)}–${fmt(gain.high)} kg'),
        if (current != null) ResultLine('Gain so far', '${fmt(current - v.n('weight'))} kg'),
      ],
      warnings: const ['Ranges are for a single baby. Twin pregnancies have higher targets.'],
    );
  },
  formula: 'BMI = weight (kg) ÷ height (m)² using pre-pregnancy weight.\n'
      'Total gain (singleton): underweight 12.5–18 kg; normal 11.5–16 kg; overweight 7–11.5 kg; obese 5–9 kg.',
  reference: 'Institute of Medicine. Weight gain during pregnancy: reexamining the guidelines. '
      'Washington DC: National Academies Press; 2009.',
);

// ---- Bishop score ------------------------------------------------------------

final bishopCalculator = Calculator(
  code: 'CALC-OBS-004',
  title: 'Bishop score',
  category: 'Obstetrics',
  synonyms: ['bishop', 'bishop score', 'cervical score', 'induction of labour', 'induction of labor', 'cervical ripening'],
  purpose: 'Assesses how ready the cervix is for induction of labour.',
  inputs: const [
    ChoiceInput(id: 'dilation', label: 'Dilatation', options: [
      CalcOption('Closed', 0),
      CalcOption('1–2 cm', 1),
      CalcOption('3–4 cm', 2),
      CalcOption('5 cm or more', 3),
    ]),
    ChoiceInput(id: 'effacement', label: 'Effacement', options: [
      CalcOption('0–30%', 0),
      CalcOption('40–50%', 1),
      CalcOption('60–70%', 2),
      CalcOption('80% or more', 3),
    ]),
    ChoiceInput(id: 'station', label: 'Station', options: [
      CalcOption('−3', 0),
      CalcOption('−2', 1),
      CalcOption('−1 or 0', 2),
      CalcOption('+1 or +2', 3),
    ]),
    ChoiceInput(id: 'consistency', label: 'Consistency', options: [
      CalcOption('Firm', 0),
      CalcOption('Medium', 1),
      CalcOption('Soft', 2),
    ]),
    ChoiceInput(id: 'position', label: 'Position', options: [
      CalcOption('Posterior', 0),
      CalcOption('Mid', 1),
      CalcOption('Anterior', 2),
    ]),
  ],
  compute: (v) {
    final score = ['dilation', 'effacement', 'station', 'consistency', 'position']
        .map(v.c)
        .fold(0, (a, b) => a + b);
    final Band band;
    if (score >= 8) {
      band = const Band('Favourable (8 or more)', Severity.normal,
          'Induction is likely to succeed; amniotomy and oxytocin may be used.');
    } else if (score == 7) {
      band = const Band('Intermediate (7)', Severity.info);
    } else {
      band = const Band('Unfavourable (6 or less)', Severity.caution,
          'Cervical ripening (e.g. misoprostol or balloon catheter) is usually needed before induction.');
    }
    return CalcResult(label: 'Bishop score', value: '$score', unit: '/ 13', band: band);
  },
  formula: 'Sum of dilatation (0–3), effacement (0–3), station (0–3), consistency (0–2) and position (0–2).',
  reference: 'Bishop EH. Pelvic scoring for elective induction. Obstet Gynecol 1964;24:266–8. '
      'WHO recommendations for induction of labour, 2011 (updated 2022).',
);

// ---- APGAR -------------------------------------------------------------------

final apgarCalculator = Calculator(
  code: 'CALC-OBS-005',
  title: 'APGAR score',
  category: 'Obstetrics',
  synonyms: ['apgar', 'apgar score', 'newborn score', 'neonatal assessment', 'birth asphyxia'],
  purpose: 'Records the condition of a newborn at 1 and 5 minutes after birth.',
  inputs: const [
    ChoiceInput(id: 'minute', label: 'Time after birth', initial: 1, options: [
      CalcOption('1 minute', 1),
      CalcOption('5 minutes', 5),
      CalcOption('10 minutes', 10),
    ]),
    ChoiceInput(id: 'appearance', label: 'Appearance (colour)', options: [
      CalcOption('Blue or pale all over', 0),
      CalcOption('Body pink, hands and feet blue', 1),
      CalcOption('Pink all over', 2),
    ]),
    ChoiceInput(id: 'pulse', label: 'Pulse (heart rate)', options: [
      CalcOption('Absent', 0),
      CalcOption('Below 100/min', 1),
      CalcOption('100/min or more', 2),
    ]),
    ChoiceInput(id: 'grimace', label: 'Grimace (reflex irritability)', options: [
      CalcOption('No response', 0),
      CalcOption('Grimace', 1),
      CalcOption('Cry, cough or sneeze', 2),
    ]),
    ChoiceInput(id: 'activity', label: 'Activity (muscle tone)', options: [
      CalcOption('Limp', 0),
      CalcOption('Some flexion', 1),
      CalcOption('Active movement', 2),
    ]),
    ChoiceInput(id: 'respiration', label: 'Respiration', options: [
      CalcOption('Absent', 0),
      CalcOption('Weak, irregular or gasping', 1),
      CalcOption('Good, crying', 2),
    ]),
  ],
  compute: (v) {
    final score = ['appearance', 'pulse', 'grimace', 'activity', 'respiration']
        .map(v.c)
        .fold(0, (a, b) => a + b);
    final Band band;
    if (score >= 7) {
      band = const Band('Reassuring (7–10)', Severity.normal);
    } else if (score >= 4) {
      band = const Band('Moderately abnormal (4–6)', Severity.caution,
          'Stimulate, clear the airway if needed, and be ready to ventilate.');
    } else {
      band = const Band('Low (0–3)', Severity.danger, 'Needs immediate resuscitation.');
    }
    return CalcResult(
      label: 'APGAR at ${v.c('minute')} ${v.c('minute') == 1 ? 'minute' : 'minutes'}',
      value: '$score',
      unit: '/ 10',
      band: band,
      warnings: const [
        'Never wait for the APGAR score to start resuscitation: follow Helping Babies Breathe '
            '(start ventilation within the Golden Minute if the baby is not breathing).',
      ],
    );
  },
  formula: 'Sum of appearance, pulse, grimace, activity and respiration (0–2 each).',
  reference: 'Apgar V. A proposal for a new method of evaluation of the newborn infant. '
      'Curr Res Anesth Analg 1953;32:260–7. AAP/ACOG. The Apgar score. Pediatrics 2015;136:819–22.',
);

final obstetricCalculators = [
  eddCalculator,
  gestationalAgeCalculator,
  pregnancyBmiCalculator,
  bishopCalculator,
  apgarCalculator,
];
