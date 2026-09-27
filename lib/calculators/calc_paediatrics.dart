import 'calc_emergency.dart' show hollidaySegarDaily;
import 'calc_engine.dart';

// Paediatric calculators (blueprint §12). Codes CALC-PAED-001 to 004.

// ---- Weight-based dosing ------------------------------------------------

/// Result of a mg/kg dose calculation.
class WeightDose {
  const WeightDose({required this.single, required this.daily, required this.capped, this.volumeMl});

  final double single;
  final double daily;
  final bool capped;
  final double? volumeMl;
}

WeightDose weightBasedDose({
  required double weightKg,
  required double mgPerKg,
  required bool perDay,
  required int dosesPerDay,
  double? maxSingleMg,
  double? mgPerMl,
}) {
  var single = perDay ? mgPerKg * weightKg / dosesPerDay : mgPerKg * weightKg;
  var capped = false;
  if (maxSingleMg != null && single > maxSingleMg) {
    single = maxSingleMg;
    capped = true;
  }
  return WeightDose(
    single: single,
    daily: single * dosesPerDay,
    capped: capped,
    volumeMl: mgPerMl == null ? null : single / mgPerMl,
  );
}

final weightDoseCalculator = Calculator(
  code: 'CALC-PAED-001',
  title: 'Weight-based dose (mg/kg)',
  category: 'Paediatrics',
  synonyms: ['mg/kg', 'weight based dosing', 'paediatric dose', 'pediatric dose', 'child dose', 'dose calculator', 'syrup volume'],
  purpose: 'Turns a mg/kg dose into a single dose, a daily total and, for liquids, a volume.',
  inputs: const [
    NumberInput(id: 'weight', label: 'Weight', units: kg, min: 0.4, max: 150),
    ChoiceInput(id: 'basis', label: 'Dose is given as', initial: 0, options: [
      CalcOption('mg/kg per dose', 0),
      CalcOption('mg/kg per day', 1),
    ]),
    NumberInput(id: 'dose', label: 'Dose', units: [UnitOption('mg/kg')], min: 0.001, max: 500),
    ChoiceInput(id: 'times', label: 'Doses per day', initial: 1, options: [
      CalcOption('Once', 1),
      CalcOption('2 times', 2),
      CalcOption('3 times', 3),
      CalcOption('4 times', 4),
      CalcOption('6 times', 6),
    ]),
    NumberInput(
        id: 'max', label: 'Maximum single dose (optional)', units: [UnitOption('mg')], min: 0.01, max: 100000, optional: true),
    NumberInput(
        id: 'strength',
        label: 'Liquid strength (optional)',
        units: [UnitOption('mg/mL'), UnitOption('mg/5 mL', 0.2)],
        min: 0.001,
        max: 10000,
        optional: true),
  ],
  compute: (v) {
    final dose = weightBasedDose(
      weightKg: v.n('weight'),
      mgPerKg: v.n('dose'),
      perDay: v.c('basis') == 1,
      dosesPerDay: v.c('times'),
      maxSingleMg: v.number('max'),
      mgPerMl: v.number('strength'),
    );
    final volume = dose.volumeMl;
    return CalcResult(
      label: 'Single dose',
      value: fmt(dose.single, 2),
      unit: 'mg',
      lines: [
        ResultLine('Daily total', '${fmt(dose.daily, 2)} mg in ${v.c('times')} '
            '${v.c('times') == 1 ? 'dose' : 'doses'}'),
        if (volume != null) ResultLine('Volume per dose', '${fmt(volume, volume < 1 ? 2 : 1)} mL'),
      ],
      warnings: [
        if (dose.capped) 'The calculated dose was above the maximum, so the maximum single dose is shown.',
        'This tool only does the arithmetic. Check the dose, maximum and interval in the drug\'s monograph.',
      ],
    );
  },
  formula: 'Per-dose basis: single dose = mg/kg × weight; daily = single × doses per day.\n'
      'Per-day basis: daily = mg/kg × weight; single = daily ÷ doses per day.\n'
      'Single dose is capped at the maximum, if given. Volume = single dose ÷ strength (mg/mL).',
  reference: 'Standard dose arithmetic. WHO Model Formulary for Children, 2010.',
);

// ---- Maintenance fluids ---------------------------------------------------

/// 4-2-1 rule in mL per hour.
double hollidaySegarHourly(double kg) {
  if (kg <= 10) return 4 * kg;
  if (kg <= 20) return 40 + 2 * (kg - 10);
  return 60 + (kg - 20);
}

final maintenanceFluidCalculator = Calculator(
  code: 'CALC-PAED-002',
  title: 'Maintenance fluids (Holliday–Segar)',
  category: 'Paediatrics',
  synonyms: ['maintenance fluids', 'holliday segar', '4-2-1', '100 50 20', 'iv fluids child', 'fluid requirement'],
  purpose: 'Calculates daily and hourly maintenance fluid for children beyond the newborn period.',
  inputs: const [NumberInput(id: 'weight', label: 'Weight', units: kg, min: 2.5, max: 120)],
  compute: (v) {
    final w = v.n('weight');
    final daily = hollidaySegarDaily(w);
    return CalcResult(
      label: 'Maintenance fluid',
      value: fmt(daily, 0),
      unit: 'mL/24 h',
      lines: [
        ResultLine('Hourly rate (4-2-1 rule)', '${fmt(hollidaySegarHourly(w), 0)} mL/hour'),
        ResultLine('Daily total ÷ 24', '${fmt(daily / 24, 0)} mL/hour'),
      ],
      warnings: [
        'Not for newborns under 28 days: use the neonatal fluid regimen.',
        'Give by mouth or nasogastric tube when possible. Some conditions (e.g. meningitis, pneumonia, '
            'raised intracranial pressure) need restriction. Use isotonic fluid with glucose if IV.',
        if (daily > 2400) 'Above usual adult requirements; many guidelines cap at 2–2.5 L a day.',
      ],
    );
  },
  note: 'Children older than 28 days.',
  formula: 'Per 24 h: 100 mL/kg for the first 10 kg + 50 mL/kg for the next 10 kg + 20 mL/kg for each kg above 20.\n'
      'Per hour: 4 mL/kg + 2 mL/kg + 1 mL/kg for the same bands.',
  reference: 'Holliday MA, Segar WE. The maintenance need for water in parenteral fluid therapy. '
      'Pediatrics 1957;19:823–32. WHO Pocket Book of Hospital Care for Children, 2013.',
);

// ---- Dehydration (WHO) ---------------------------------------------------

enum DehydrationLevel { none, some, severe }

/// WHO classification: two or more signs in a row decide the class.
/// Levels: condition, drinking and skin pinch 0 (none), 1 (some), 2 (severe);
/// sunken eyes count towards both some and severe.
DehydrationLevel classifyDehydration({
  required int condition,
  required bool sunkenEyes,
  required int drinking,
  required int skinPinch,
}) {
  final levels = [condition, drinking, skinPinch];
  final severe = levels.where((l) => l == 2).length + (sunkenEyes ? 1 : 0);
  final some = levels.where((l) => l >= 1).length + (sunkenEyes ? 1 : 0);
  if (severe >= 2) return DehydrationLevel.severe;
  if (some >= 2) return DehydrationLevel.some;
  return DehydrationLevel.none;
}

final dehydrationCalculator = Calculator(
  code: 'CALC-PAED-003',
  title: 'Dehydration assessment and fluid plan (WHO)',
  category: 'Paediatrics',
  synonyms: ['dehydration', 'diarrhoea', 'diarrhea', 'running stomach', 'ors', 'plan a', 'plan b', 'plan c', 'rehydration'],
  purpose: 'Classifies dehydration in a child with diarrhoea and calculates the WHO Plan A, B or C volumes.',
  inputs: const [
    ChoiceInput(id: 'age', label: 'Age', initial: 3, options: [
      CalcOption('Under 6 months', 0),
      CalcOption('6–11 months', 1),
      CalcOption('12–23 months', 2),
      CalcOption('2–10 years', 3),
      CalcOption('Over 10 years', 4),
    ]),
    NumberInput(id: 'weight', label: 'Weight', units: kg, min: 1, max: 80),
    ChoiceInput(id: 'condition', label: 'General condition', initial: 0, options: [
      CalcOption('Well, alert', 0),
      CalcOption('Restless, irritable', 1),
      CalcOption('Lethargic or unconscious', 2),
    ]),
    ChoiceInput(id: 'eyes', label: 'Eyes', initial: 0, options: [
      CalcOption('Normal', 0),
      CalcOption('Sunken', 1),
    ]),
    ChoiceInput(id: 'drinking', label: 'Offered fluid', initial: 0, options: [
      CalcOption('Drinks normally', 0),
      CalcOption('Drinks eagerly, thirsty', 1),
      CalcOption('Drinks poorly or not able to drink', 2),
    ]),
    ChoiceInput(id: 'pinch', label: 'Skin pinch goes back', initial: 0, options: [
      CalcOption('Immediately', 0),
      CalcOption('Slowly', 1),
      CalcOption('Very slowly (2 seconds or more)', 2),
    ]),
    YesNoInput(id: 'sam', label: 'Severe acute malnutrition'),
  ],
  compute: (v) {
    final w = v.n('weight');
    final age = v.c('age');
    final level = classifyDehydration(
      condition: v.c('condition'),
      sunkenEyes: v.yes('eyes'),
      drinking: v.c('drinking'),
      skinPinch: v.c('pinch'),
    );
    final warnings = <String>[];
    if (v.yes('sam')) {
      warnings.add('Severe acute malnutrition: do NOT use these plans. Follow the malnutrition protocol '
          '(ReSoMal, slow rehydration, no rapid IV fluid unless in shock).');
    }
    final zincLine = ResultLine('Zinc', '${age == 0 ? '10 mg' : '20 mg'} once daily for 10–14 days');
    final Band band;
    final lines = <ResultLine>[];
    switch (level) {
      case DehydrationLevel.severe:
        band = const Band('Severe dehydration · Plan C', Severity.danger,
            'Start IV fluid immediately. If the child can drink, give ORS while the drip is set up.');
        final under12m = age <= 1;
        lines.addAll([
          ResultLine('Ringer\'s lactate (or normal saline)', 'total ${fmt(100 * w, 0)} mL'),
          ResultLine(under12m ? 'First 1 hour' : 'First 30 minutes', '${fmt(30 * w, 0)} mL'),
          ResultLine(under12m ? 'Then over 5 hours' : 'Then over 2½ hours', '${fmt(70 * w, 0)} mL'),
        ]);
        warnings.add('Repeat the first 30 mL/kg once if the radial pulse is still very weak. '
            'Reassess every 15–30 minutes.');
      case DehydrationLevel.some:
        band = const Band('Some dehydration · Plan B', Severity.caution,
            'Give ORS in the clinic over 4 hours, then reassess.');
        lines.add(ResultLine('ORS over 4 hours', '${fmt(75 * w, 0)} mL'));
      case DehydrationLevel.none:
        band = const Band('No dehydration · Plan A', Severity.normal, 'Treat at home with extra fluid and zinc.');
        lines.add(ResultLine('ORS after each loose stool', switch (age) {
          0 || 1 || 2 => '50–100 mL',
          3 => '100–200 mL',
          _ => 'As much as wanted',
        }));
    }
    lines.add(zincLine);
    warnings.add('Continue breastfeeding and feeding. Return at once if the child cannot drink, becomes '
        'more sick, or has blood in the stool.');
    return CalcResult(label: 'Classification', value: switch (level) {
      DehydrationLevel.severe => 'Severe',
      DehydrationLevel.some => 'Some',
      DehydrationLevel.none => 'None',
    }, band: band, lines: lines, warnings: warnings);
  },
  note: 'Children with diarrhoea. Two or more signs in a row decide the class.',
  formula: 'Severe: 2+ of lethargic/unconscious, sunken eyes, not able to drink or drinking poorly, skin pinch very slow.\n'
      'Some: 2+ of restless/irritable, sunken eyes, drinks eagerly, skin pinch slow.\n'
      'Plan B: ORS 75 mL/kg over 4 h. Plan C: 100 mL/kg IV (under 12 months: 30 mL/kg in 1 h then 70 mL/kg in 5 h; '
      '12 months and over: 30 mL/kg in 30 min then 70 mL/kg in 2½ h).',
  reference: 'World Health Organization. The treatment of diarrhoea: a manual for physicians and other senior health '
      'workers. 4th rev. 2005. WHO Pocket Book of Hospital Care for Children, 2013.',
);

// ---- Growth and nutrition (MUAC) ----------------------------------------

Band muacBand(double muacCm, {required bool oedema}) {
  if (oedema) {
    return const Band('Severe acute malnutrition (oedematous)', Severity.danger,
        'Bilateral pitting oedema means SAM whatever the MUAC. Assess for complications; '
        'inpatient care if complicated.');
  }
  if (muacCm < 11.5) {
    return const Band('Severe acute malnutrition (SAM)', Severity.danger,
        'Assess appetite and medical complications; start the SAM protocol (outpatient or inpatient).');
  }
  if (muacCm < 12.5) {
    return const Band('Moderate acute malnutrition (MAM)', Severity.caution,
        'Enrol in supplementary feeding and follow up.');
  }
  return const Band('No acute malnutrition by MUAC', Severity.normal);
}

final muacCalculator = Calculator(
  code: 'CALC-PAED-004',
  title: 'Growth and nutrition (MUAC)',
  category: 'Paediatrics',
  synonyms: ['muac', 'mid upper arm circumference', 'malnutrition', 'sam', 'mam', 'growth', 'wasting', 'kwashiorkor'],
  purpose: 'Classifies acute malnutrition in children aged 6 to 59 months from MUAC and oedema.',
  inputs: const [
    NumberInput(id: 'age', label: 'Age', units: [UnitOption('months')], min: 6, max: 59, integer: true),
    NumberInput(id: 'muac', label: 'MUAC', units: [UnitOption('cm'), UnitOption('mm', 0.1)], min: 5, max: 30),
    YesNoInput(id: 'oedema', label: 'Bilateral pitting oedema'),
  ],
  compute: (v) {
    final muac = roundTo(v.n('muac'), 1);
    return CalcResult(
      label: 'MUAC',
      value: fmt(muac),
      unit: 'cm',
      band: muacBand(muac, oedema: v.yes('oedema')),
      warnings: const [
        'Also plot weight-for-height and height-for-age on WHO growth charts. '
            'WHO z-score calculations will be added once the WHO growth tables are imported and checked.',
      ],
    );
  },
  note: 'Children 6 to 59 months.',
  formula: 'MUAC below 11.5 cm or bilateral pitting oedema: SAM. 11.5 to below 12.5 cm: MAM. 12.5 cm or more: no acute malnutrition.',
  reference: 'WHO and UNICEF. WHO child growth standards and the identification of severe acute malnutrition '
      'in infants and children. 2009. WHO guideline on the prevention and management of wasting and '
      'nutritional oedema in infants and children, 2023.',
);

final paediatricCalculators = [
  weightDoseCalculator,
  maintenanceFluidCalculator,
  dehydrationCalculator,
  muacCalculator,
];
