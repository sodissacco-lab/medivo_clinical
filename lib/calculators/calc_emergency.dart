import 'calc_engine.dart';

// Emergency calculators (blueprint §12). Codes CALC-EM-001 to 007.

// ---- GCS ---------------------------------------------------------------

const gcsNotTestable = -1;

final gcsCalculator = Calculator(
  code: 'CALC-EM-001',
  title: 'Glasgow Coma Scale (GCS)',
  category: 'Emergency',
  synonyms: ['gcs', 'glasgow coma scale', 'coma scale', 'consciousness', 'head injury', 'level of consciousness'],
  purpose: 'Describes level of consciousness from eye, verbal and motor responses.',
  inputs: const [
    ChoiceInput(id: 'eye', label: 'Eye opening', options: [
      CalcOption('4 · Spontaneous', 4),
      CalcOption('3 · To sound', 3),
      CalcOption('2 · To pressure', 2),
      CalcOption('1 · None', 1),
    ]),
    ChoiceInput(id: 'verbal', label: 'Verbal response', options: [
      CalcOption('5 · Orientated', 5),
      CalcOption('4 · Confused', 4),
      CalcOption('3 · Words', 3),
      CalcOption('2 · Sounds', 2),
      CalcOption('1 · None', 1),
      CalcOption('NT · Not testable', gcsNotTestable, 'e.g. intubated or severe facial injury'),
    ]),
    ChoiceInput(id: 'motor', label: 'Best motor response', options: [
      CalcOption('6 · Obeys commands', 6),
      CalcOption('5 · Localising', 5),
      CalcOption('4 · Normal flexion', 4, 'Withdraws from pressure'),
      CalcOption('3 · Abnormal flexion', 3, 'Decorticate'),
      CalcOption('2 · Extension', 2, 'Decerebrate'),
      CalcOption('1 · None', 1),
    ]),
  ],
  compute: (v) {
    final e = v.c('eye');
    final vb = v.c('verbal');
    final m = v.c('motor');
    if (vb == gcsNotTestable) {
      return CalcResult(
        label: 'GCS',
        value: 'E$e VNT M$m',
        warnings: const [
          'A total score cannot be given when the verbal response is not testable. '
              'Record and hand over the components.',
        ],
      );
    }
    final total = e + vb + m;
    final Band band;
    if (total <= 8) {
      band = const Band('Severe (3–8)', Severity.danger,
          'GCS 8 or below: the airway is at risk. Protect the airway and get senior help.');
    } else if (total <= 12) {
      band = const Band('Moderate (9–12)', Severity.caution);
    } else if (total < 15) {
      band = const Band('Mild (13–14)', Severity.caution);
    } else {
      band = const Band('Fully conscious (15)', Severity.normal);
    }
    return CalcResult(
      label: 'GCS',
      value: '$total',
      unit: '/ 15',
      band: band,
      lines: [ResultLine('Components', 'E$e V$vb M$m')],
      warnings: const ['Always report the components (E, V, M) as well as the total.'],
    );
  },
  note: 'For adults and children who can talk. Young children need the paediatric verbal scale.',
  formula: 'GCS = eye (1–4) + verbal (1–5) + motor (1–6); range 3 to 15.',
  reference: 'Teasdale G, Jennett B. Lancet 1974;2:81–4. Teasdale G, et al. The Glasgow Coma Scale at 40 years. '
      'Lancet Neurol 2014;13:844–54.',
);

// ---- NEWS2 ---------------------------------------------------------------

int news2Respiration(double rr) {
  if (rr <= 8) return 3;
  if (rr <= 11) return 1;
  if (rr <= 20) return 0;
  if (rr <= 24) return 2;
  return 3;
}

int news2SpO2Scale1(double s) {
  if (s <= 91) return 3;
  if (s <= 93) return 2;
  if (s <= 95) return 1;
  return 0;
}

int news2SpO2Scale2(double s, {required bool onOxygen}) {
  if (s <= 83) return 3;
  if (s <= 85) return 2;
  if (s <= 87) return 1;
  if (s <= 92 || !onOxygen) return 0;
  if (s <= 94) return 1;
  if (s <= 96) return 2;
  return 3;
}

int news2Systolic(double sbp) {
  if (sbp <= 90) return 3;
  if (sbp <= 100) return 2;
  if (sbp <= 110) return 1;
  if (sbp <= 219) return 0;
  return 3;
}

int news2Pulse(double hr) {
  if (hr <= 40) return 3;
  if (hr <= 50) return 1;
  if (hr <= 90) return 0;
  if (hr <= 110) return 1;
  if (hr <= 130) return 2;
  return 3;
}

int news2Temperature(double t) {
  if (t <= 35.0) return 3;
  if (t <= 36.0) return 1;
  if (t <= 38.0) return 0;
  if (t <= 39.0) return 1;
  return 2;
}

final news2Calculator = Calculator(
  code: 'CALC-EM-002',
  title: 'NEWS2 (National Early Warning Score 2)',
  category: 'Emergency',
  synonyms: ['news2', 'news', 'early warning score', 'ews', 'deterioration', 'vital signs score', 'track and trigger'],
  purpose: 'Detects acute deterioration in adults from routine vital signs.',
  inputs: const [
    NumberInput(id: 'rr', label: 'Respiratory rate', units: perMin, min: 2, max: 80, integer: true),
    ChoiceInput(id: 'scale', label: 'SpO₂ scale', initial: 1, options: [
      CalcOption('Scale 1', 1, 'Most patients'),
      CalcOption('Scale 2', 2, 'Hypercapnic respiratory failure with a prescribed target of 88–92%'),
    ]),
    NumberInput(id: 'spo2', label: 'Oxygen saturation (SpO₂)', units: [UnitOption('%')], min: 50, max: 100, integer: true),
    ChoiceInput(id: 'oxygen', label: 'Breathing', initial: 0, options: [
      CalcOption('Air', 0),
      CalcOption('Oxygen', 1),
    ]),
    NumberInput(id: 'sbp', label: 'Systolic blood pressure', units: mmHg, min: 30, max: 300, integer: true),
    NumberInput(id: 'pulse', label: 'Pulse', units: perMin, min: 20, max: 250, integer: true),
    ChoiceInput(id: 'avpu', label: 'Consciousness', initial: 0, options: [
      CalcOption('Alert', 0),
      CalcOption('New confusion, voice, pain or unresponsive', 1, 'ACVPU: anything other than Alert'),
    ]),
    NumberInput(id: 'temp', label: 'Temperature', units: [UnitOption('°C')], min: 28, max: 44),
  ],
  compute: (v) {
    final onOxygen = v.yes('oxygen');
    final parts = <String, int>{
      'Respiratory rate': news2Respiration(v.n('rr')),
      'SpO₂': v.c('scale') == 2
          ? news2SpO2Scale2(v.n('spo2'), onOxygen: onOxygen)
          : news2SpO2Scale1(v.n('spo2')),
      'Air or oxygen': onOxygen ? 2 : 0,
      'Systolic BP': news2Systolic(v.n('sbp')),
      'Pulse': news2Pulse(v.n('pulse')),
      'Consciousness': v.yes('avpu') ? 3 : 0,
      'Temperature': news2Temperature(v.n('temp')),
    };
    final total = parts.values.fold(0, (a, b) => a + b);
    final redScore = parts.values.any((s) => s == 3);
    return CalcResult(
      label: 'NEWS2',
      value: '$total',
      band: news2Band(total, redScore),
      lines: [for (final e in parts.entries) ResultLine(e.key, '${e.value}')],
    );
  },
  note: 'Adults 16 years and over. Not for children or pregnant women (use obstetric early warning charts).',
  formula: 'Sum of seven parameter scores (0–3 each): respiratory rate, SpO₂ (scale 1 or 2), '
      'air or oxygen (2 if on oxygen), systolic BP, pulse, consciousness (3 if not alert), temperature.',
  reference: 'Royal College of Physicians. National Early Warning Score (NEWS) 2: standardising the '
      'assessment of acute-illness severity in the NHS. London: RCP, 2017.',
);

Band news2Band(int total, bool redScore) {
  if (total >= 7) {
    return const Band('High clinical risk (7 or more)', Severity.danger,
        'Emergency response: immediate assessment by a clinician with critical care skills; '
        'continuous monitoring.');
  }
  if (total >= 5) {
    return const Band('Medium clinical risk (5–6)', Severity.danger,
        'Urgent response: urgent review by a clinician; monitor at least hourly.');
  }
  if (redScore) {
    return const Band('Low–medium risk (a single parameter scored 3)', Severity.caution,
        'Urgent ward-based response: inform the clinician in charge.');
  }
  if (total >= 1) {
    return const Band('Low clinical risk (1–4)', Severity.normal,
        'Nurse to assess and decide on monitoring frequency and escalation.');
  }
  return const Band('Low clinical risk (0)', Severity.normal, 'Continue routine monitoring.');
}

// ---- qSOFA ---------------------------------------------------------------

final qsofaCalculator = Calculator(
  code: 'CALC-EM-003',
  title: 'qSOFA',
  category: 'Emergency',
  synonyms: ['qsofa', 'quick sofa', 'sepsis score', 'sepsis'],
  purpose: 'Identifies adults with suspected infection who are at higher risk of a poor outcome.',
  inputs: const [
    YesNoInput(id: 'rr', label: 'Respiratory rate 22/min or more'),
    YesNoInput(id: 'mental', label: 'Altered mentation (GCS below 15)'),
    YesNoInput(id: 'sbp', label: 'Systolic BP 100 mmHg or less'),
  ],
  compute: (v) {
    final score = [v.yes('rr'), v.yes('mental'), v.yes('sbp')].where((x) => x).length;
    return CalcResult(
      label: 'qSOFA',
      value: '$score',
      unit: '/ 3',
      band: score >= 2
          ? const Band('Higher risk (2 or more)', Severity.danger,
              'Assess for organ dysfunction and sepsis now; start the sepsis protocol and escalate.')
          : const Band('Lower risk (0–1)', Severity.normal,
              'A low score does not rule out sepsis. Keep reassessing.'),
      warnings: const ['qSOFA is not a screening test for sepsis on its own; use it with clinical judgement.'],
    );
  },
  note: 'Adults with suspected infection.',
  formula: 'One point each: respiratory rate ≥22/min; altered mentation; systolic BP ≤100 mmHg.',
  reference: 'Seymour CW, et al. Assessment of clinical criteria for sepsis (Sepsis-3). JAMA 2016;315:762–74. '
      'Evans L, et al. Surviving Sepsis Campaign 2021. Crit Care Med 2021;49:e1063–143.',
);

// ---- Shock index --------------------------------------------------------

final shockIndexCalculator = Calculator(
  code: 'CALC-EM-004',
  title: 'Shock index',
  category: 'Emergency',
  synonyms: ['shock index', 'si', 'haemorrhage', 'hemorrhage', 'hypovolaemia', 'bleeding'],
  purpose: 'Flags hidden shock (e.g. bleeding) when pulse rises before blood pressure falls.',
  inputs: const [
    NumberInput(id: 'pulse', label: 'Heart rate', units: perMin, min: 20, max: 250, integer: true),
    NumberInput(id: 'sbp', label: 'Systolic blood pressure', units: mmHg, min: 30, max: 300, integer: true),
  ],
  compute: (v) {
    final si = roundTo(v.n('pulse') / v.n('sbp'), 2);
    final Band band;
    if (si < 0.7) {
      band = const Band('Within usual range', Severity.normal);
    } else if (si < 1.0) {
      band = const Band('Raised', Severity.caution, 'Look for bleeding, sepsis or dehydration; monitor closely.');
    } else {
      band = const Band('1.0 or more: significant haemodynamic compromise likely', Severity.danger,
          'Treat as shock until proven otherwise; escalate.');
    }
    return CalcResult(label: 'Shock index', value: fmt(si, 2), band: band);
  },
  note: 'Adults. Normal values are higher in children; in pregnancy a raised value of 0.9 or more is concerning.',
  formula: 'Shock index = heart rate ÷ systolic blood pressure',
  reference: 'Allgöwer M, Burri C. Dtsch Med Wochenschr 1967;92:1947–50. '
      'Koch E, et al. Shock index in the emergency department. Scand J Trauma Resusc Emerg Med 2019;27:38.',
);

// ---- Burns TBSA (Lund and Browder) ---------------------------------------

/// Age columns: 0 = under 1, 1 = 1–4, 2 = 5–9, 3 = 10–14, 4 = 15, 5 = adult.
class BurnRegion {
  const BurnRegion(this.id, this.label, this.percentByAge);

  final String id;
  final String label;
  final List<double> percentByAge;
}

const burnRegions = [
  BurnRegion('head', 'Head', [19, 17, 13, 11, 9, 7]),
  BurnRegion('neck', 'Neck', [2, 2, 2, 2, 2, 2]),
  BurnRegion('trunk_front', 'Front of trunk', [13, 13, 13, 13, 13, 13]),
  BurnRegion('trunk_back', 'Back of trunk', [13, 13, 13, 13, 13, 13]),
  BurnRegion('buttock_r', 'Right buttock', [2.5, 2.5, 2.5, 2.5, 2.5, 2.5]),
  BurnRegion('buttock_l', 'Left buttock', [2.5, 2.5, 2.5, 2.5, 2.5, 2.5]),
  BurnRegion('genitalia', 'Genitalia', [1, 1, 1, 1, 1, 1]),
  BurnRegion('upper_arm_r', 'Right upper arm', [4, 4, 4, 4, 4, 4]),
  BurnRegion('upper_arm_l', 'Left upper arm', [4, 4, 4, 4, 4, 4]),
  BurnRegion('forearm_r', 'Right forearm', [3, 3, 3, 3, 3, 3]),
  BurnRegion('forearm_l', 'Left forearm', [3, 3, 3, 3, 3, 3]),
  BurnRegion('hand_r', 'Right hand', [2.5, 2.5, 2.5, 2.5, 2.5, 2.5]),
  BurnRegion('hand_l', 'Left hand', [2.5, 2.5, 2.5, 2.5, 2.5, 2.5]),
  BurnRegion('thigh_r', 'Right thigh', [5.5, 6.5, 8, 8.5, 9, 9.5]),
  BurnRegion('thigh_l', 'Left thigh', [5.5, 6.5, 8, 8.5, 9, 9.5]),
  BurnRegion('leg_r', 'Right lower leg', [5, 5, 5.5, 6, 6.5, 7]),
  BurnRegion('leg_l', 'Left lower leg', [5, 5, 5.5, 6, 6.5, 7]),
  BurnRegion('foot_r', 'Right foot', [3.5, 3.5, 3.5, 3.5, 3.5, 3.5]),
  BurnRegion('foot_l', 'Left foot', [3.5, 3.5, 3.5, 3.5, 3.5, 3.5]),
];

const _burnFractions = [
  CalcOption('None', 0),
  CalcOption('¼', 1),
  CalcOption('½', 2),
  CalcOption('¾', 3),
  CalcOption('All', 4),
];

/// Burned % of total body surface; [fractions] maps region id → quarters (0–4).
double burnTbsa(int ageColumn, Map<String, int> fractions) {
  var total = 0.0;
  for (final region in burnRegions) {
    total += region.percentByAge[ageColumn] * (fractions[region.id] ?? 0) / 4;
  }
  return total;
}

final burnTbsaCalculator = Calculator(
  code: 'CALC-EM-005',
  title: 'Burns: total body surface area (Lund and Browder)',
  category: 'Emergency',
  synonyms: ['tbsa', 'burns', 'burn', 'lund and browder', 'lund browder', 'rule of nines', 'burn area', 'scald'],
  purpose: 'Estimates the percentage of body surface burned, adjusting for age.',
  inputs: [
    const ChoiceInput(id: 'age', label: 'Age', initial: 5, options: [
      CalcOption('Under 1 year', 0),
      CalcOption('1–4 years', 1),
      CalcOption('5–9 years', 2),
      CalcOption('10–14 years', 3),
      CalcOption('15 years', 4),
      CalcOption('Adult', 5),
    ]),
    for (final region in burnRegions)
      ChoiceInput(
        id: region.id,
        label: region.label,
        options: _burnFractions,
        initial: 0,
      ),
  ],
  compute: (v) {
    final age = v.c('age');
    final fractions = {for (final r in burnRegions) r.id: v.choice(r.id) ?? 0};
    final tbsa = roundTo(burnTbsa(age, fractions), 1);
    final child = age <= 3;
    final threshold = child ? 10 : 15;
    final lines = [
      for (final r in burnRegions)
        if ((fractions[r.id] ?? 0) > 0)
          ResultLine(r.label, '${fmt(r.percentByAge[age] * fractions[r.id]! / 4, 2)}%'),
    ];
    return CalcResult(
      label: 'Burned surface area',
      value: fmt(tbsa),
      unit: '% TBSA',
      band: tbsa >= threshold
          ? Band('$threshold% or more (${child ? 'child' : 'adult'})', Severity.danger,
              'Formal IV fluid resuscitation is usually needed: use the Burns fluid calculator. '
              'Discuss with or refer to a burns service.')
          : Band('Below $threshold% (${child ? 'child' : 'adult'})', tbsa == 0 ? Severity.info : Severity.caution,
              'Oral fluids are often enough if the patient can drink. Refer burns of the face, hands, '
              'feet, genitalia or joints, full-thickness, electrical, chemical and inhalation injuries.'),
      lines: lines,
      warnings: const ['Count partial- and full-thickness burns only. Do not include simple redness (erythema).'],
    );
  },
  note: 'For each area, choose how much is burned (partial or full thickness only).',
  formula: 'TBSA = Σ (region % for the age group × fraction of that region burned)\n'
      'Lund and Browder chart: head and legs change with age.',
  reference: 'Lund CC, Browder NC. The estimation of areas of burns. Surg Gynecol Obstet 1944;79:352–8. '
      'ISBI Practice Guidelines for Burn Care. Burns 2016;42:953–1021.',
);

// ---- Burns fluid (Parkland) ---------------------------------------------

/// Holliday–Segar maintenance fluid in mL per 24 hours.
double hollidaySegarDaily(double kg) {
  if (kg <= 10) return 100 * kg;
  if (kg <= 20) return 1000 + 50 * (kg - 10);
  return 1500 + 20 * (kg - 20);
}

final burnFluidCalculator = Calculator(
  code: 'CALC-EM-006',
  title: 'Burns fluid resuscitation (Parkland)',
  category: 'Emergency',
  synonyms: ['parkland', 'burns fluid', 'burn fluids', 'fluid resuscitation burns', 'ringers lactate burns'],
  purpose: 'Calculates the first 24 hours of IV fluid for major burns.',
  inputs: const [
    ChoiceInput(id: 'group', label: 'Patient', initial: 0, options: [
      CalcOption('Adult', 0),
      CalcOption('Child', 1),
    ]),
    NumberInput(id: 'weight', label: 'Weight', units: kg, min: 2, max: 300),
    NumberInput(id: 'tbsa', label: 'Burned area (partial + full thickness)', units: [UnitOption('% TBSA')], min: 1, max: 100),
    NumberInput(
        id: 'hours',
        label: 'Hours since the burn',
        units: [UnitOption('hours')],
        min: 0,
        max: 24,
        hint: 'Time from the burn, not from arrival'),
  ],
  compute: (v) {
    final w = v.n('weight');
    final total = 4 * w * v.n('tbsa');
    final half = total / 2;
    final hours = v.n('hours');
    final child = v.c('group') == 1;
    final lines = <ResultLine>[
      ResultLine('First 8 hours from the burn', '${fmt(half, 0)} mL'),
      ResultLine('Next 16 hours', '${fmt(half, 0)} mL (${fmt(half / 16, 0)} mL/hour)'),
    ];
    final warnings = <String>[];
    if (hours < 8) {
      lines.insert(1, ResultLine('Rate now, until 8 hours after the burn',
          '${fmt(half / (8 - hours), 0)} mL/hour (over ${fmt(8 - hours)} hours)'));
    } else {
      warnings.add('More than 8 hours have passed: the first-half volume is behind schedule. '
          'Discuss with a burns specialist.');
    }
    if (child) {
      final maintenance = hollidaySegarDaily(w);
      lines.add(ResultLine('Plus maintenance fluid (child)',
          '${fmt(maintenance, 0)} mL/24 h (${fmt(maintenance / 24, 0)} mL/hour), with glucose'));
    }
    warnings.addAll([
      'Use Ringer\'s lactate (Hartmann\'s). Adjust hourly to urine output: '
          '${child ? '1 mL/kg/hour (child)' : '0.5 mL/kg/hour (adult)'}.',
      'The formula is a starting point. Too much fluid is as harmful as too little.',
    ]);
    return CalcResult(
      label: 'First 24 hours (Ringer\'s lactate)',
      value: fmt(total, 0),
      unit: 'mL',
      lines: lines,
      warnings: warnings,
    );
  },
  note: 'For burns of 15% TBSA or more in adults and 10% or more in children.',
  formula: 'Total = 4 mL × weight (kg) × % TBSA over 24 hours from the time of the burn;\n'
      'half in the first 8 hours, half over the next 16 hours.\nChildren also receive maintenance fluid.',
  reference: 'Baxter CR, Shires T. Ann N Y Acad Sci 1968;150:874–94. '
      'ISBI Practice Guidelines for Burn Care. Burns 2016;42:953–1021.',
);

// ---- CURB-65 -------------------------------------------------------------

final curb65Calculator = Calculator(
  code: 'CALC-EM-007',
  title: 'CURB-65 (pneumonia severity)',
  category: 'Emergency',
  synonyms: ['curb-65', 'curb65', 'crb-65', 'crb65', 'pneumonia severity', 'community acquired pneumonia'],
  purpose: 'Assesses the severity of community-acquired pneumonia in adults to guide place of care.',
  inputs: const [
    YesNoInput(id: 'confusion', label: 'Confusion (new)'),
    ChoiceInput(id: 'urea', label: 'Urea above 7 mmol/L', initial: 0, options: [
      CalcOption('No', 0),
      CalcOption('Yes', 1),
      CalcOption('Not measured', 2, 'Gives CRB-65'),
    ]),
    YesNoInput(id: 'rr', label: 'Respiratory rate 30/min or more'),
    YesNoInput(id: 'bp', label: 'Systolic BP below 90 or diastolic 60 mmHg or less'),
    YesNoInput(id: 'age', label: 'Age 65 years or more'),
  ],
  compute: (v) {
    final noUrea = v.c('urea') == 2;
    final score = [v.yes('confusion'), v.c('urea') == 1, v.yes('rr'), v.yes('bp'), v.yes('age')]
        .where((x) => x)
        .length;
    final Band band;
    if (noUrea) {
      band = score == 0
          ? const Band('Low risk (CRB-65 = 0)', Severity.normal, 'Usually suitable for home treatment.')
          : score <= 2
              ? const Band('Increased risk (CRB-65 = 1–2)', Severity.caution, 'Consider hospital assessment.')
              : const Band('High risk (CRB-65 = 3–4)', Severity.danger, 'Urgent hospital admission.');
    } else if (score <= 1) {
      band = const Band('Low severity (0–1)', Severity.normal, 'Usually suitable for home treatment.');
    } else if (score == 2) {
      band = const Band('Moderate severity (2)', Severity.caution, 'Consider hospital treatment.');
    } else {
      band = const Band('High severity (3–5)', Severity.danger,
          'Manage in hospital as severe pneumonia; assess for high-dependency care, especially at 4–5.');
    }
    return CalcResult(
      label: noUrea ? 'CRB-65' : 'CURB-65',
      value: '$score',
      unit: noUrea ? '/ 4' : '/ 5',
      band: band,
      warnings: const ['Always combine with clinical judgement, oxygen saturation and social circumstances.'],
    );
  },
  note: 'Adults with community-acquired pneumonia.',
  formula: 'One point each: Confusion; Urea >7 mmol/L; Respiratory rate ≥30/min; '
      'Blood pressure (SBP <90 or DBP ≤60 mmHg); age ≥65. CRB-65 leaves out urea.',
  reference: 'Lim WS, et al. Defining community acquired pneumonia severity on presentation to hospital. '
      'Thorax 2003;58:377–82.',
);

final emergencyCalculators = [
  gcsCalculator,
  news2Calculator,
  qsofaCalculator,
  shockIndexCalculator,
  burnTbsaCalculator,
  burnFluidCalculator,
  curb65Calculator,
];
