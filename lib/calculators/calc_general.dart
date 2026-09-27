import 'dart:math' as math;

import 'calc_engine.dart';

// General calculators (blueprint §12). Codes CALC-GEN-001 to 010.

Band adultBmiBand(double bmi) {
  if (bmi < 16) return const Band('Severe thinness', Severity.danger);
  if (bmi < 17) return const Band('Moderate thinness', Severity.caution);
  if (bmi < 18.5) return const Band('Mild thinness (underweight)', Severity.caution);
  if (bmi < 25) return const Band('Normal range', Severity.normal);
  if (bmi < 30) return const Band('Overweight (pre-obese)', Severity.caution);
  if (bmi < 35) return const Band('Obesity class I', Severity.caution);
  if (bmi < 40) return const Band('Obesity class II', Severity.danger);
  return const Band('Obesity class III', Severity.danger);
}

double bmiOf(double weightKg, double heightCm) {
  final m = heightCm / 100;
  return weightKg / (m * m);
}

final bmiCalculator = Calculator(
  code: 'CALC-GEN-001',
  title: 'Body mass index (BMI)',
  category: 'General',
  synonyms: ['bmi', 'body mass index', 'obesity', 'underweight', 'quetelet'],
  purpose: 'Classifies body weight relative to height in adults.',
  inputs: const [weightInput, heightInput],
  compute: (v) {
    final bmi = roundTo(bmiOf(v.n('weight'), v.n('height')), 1);
    return CalcResult(label: 'BMI', value: fmt(bmi), unit: 'kg/m²', band: adultBmiBand(bmi));
  },
  note: 'Adults 18 years and over. Children and adolescents need BMI-for-age on WHO growth charts. '
      'In pregnancy use the BMI in pregnancy calculator.',
  formula: 'BMI = weight (kg) ÷ height (m)²',
  reference: 'World Health Organization. Obesity: preventing and managing the global epidemic. '
      'WHO Technical Report Series 894, 2000.',
);

double mosteller(double weightKg, double heightCm) => math.sqrt(heightCm * weightKg / 3600);
double duBois(double weightKg, double heightCm) =>
    (0.007184 * math.pow(weightKg, 0.425) * math.pow(heightCm, 0.725)).toDouble();

final bsaCalculator = Calculator(
  code: 'CALC-GEN-002',
  title: 'Body surface area (BSA)',
  category: 'General',
  synonyms: ['bsa', 'body surface area', 'mosteller', 'du bois', 'chemotherapy dosing'],
  purpose: 'Estimates body surface area, used for some drug doses (e.g. chemotherapy) and indexing.',
  inputs: const [weightInput, heightInput],
  compute: (v) {
    final m = mosteller(v.n('weight'), v.n('height'));
    final d = duBois(v.n('weight'), v.n('height'));
    return CalcResult(
      label: 'BSA (Mosteller)',
      value: fmt(roundTo(m, 2), 2),
      unit: 'm²',
      lines: [ResultLine('BSA (Du Bois)', '${fmt(roundTo(d, 2), 2)} m²')],
    );
  },
  formula: 'Mosteller: BSA (m²) = √(height (cm) × weight (kg) ÷ 3600)\n'
      'Du Bois: BSA (m²) = 0.007184 × weight (kg)^0.425 × height (cm)^0.725',
  reference: 'Mosteller RD. Simplified calculation of body-surface area. N Engl J Med 1987;317:1098. '
      'Du Bois D, Du Bois EF. Arch Intern Med 1916;17:863–71.',
);

/// Devine ideal body weight in kg.
double idealBodyWeight({required bool female, required double heightCm}) {
  final inches = heightCm / 2.54;
  return (female ? 45.5 : 50) + 2.3 * (inches - 60);
}

const _adultHeight =
    NumberInput(id: 'height', label: 'Height', units: cm, min: 120, max: 250);

final ibwCalculator = Calculator(
  code: 'CALC-GEN-003',
  title: 'Ideal body weight (IBW)',
  category: 'General',
  synonyms: ['ibw', 'ideal body weight', 'devine', 'lean weight'],
  purpose: 'Estimates ideal body weight in adults, used for some drug doses and ventilator settings.',
  inputs: const [sexInput, _adultHeight],
  compute: (v) {
    final ibw = idealBodyWeight(female: isFemale(v), heightCm: v.n('height'));
    return CalcResult(
      label: 'Ideal body weight',
      value: fmt(roundTo(ibw, 1)),
      unit: 'kg',
      lines: [ResultLine('Height', '${fmt(v.n('height') / 2.54)} in')],
      warnings: [
        if (v.n('height') < 152.4)
          'The Devine formula was derived for heights of 152 cm (5 ft) and above; '
              'below this the result is an extrapolation.',
      ],
    );
  },
  note: 'Adults only.',
  formula: 'Men: IBW (kg) = 50 + 2.3 × (height in inches − 60)\n'
      'Women: IBW (kg) = 45.5 + 2.3 × (height in inches − 60)',
  reference: 'Devine BJ. Gentamicin therapy. Drug Intell Clin Pharm 1974;8:650–5.',
);

final adjustedWeightCalculator = Calculator(
  code: 'CALC-GEN-004',
  title: 'Adjusted body weight',
  category: 'General',
  synonyms: ['abw', 'adjusted body weight', 'dosing weight', 'obesity dosing'],
  purpose: 'Estimates a dosing weight for adults with obesity, between ideal and actual weight.',
  inputs: const [
    sexInput,
    _adultHeight,
    NumberInput(id: 'weight', label: 'Actual weight', units: kg, min: 30, max: 350),
  ],
  compute: (v) {
    final ibw = idealBodyWeight(female: isFemale(v), heightCm: v.n('height'));
    final actual = v.n('weight');
    final adjusted = ibw + 0.4 * (actual - ibw);
    final percent = actual / ibw * 100;
    return CalcResult(
      label: 'Adjusted body weight',
      value: fmt(roundTo(adjusted, 1)),
      unit: 'kg',
      lines: [
        ResultLine('Ideal body weight', '${fmt(roundTo(ibw, 1))} kg'),
        ResultLine('Actual weight', '${fmt(actual)} kg (${fmt(percent, 0)}% of ideal)'),
      ],
      warnings: [
        if (actual <= ibw)
          'Actual weight is at or below ideal body weight: adjusted body weight does not apply. '
              'Use actual weight.'
        else if (percent < 120)
          'Adjusted body weight is usually used only when actual weight is more than 120% of ideal.',
        'Always follow the dosing weight named in the drug\'s own guidance.',
      ],
    );
  },
  note: 'Adults only.',
  formula: 'Adjusted body weight = IBW + 0.4 × (actual weight − IBW)\nIBW by the Devine formula.',
  reference: 'Bauer LA. Applied Clinical Pharmacokinetics. 3rd ed. McGraw-Hill; 2014. '
      'Devine BJ. Drug Intell Clin Pharm 1974;8:650–5.',
);

double creatinineMgDl(double umolL) => umolL / 88.4;

/// Cockcroft–Gault creatinine clearance in mL/min.
double cockcroftGault({
  required double age,
  required double weightKg,
  required bool female,
  required double creatinineUmolL,
}) =>
    (140 - age) * weightKg * (female ? 0.85 : 1) / (72 * creatinineMgDl(creatinineUmolL));

const _age = NumberInput(id: 'age', label: 'Age', units: years, min: 18, max: 120, integer: true);
const _creatinine =
    NumberInput(id: 'creatinine', label: 'Serum creatinine', units: creatinineUnits, min: 20, max: 2000);

Band kidneyFunctionBand(double value) {
  if (value >= 60) return const Band('No more than mild reduction', Severity.normal);
  if (value >= 30) return const Band('Moderate reduction', Severity.caution,
      'Check the renal dosing section of every drug.');
  if (value >= 15) return const Band('Severe reduction', Severity.danger,
      'Check the renal dosing section of every drug. Avoid nephrotoxic drugs where possible.');
  return const Band('Kidney failure range', Severity.danger,
      'Many drugs need dose reduction or avoidance. Seek specialist advice.');
}

final crclCalculator = Calculator(
  code: 'CALC-GEN-005',
  title: 'Creatinine clearance (Cockcroft–Gault)',
  category: 'General',
  synonyms: ['crcl', 'creatinine clearance', 'cockcroft gault', 'renal dosing', 'kidney function'],
  purpose: 'Estimates creatinine clearance in adults, mainly for adjusting drug doses in kidney impairment.',
  inputs: const [
    _age,
    sexInput,
    NumberInput(id: 'weight', label: 'Weight', units: kg, min: 30, max: 300),
    _creatinine,
  ],
  compute: (v) {
    final crcl = cockcroftGault(
      age: v.n('age'),
      weightKg: v.n('weight'),
      female: isFemale(v),
      creatinineUmolL: v.n('creatinine'),
    );
    final shown = roundTo(crcl, 0);
    return CalcResult(
      label: 'Creatinine clearance',
      value: fmt(shown, 0),
      unit: 'mL/min',
      band: kidneyFunctionBand(shown),
      lines: [ResultLine('Creatinine', '${fmt(creatinineMgDl(v.n('creatinine')), 2)} mg/dL')],
      warnings: const [
        'Not valid when creatinine is changing quickly (acute kidney injury).',
        'Uses the weight entered. In obesity many drug guides use ideal or adjusted body weight.',
      ],
    );
  },
  note: 'Adults only.',
  formula: 'CrCl (mL/min) = (140 − age) × weight (kg) × 0.85 if female ÷ (72 × creatinine (mg/dL))\n'
      'Creatinine mg/dL = µmol/L ÷ 88.4',
  reference: 'Cockcroft DW, Gault MH. Prediction of creatinine clearance from serum creatinine. '
      'Nephron 1976;16:31–41.',
);

/// CKD-EPI 2021 (race-free) eGFR in mL/min/1.73 m².
double ckdEpi2021({required double age, required bool female, required double creatinineUmolL}) {
  final scr = creatinineMgDl(creatinineUmolL);
  final kappa = female ? 0.7 : 0.9;
  final alpha = female ? -0.241 : -0.302;
  final ratio = scr / kappa;
  return (142 *
          math.pow(math.min(ratio, 1.0), alpha) *
          math.pow(math.max(ratio, 1.0), -1.200) *
          math.pow(0.9938, age) *
          (female ? 1.012 : 1.0))
      .toDouble();
}

Band ckdStage(double egfr) {
  if (egfr >= 90) return const Band('G1 · Normal or high', Severity.normal,
      'CKD only if there is other evidence of kidney damage (e.g. albuminuria).');
  if (egfr >= 60) return const Band('G2 · Mildly decreased', Severity.normal,
      'CKD only if there is other evidence of kidney damage (e.g. albuminuria).');
  if (egfr >= 45) return const Band('G3a · Mildly to moderately decreased', Severity.caution);
  if (egfr >= 30) return const Band('G3b · Moderately to severely decreased', Severity.caution);
  if (egfr >= 15) return const Band('G4 · Severely decreased', Severity.danger);
  return const Band('G5 · Kidney failure', Severity.danger);
}

final egfrCalculator = Calculator(
  code: 'CALC-GEN-006',
  title: 'eGFR (CKD-EPI 2021)',
  category: 'General',
  synonyms: ['egfr', 'gfr', 'ckd-epi', 'kidney function', 'renal function', 'ckd stage', 'chronic kidney disease'],
  purpose: 'Estimates glomerular filtration rate in adults to detect and stage chronic kidney disease.',
  inputs: const [_age, sexInput, _creatinine],
  compute: (v) {
    final egfr = roundTo(
        ckdEpi2021(age: v.n('age'), female: isFemale(v), creatinineUmolL: v.n('creatinine')), 0);
    return CalcResult(
      label: 'eGFR',
      value: fmt(egfr, 0),
      unit: 'mL/min/1.73 m²',
      band: ckdStage(egfr),
      warnings: const [
        'CKD staging needs results persisting for more than 3 months.',
        'Not valid in acute kidney injury, pregnancy, or extremes of muscle mass.',
      ],
    );
  },
  note: 'Adults only. Uses the 2021 equation without a race coefficient.',
  formula: 'eGFR = 142 × min(Scr/κ, 1)^α × max(Scr/κ, 1)^−1.200 × 0.9938^age × 1.012 if female\n'
      'Scr in mg/dL; κ = 0.7 (female) or 0.9 (male); α = −0.241 (female) or −0.302 (male)',
  reference: 'Inker LA, et al. New creatinine- and cystatin C-based equations to estimate GFR without race. '
      'N Engl J Med 2021;385:1737–49. KDIGO 2024 CKD guideline (GFR categories).',
);

const _sodium = NumberInput(id: 'sodium', label: 'Sodium (Na⁺)', units: mmolL, min: 90, max: 200);

final anionGapCalculator = Calculator(
  code: 'CALC-GEN-007',
  title: 'Anion gap',
  category: 'General',
  synonyms: ['anion gap', 'ag', 'metabolic acidosis', 'hagma'],
  purpose: 'Helps sort the causes of metabolic acidosis.',
  inputs: const [
    _sodium,
    NumberInput(id: 'chloride', label: 'Chloride (Cl⁻)', units: mmolL, min: 50, max: 150),
    NumberInput(id: 'bicarbonate', label: 'Bicarbonate (HCO₃⁻)', units: mmolL, min: 1, max: 60),
    NumberInput(
        id: 'albumin', label: 'Albumin (optional)', units: albuminUnits, min: 5, max: 70, optional: true),
  ],
  compute: (v) {
    final ag = v.n('sodium') - (v.n('chloride') + v.n('bicarbonate'));
    final albumin = v.number('albumin');
    final corrected = albumin == null ? null : ag + 0.25 * (40 - albumin);
    final judged = roundTo(corrected ?? ag, 1);
    final Band band;
    if (judged > 12) {
      band = const Band('High anion gap', Severity.caution,
          'Consider lactic acidosis, ketoacidosis, kidney failure and toxins '
          '(e.g. methanol, ethylene glycol, salicylate). Interpret with pH and bicarbonate.');
    } else if (judged >= 8) {
      band = const Band('Within usual range', Severity.normal,
          'If acidosis is present with a normal gap, consider bicarbonate loss (diarrhoea) or renal tubular acidosis.');
    } else {
      band = const Band('Low anion gap', Severity.info,
          'Often due to low albumin or laboratory error.');
    }
    return CalcResult(
      label: corrected == null ? 'Anion gap' : 'Albumin-corrected anion gap',
      value: fmt(judged),
      unit: 'mmol/L',
      band: band,
      lines: [if (corrected != null) ResultLine('Uncorrected anion gap', '${fmt(roundTo(ag, 1))} mmol/L')],
      warnings: const ['Usual range varies by laboratory; commonly about 8–12 mmol/L without potassium.'],
    );
  },
  formula: 'Anion gap = Na⁺ − (Cl⁻ + HCO₃⁻)\n'
      'Albumin-corrected anion gap = anion gap + 0.25 × (40 − albumin (g/L))',
  reference: 'Kraut JA, Madias NE. Serum anion gap: its uses and limitations in clinical medicine. '
      'Clin J Am Soc Nephrol 2007;2:162–74. Figge J, et al. Crit Care Med 1998;26:1807–10.',
);

final correctedCalciumCalculator = Calculator(
  code: 'CALC-GEN-008',
  title: 'Corrected calcium',
  category: 'General',
  synonyms: ['corrected calcium', 'adjusted calcium', 'calcium albumin', 'hypocalcaemia', 'hypercalcaemia', 'hypocalcemia', 'hypercalcemia'],
  purpose: 'Adjusts total serum calcium for a low or high albumin.',
  inputs: const [
    NumberInput(
        id: 'calcium',
        label: 'Total calcium',
        units: [UnitOption('mmol/L'), UnitOption('mg/dL', 1 / 4.008)],
        min: 0.5,
        max: 5),
    NumberInput(id: 'albumin', label: 'Albumin', units: albuminUnits, min: 5, max: 70),
  ],
  compute: (v) {
    final corrected = roundTo(v.n('calcium') + 0.02 * (40 - v.n('albumin')), 2);
    final Band band;
    if (corrected < 2.2) {
      band = const Band('Low (hypocalcaemia)', Severity.caution);
    } else if (corrected <= 2.6) {
      band = const Band('Within usual range', Severity.normal);
    } else {
      band = const Band('High (hypercalcaemia)', Severity.caution);
    }
    return CalcResult(
      label: 'Corrected calcium',
      value: fmt(corrected, 2),
      unit: 'mmol/L',
      band: band,
      lines: [ResultLine('In conventional units', '${fmt(corrected * 4.008, 1)} mg/dL')],
      warnings: const [
        'Usual range varies by laboratory; commonly 2.2–2.6 mmol/L.',
        'Unreliable in critical illness and kidney failure: measure ionised calcium where available.',
      ],
    );
  },
  formula: 'Corrected Ca (mmol/L) = measured Ca + 0.02 × (40 − albumin (g/L))\n'
      '(conventional: Ca (mg/dL) + 0.8 × (4 − albumin (g/dL)))',
  reference: 'Payne RB, et al. Interpretation of serum calcium in patients with abnormal serum proteins. '
      'BMJ 1973;4:643–6.',
);

final correctedSodiumCalculator = Calculator(
  code: 'CALC-GEN-009',
  title: 'Corrected sodium (hyperglycaemia)',
  category: 'General',
  synonyms: ['corrected sodium', 'sodium correction', 'pseudohyponatraemia', 'dka sodium', 'hyperglycemia sodium', 'katz', 'hillier'],
  purpose: 'Estimates what the sodium would be if the high blood glucose were corrected, e.g. in DKA or HHS.',
  inputs: const [
    _sodium,
    NumberInput(id: 'glucose', label: 'Blood glucose', units: glucoseUnits, min: 1, max: 150),
  ],
  compute: (v) {
    final na = v.n('sodium');
    final glucoseMgDl = v.n('glucose') * 18.016;
    final excess = math.max(0.0, (glucoseMgDl - 100) / 100);
    final katz = roundTo(na + 1.6 * excess, 0);
    final hillier = roundTo(na + 2.4 * excess, 0);
    final Band band;
    if (katz < 135) {
      band = const Band('Low (hyponatraemia)', Severity.caution);
    } else if (katz <= 145) {
      band = const Band('Within usual range', Severity.normal);
    } else {
      band = const Band('High (hypernatraemia)', Severity.caution,
          'Suggests significant water deficit. Correct slowly.');
    }
    return CalcResult(
      label: 'Corrected sodium (Katz)',
      value: fmt(katz, 0),
      unit: 'mmol/L',
      band: band,
      lines: [
        ResultLine('Corrected sodium (Hillier)', '${fmt(hillier, 0)} mmol/L'),
        ResultLine('Glucose', '${fmt(glucoseMgDl, 0)} mg/dL'),
      ],
      warnings: [
        if (excess == 0) 'Glucose is not raised, so no correction is needed.',
      ],
    );
  },
  formula: 'Katz: corrected Na = Na + 1.6 × (glucose (mg/dL) − 100) ÷ 100\n'
      'Hillier: corrected Na = Na + 2.4 × (glucose (mg/dL) − 100) ÷ 100\n'
      'Glucose mg/dL = mmol/L × 18',
  reference: 'Katz MA. Hyperglycemia-induced hyponatremia. N Engl J Med 1973;289:843–4. '
      'Hillier TA, et al. Am J Med 1999;106:399–403.',
);

final osmolalityCalculator = Calculator(
  code: 'CALC-GEN-010',
  title: 'Serum osmolality and osmolal gap',
  category: 'General',
  synonyms: ['osmolality', 'osmolarity', 'osmolal gap', 'osmolar gap', 'hhs', 'toxic alcohol', 'methanol'],
  purpose: 'Calculates serum osmolality and, with a measured value, the osmolal gap.',
  inputs: const [
    _sodium,
    NumberInput(id: 'glucose', label: 'Blood glucose', units: glucoseUnits, min: 1, max: 150),
    NumberInput(
        id: 'urea',
        label: 'Urea',
        units: [UnitOption('mmol/L'), UnitOption('mg/dL BUN', 0.357)],
        min: 0.5,
        max: 150),
    NumberInput(
        id: 'measured',
        label: 'Measured osmolality (optional)',
        units: [UnitOption('mOsm/kg')],
        min: 200,
        max: 500,
        optional: true),
  ],
  compute: (v) {
    final calculated = roundTo(2 * v.n('sodium') + v.n('glucose') + v.n('urea'), 0);
    final measured = v.number('measured');
    final Band band;
    if (calculated < 275) {
      band = const Band('Low', Severity.caution);
    } else if (calculated <= 295) {
      band = const Band('Within usual range', Severity.normal);
    } else if (calculated <= 320) {
      band = const Band('High', Severity.caution);
    } else {
      band = const Band('Very high', Severity.danger, 'Above 320 mOsm/kg supports HHS when glucose is high.');
    }
    final lines = <ResultLine>[];
    final warnings = <String>['Usual range is about 275–295 mOsm/kg.'];
    if (measured != null) {
      final gap = roundTo(measured - calculated, 0);
      lines.add(ResultLine('Osmolal gap', '${fmt(gap, 0)} mOsm/kg'));
      if (gap > 10) {
        warnings.add('Osmolal gap above 10 suggests unmeasured osmoles, e.g. ethanol, methanol, '
            'ethylene glycol or mannitol.');
      }
    }
    return CalcResult(
      label: 'Calculated osmolality',
      value: fmt(calculated, 0),
      unit: 'mOsm/kg',
      band: band,
      lines: lines,
      warnings: warnings,
    );
  },
  formula: 'Calculated osmolality = 2 × Na⁺ + glucose + urea (all mmol/L)\n'
      'Osmolal gap = measured − calculated',
  reference: 'Kraut JA, Xing SX. Approach to the evaluation of a patient with an increased serum osmolal gap. '
      'Am J Kidney Dis 2011;58:480–4.',
);

final generalCalculators = [
  bmiCalculator,
  bsaCalculator,
  ibwCalculator,
  adjustedWeightCalculator,
  crclCalculator,
  egfrCalculator,
  anionGapCalculator,
  correctedCalciumCalculator,
  correctedSodiumCalculator,
  osmolalityCalculator,
];
