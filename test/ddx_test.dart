// Tests for the differential diagnosis ranking (blueprint §11).
// Run with:  flutter test test/ddx_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medivo_clinical/differentials/ddx_engine.dart';

DdxFinding f(String key) => DdxFinding(key: key, name: key, group: 'General');

DdxCondition c(String key, Map<String, int> w,
        {bool mnm = false, String common = 'common', List<List<String>> required = const []}) =>
    DdxCondition(
      key: key,
      name: key,
      category: 'Test',
      commonness: common,
      mustNotMiss: mnm,
      weights: w,
      required: required,
    );

void main() {
  final index = DdxIndex(
    findings: [
      for (final k in ['fever', 'headache', 'neck_stiffness', 'vomiting', 'malaria_pos', 'hiv', 'confusion',
        'outbreak_contact', 'bleeding', 'rlq_pain', 'cough'])
        f(k),
    ],
    conditions: [
      c('bacterial_meningitis', {'fever': 3, 'neck_stiffness': 3, 'headache': 3, 'vomiting': 2, 'confusion': 2},
          mnm: true, common: 'uncommon', required: [['neck_stiffness', 'headache', 'confusion']]),
      c('malaria', {'fever': 3, 'malaria_pos': 3, 'headache': 2, 'vomiting': 1}, required: [['fever', 'malaria_pos']]),
      c('tension_headache', {'headache': 3, 'neck_stiffness': 1}, required: [['headache']]),
      c('crypto', {'hiv': 3, 'headache': 3, 'fever': 2, 'confusion': 2},
          mnm: true, common: 'uncommon', required: [['hiv'], ['headache', 'confusion']]),
      c('vhf', {'outbreak_contact': 3, 'fever': 3, 'bleeding': 3, 'vomiting': 2},
          mnm: true, common: 'rare', required: [['outbreak_contact', 'bleeding']]),
      c('appendicitis', {'rlq_pain': 3, 'fever': 2, 'vomiting': 2}, mnm: true, required: [['rlq_pain']]),
    ],
  );

  test('blueprint example: meningitis is must-not-miss, first', () {
    final r = index.rank(['fever', 'headache', 'neck_stiffness', 'vomiting']);
    expect(r.first.condition.key, 'bacterial_meningitis');
    expect(r.first.group, DdxGroup.mustNotMiss);
    expect(r.map((x) => x.condition.key), contains('malaria'));
  });

  test('required findings gate a condition', () {
    final keys = index.rank(['fever', 'vomiting']).map((x) => x.condition.key);
    expect(keys, isNot(contains('vhf'))); // needs contact or bleeding
    expect(keys, isNot(contains('crypto'))); // needs HIV
    expect(index.rank(['fever', 'vomiting', 'outbreak_contact']).map((x) => x.condition.key), contains('vhf'));
    expect(index.rank(['hiv', 'headache']).first.condition.key, 'crypto');
  });

  test('a single weak match is ignored when several findings are entered', () {
    final keys = index.rank(['cough', 'fever', 'rlq_pain']).map((x) => x.condition.key);
    expect(keys, contains('appendicitis'));
    expect(keys, isNot(contains('tension_headache')));
  });

  test('suggests what to check next, and lists matched findings first by weight', () {
    final r = index.rank(['fever', 'headache']).firstWhere((x) => x.condition.key == 'malaria');
    expect(r.lookFor, contains('malaria_pos'));
    expect(r.matched.first, 'fever');
  });

  test('empty input returns nothing; survives saving to the phone', () {
    expect(index.rank([]), isEmpty);
    final copy = DdxIndex.fromJson(index.toJson());
    expect(copy.rank(['hiv', 'headache']).first.condition.key, 'crypto');
  });
}
