// Tests for every calculator formula (blueprint §12: deterministic code).
// Run with:  flutter test test/calculators_test.dart
//
// Expected values were worked out independently from the published
// formulas. A reviewer can check any of them by hand.

import 'package:flutter_test/flutter_test.dart';
import 'package:medivo_clinical/calculators/calc_emergency.dart';
import 'package:medivo_clinical/calculators/calc_engine.dart';
import 'package:medivo_clinical/calculators/calc_general.dart';
import 'package:medivo_clinical/calculators/calc_obstetrics.dart';
import 'package:medivo_clinical/calculators/calc_paediatrics.dart';
import 'package:medivo_clinical/calculators/calculator_registry.dart';

final _today = DateTime.utc(2026, 6, 1);

CalcResult run(Calculator calc, Map<String, Object?> entries) {
  final values = calc.initialValues(_today);
  entries.forEach((k, v) => values[k] = v);
  final validation = calc.validate(values);
  expect(validation.ok, isTrue,
      reason: 'missing ${validation.missing} errors ${validation.errors} ${validation.crossError}');
  return calc.compute(values);
}

void main() {
  group('registry', () {
    test('26 calculators with unique codes, all in a §12 group', () {
      expect(allCalculators.length, 26);
      expect(allCalculators.map((c) => c.code).toSet().length, 26);
      for (final c in allCalculators) {
        expect(calculatorCategories, contains(c.category), reason: c.code);
      }
    });
  });

  group('engine', () {
    test('fmt never shows a trailing zero', () {
      expect(fmt(5.0), '5');
      expect(fmt(0.50, 2), '0.5');
      expect(fmt(22.94), '22.9');
    });

    test('missing and out-of-range entries are caught', () {
      final values = bmiCalculator.initialValues(_today);
      expect(bmiCalculator.validate(values).missing, ['weight', 'height']);
      values['weight'] = 70.0;
      values['height'] = 400.0;
      expect(bmiCalculator.validate(values).errors.keys, ['height']);
      expect(bmiCalculator.run(values), isNull);
    });
  });

  group('general', () {
    test('BMI', () {
      final r = run(bmiCalculator, {'weight': 70.0, 'height': 175.0});
      expect(r.value, '22.9');
      expect(r.band!.label, 'Normal range');
      expect(adultBmiBand(30).label, 'Obesity class I');
      expect(adultBmiBand(18.4).severity, Severity.caution);
    });

    test('BSA', () {
      final r = run(bsaCalculator, {'weight': 70.0, 'height': 175.0});
      expect(r.value, '1.84');
      expect(r.lines.first.value, '1.85 m²');
    });

    test('IBW and adjusted body weight', () {
      expect(idealBodyWeight(female: false, heightCm: 180), closeTo(74.99, 0.01));
      expect(idealBodyWeight(female: true, heightCm: 165), closeTo(56.91, 0.01));
      final r = run(adjustedWeightCalculator, {'sex': 0, 'height': 180.0, 'weight': 120.0});
      expect(r.value, '93');
    });

    test('Cockcroft–Gault', () {
      final male = cockcroftGault(age: 60, weightKg: 70, female: false, creatinineUmolL: 100);
      expect(male, closeTo(68.76, 0.01));
      final r = run(crclCalculator, {'age': 60.0, 'sex': 1, 'weight': 70.0, 'creatinine': 100.0});
      expect(r.value, '58');
      expect(r.band!.label, 'Moderate reduction');
    });

    test('eGFR CKD-EPI 2021', () {
      expect(ckdEpi2021(age: 50, female: true, creatinineUmolL: 88.4), closeTo(68.63, 0.01));
      expect(ckdEpi2021(age: 40, female: false, creatinineUmolL: 70), closeTo(115.09, 0.01));
      final r = run(egfrCalculator, {'age': 50.0, 'sex': 1, 'creatinine': 88.4});
      expect(r.value, '69');
      expect(r.band!.label, startsWith('G2'));
      expect(ckdStage(14).label, startsWith('G5'));
    });

    test('anion gap, with albumin correction', () {
      var r = run(anionGapCalculator, {'sodium': 140.0, 'chloride': 104.0, 'bicarbonate': 24.0});
      expect(r.value, '12');
      expect(r.band!.label, 'Within usual range');
      r = run(anionGapCalculator,
          {'sodium': 140.0, 'chloride': 104.0, 'bicarbonate': 24.0, 'albumin': 20.0});
      expect(r.value, '17');
      expect(r.band!.label, 'High anion gap');
    });

    test('corrected calcium', () {
      final r = run(correctedCalciumCalculator, {'calcium': 2.0, 'albumin': 25.0});
      expect(r.value, '2.3');
      expect(r.band!.label, 'Within usual range');
    });

    test('corrected sodium', () {
      final r = run(correctedSodiumCalculator, {'sodium': 130.0, 'glucose': 30.0});
      expect(r.value, '137');
      expect(r.lines.first.value, '141 mmol/L');
    });

    test('osmolality and gap', () {
      final r = run(osmolalityCalculator, {'sodium': 140.0, 'glucose': 5.0, 'urea': 5.0, 'measured': 310.0});
      expect(r.value, '290');
      expect(r.lines.first.value, '20 mOsm/kg');
      expect(r.warnings.any((w) => w.contains('unmeasured')), isTrue);
    });
  });

  group('emergency', () {
    test('GCS', () {
      var r = run(gcsCalculator, {'eye': 2, 'verbal': 2, 'motor': 4});
      expect(r.value, '8');
      expect(r.band!.severity, Severity.danger);
      r = run(gcsCalculator, {'eye': 3, 'verbal': gcsNotTestable, 'motor': 6});
      expect(r.value, 'E3 VNT M6');
      expect(r.band, isNull);
    });

    test('NEWS2 parameter bands', () {
      expect(news2Respiration(8), 3);
      expect(news2Respiration(21), 2);
      expect(news2SpO2Scale1(94), 1);
      expect(news2SpO2Scale2(95, onOxygen: true), 2);
      expect(news2SpO2Scale2(95, onOxygen: false), 0);
      expect(news2Systolic(220), 3);
      expect(news2Pulse(131), 3);
      expect(news2Temperature(38.1), 1);
      expect(news2Temperature(35.0), 3);
    });

    test('NEWS2 total and response', () {
      // RR 22 (2), SpO2 95 scale 1 (1), oxygen (2), SBP 105 (1), pulse 115 (2), alert (0), temp 38.5 (1) = 9
      final r = run(news2Calculator, {
        'rr': 22.0, 'scale': 1, 'spo2': 95.0, 'oxygen': 1, 'sbp': 105.0,
        'pulse': 115.0, 'avpu': 0, 'temp': 38.5,
      });
      expect(r.value, '9');
      expect(r.band!.severity, Severity.danger);
      expect(news2Band(3, true).label, startsWith('Low–medium'));
      expect(news2Band(5, false).label, startsWith('Medium'));
    });

    test('qSOFA', () {
      final r = run(qsofaCalculator, {'rr': 1, 'mental': 0, 'sbp': 1});
      expect(r.value, '2');
      expect(r.band!.severity, Severity.danger);
    });

    test('shock index', () {
      final r = run(shockIndexCalculator, {'pulse': 120.0, 'sbp': 100.0});
      expect(r.value, '1.2');
      expect(r.band!.severity, Severity.danger);
    });

    test('Lund and Browder tables add up to 100% for every age', () {
      for (var age = 0; age < 6; age++) {
        final all = {for (final r in burnRegions) r.id: 4};
        expect(burnTbsa(age, all), closeTo(100, 1e-9), reason: 'age column $age');
      }
      // Adult: whole head (7) + whole front of trunk (13) = 20
      expect(burnTbsa(5, {'head': 4, 'trunk_front': 4}), 20);
      // Infant: half the head (9.5) + a quarter of the front trunk (3.25) = 12.75
      expect(burnTbsa(0, {'head': 2, 'trunk_front': 1}), 12.75);
    });

    test('Parkland', () {
      final r = run(burnFluidCalculator, {'group': 0, 'weight': 70.0, 'tbsa': 20.0, 'hours': 2.0});
      expect(r.value, '5600');
      expect(r.lines.first.value, '2800 mL');
      expect(r.lines[1].value, startsWith('467 mL/hour')); // 2800 over the 6 hours left
    });

    test('CURB-65 and CRB-65', () {
      var r = run(curb65Calculator, {'confusion': 1, 'urea': 1, 'rr': 0, 'bp': 0, 'age': 1});
      expect(r.value, '3');
      expect(r.label, 'CURB-65');
      r = run(curb65Calculator, {'confusion': 0, 'urea': 2, 'rr': 1, 'bp': 0, 'age': 0});
      expect(r.label, 'CRB-65');
      expect(r.band!.severity, Severity.caution);
    });
  });

  group('paediatrics', () {
    test('weight-based dose with cap and volume', () {
      final d = weightBasedDose(weightKg: 12, mgPerKg: 15, perDay: false, dosesPerDay: 4, mgPerMl: 24);
      expect(d.single, 180);
      expect(d.daily, 720);
      expect(d.volumeMl, 7.5);
      final capped = weightBasedDose(
          weightKg: 50, mgPerKg: 15, perDay: false, dosesPerDay: 4, maxSingleMg: 500);
      expect(capped.single, 500);
      expect(capped.capped, isTrue);
      final perDay = weightBasedDose(weightKg: 10, mgPerKg: 90, perDay: true, dosesPerDay: 2);
      expect(perDay.single, 450);
    });

    test('Holliday–Segar', () {
      expect(hollidaySegarDaily(8), 800);
      expect(hollidaySegarDaily(15), 1250);
      expect(hollidaySegarDaily(25), 1600);
      expect(hollidaySegarHourly(25), 65);
    });

    test('WHO dehydration classification', () {
      expect(classifyDehydration(condition: 2, sunkenEyes: true, drinking: 0, skinPinch: 0),
          DehydrationLevel.severe);
      expect(classifyDehydration(condition: 1, sunkenEyes: true, drinking: 0, skinPinch: 0),
          DehydrationLevel.some);
      expect(classifyDehydration(condition: 2, sunkenEyes: false, drinking: 0, skinPinch: 1),
          DehydrationLevel.some);
      expect(classifyDehydration(condition: 0, sunkenEyes: false, drinking: 1, skinPinch: 0),
          DehydrationLevel.none);
    });

    test('Plan C volumes by age', () {
      final r = run(dehydrationCalculator, {
        'age': 1, 'weight': 8.0, 'condition': 2, 'eyes': 1, 'drinking': 2, 'pinch': 2,
      });
      expect(r.value, 'Severe');
      expect(r.lines[1].label, 'First 1 hour');
      expect(r.lines[1].value, '240 mL');
      expect(r.lines[2].value, '560 mL');
    });

    test('MUAC', () {
      expect(muacBand(11.4, oedema: false).label, startsWith('Severe'));
      expect(muacBand(12.0, oedema: false).label, startsWith('Moderate'));
      expect(muacBand(13.0, oedema: true).label, startsWith('Severe'));
      expect(muacBand(12.5, oedema: false).severity, Severity.normal);
    });
  });

  group('obstetrics', () {
    test('EDD', () {
      expect(eddFromLmp(DateTime.utc(2026, 1, 1)), DateTime.utc(2026, 10, 8));
      expect(eddFromLmp(DateTime.utc(2026, 1, 1), cycleDays: 32), DateTime.utc(2026, 10, 12));
      expect(eddFromScan(DateTime.utc(2026, 3, 1), 10 * 7 + 3), DateTime.utc(2026, 9, 24));
      final r = run(eddCalculator, {'method': 0, 'lmp': DateTime.utc(2026, 1, 1)});
      expect(r.value, '8 October 2026');
      expect(r.lines.first.value, '21 weeks 4 days');
    });

    test('gestational age', () {
      final r = run(gestationalAgeCalculator, {'method': 0, 'lmp': DateTime.utc(2026, 1, 1)});
      expect(r.value, '21 weeks 4 days');
      expect(r.lines.first.value, 'Second trimester');
    });

    test('BMI in pregnancy', () {
      final r = run(pregnancyBmiCalculator, {'weight': 85.0, 'height': 160.0});
      expect(r.value, '33.2');
      expect(r.lines.first.value, '5–9 kg');
    });

    test('Bishop and APGAR', () {
      final b = run(bishopCalculator,
          {'dilation': 2, 'effacement': 2, 'station': 2, 'consistency': 1, 'position': 1});
      expect(b.value, '8');
      expect(b.band!.label, startsWith('Favourable'));
      final a = run(apgarCalculator,
          {'minute': 5, 'appearance': 1, 'pulse': 2, 'grimace': 1, 'activity': 1, 'respiration': 1});
      expect(a.value, '6');
      expect(a.label, 'APGAR at 5 minutes');
    });
  });
}
