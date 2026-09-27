// Tests for the drug interaction checker's matching rules (blueprint §15).
// Run with:  flutter test test/interactions_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medivo_clinical/interactions/interaction_engine.dart';

InteractionTerm drug(String key, String name, {List<String> classes = const [], List<String> synonyms = const []}) =>
    InteractionTerm(key: key, name: name, isClass: false, classes: classes, synonyms: synonyms);

InteractionTerm cls(String key, String name) => InteractionTerm(key: key, name: name, isClass: true);

int _n = 0;
DrugInteraction rule(String a, String b, String severity) => DrugInteraction(
      id: 'id${_n++}',
      code: 'INT-$_n',
      termA: a,
      termB: b,
      severity: interactionSeverityFrom(severity),
      summary: '$a + $b',
      status: 'published',
    );

void main() {
  final index = InteractionIndex(
    terms: [
      cls('class:strong-inducer', 'Strong enzyme inducers'),
      cls('class:strong-cyp3a4-inhibitor', 'Strong CYP3A4 inhibitors'),
      cls('class:nsaid', 'NSAIDs'),
      cls('class:antiplatelet-anticoagulant', 'Antiplatelets and anticoagulants'),
      drug('rifampicin', 'Rifampicin', classes: ['class:strong-inducer'], synonyms: ['RHZE']),
      drug('carbamazepine', 'Carbamazepine', classes: ['class:strong-inducer']),
      drug('nevirapine', 'Nevirapine', synonyms: ['NVP']),
      drug('dolutegravir', 'Dolutegravir', synonyms: ['DTG', 'TLD']),
      drug('tenofovir', 'Tenofovir disoproxil (TDF)', synonyms: ['TDF', 'TLD']),
      drug('warfarin', 'Warfarin', classes: ['class:antiplatelet-anticoagulant']),
      drug('metronidazole', 'Metronidazole', synonyms: ['Flagyl']),
      drug('aspirin', 'Aspirin', classes: ['class:nsaid', 'class:antiplatelet-anticoagulant']),
      drug('clarithromycin', 'Clarithromycin', classes: ['class:strong-cyp3a4-inhibitor']),
      drug('lopinavir-ritonavir', 'Lopinavir/ritonavir', classes: ['class:strong-cyp3a4-inhibitor']),
      drug('simvastatin', 'Simvastatin'),
      drug('paracetamol', 'Paracetamol'),
    ],
    interactions: [
      rule('rifampicin', 'nevirapine', 'contraindicated'),
      rule('class:strong-inducer', 'nevirapine', 'major'),
      rule('rifampicin', 'dolutegravir', 'major'),
      rule('warfarin', 'metronidazole', 'major'),
      rule('warfarin', 'class:nsaid', 'major'),
      rule('class:strong-inducer', 'warfarin', 'major'),
      rule('class:strong-cyp3a4-inhibitor', 'simvastatin', 'contraindicated'),
      rule('clarithromycin', 'simvastatin', 'contraindicated'),
      rule('warfarin', 'paracetamol', 'minor'),
    ],
  );

  test('finds a drug-to-drug interaction in either order', () {
    expect(index.check(['warfarin', 'metronidazole']).single.interaction.severity, InteractionSeverity.major);
    expect(index.check(['metronidazole', 'warfarin']).length, 1);
  });

  test('the most specific entry wins over a class entry', () {
    final hits = index.check(['rifampicin', 'nevirapine']);
    expect(hits.length, 1);
    expect(hits.single.interaction.severity, InteractionSeverity.contraindicated);
  });

  test('class entries apply to every member of the class', () {
    final hits = index.check(['carbamazepine', 'nevirapine']);
    expect(hits.single.interaction.termA, 'class:strong-inducer');
    expect(index.check(['lopinavir-ritonavir', 'simvastatin']).single.interaction.severity,
        InteractionSeverity.contraindicated);
    expect(index.check(['aspirin', 'warfarin']).length, 1);
  });

  test('a drug matched both specifically and by class shows once', () {
    expect(index.check(['clarithromycin', 'simvastatin']).length, 1);
  });

  test('checks every pair among several drugs, most severe first', () {
    final hits = index.check(['warfarin', 'paracetamol', 'rifampicin', 'nevirapine']);
    expect(hits.length, 3); // warfarin+paracetamol, warfarin+rifampicin, rifampicin+nevirapine
    expect(hits.first.interaction.severity, InteractionSeverity.contraindicated);
    expect(hits.last.interaction.severity, InteractionSeverity.minor);
  });

  test('no interaction returns an empty list; duplicates ignored', () {
    expect(index.check(['paracetamol', 'dolutegravir']), isEmpty);
    expect(index.check(['warfarin', 'warfarin']), isEmpty);
  });

  test('search finds brands and abbreviations; classes are not offered', () {
    expect(index.search('TLD').map((t) => t.key), containsAll(['dolutegravir', 'tenofovir']));
    expect(index.search('flagyl').single.key, 'metronidazole');
    expect(index.search('inducer'), isEmpty);
    expect(index.search('warf', exclude: {'warfarin'}), isEmpty);
  });

  test('survives saving to the phone and reading back', () {
    final copy = InteractionIndex.fromJson(index.toJson());
    expect(copy.terms.length, index.terms.length);
    expect(copy.check(['rifampicin', 'nevirapine']).single.interaction.severity,
        InteractionSeverity.contraindicated);
  });
}
