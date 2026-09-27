/// Differential diagnosis engine (blueprint §11). Rule-based, no AI:
/// entered findings are matched against reviewed condition profiles.
/// "A clinical-support tool, not an autonomous diagnostic system."
/// Plain Dart so the ranking can be unit-tested (test/ddx_test.dart).

class DdxFinding {
  const DdxFinding({required this.key, required this.name, required this.group, this.synonyms = const [], this.sortOrder = 0});

  final String key;
  final String name;
  final String group;
  final List<String> synonyms;
  final int sortOrder;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || name.toLowerCase().contains(q) || synonyms.any((s) => s.toLowerCase().contains(q));
  }

  factory DdxFinding.fromMap(Map<String, dynamic> m) => DdxFinding(
        key: m['key'] as String,
        name: m['name'] as String,
        group: m['group_name'] as String,
        synonyms: ((m['synonyms'] as List?) ?? const []).map((e) => e.toString()).toList(),
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'key': key, 'name': name, 'group_name': group, 'synonyms': synonyms, 'sort_order': sortOrder};
}

class DdxCondition {
  const DdxCondition({
    required this.key,
    required this.name,
    required this.category,
    required this.commonness,
    required this.mustNotMiss,
    required this.weights,
    this.links = const [],
    this.required = const [],
    this.status = 'published',
    this.verifiedAgainst,
  });

  final String key;
  final String name;
  final String category;

  /// How often it is seen in Uganda: common, uncommon or rare.
  final String commonness;
  final bool mustNotMiss;

  /// Finding key → weight (3 characteristic, 2 common, 1 supportive).
  final Map<String, int> weights;

  /// Content codes to open, e.g. DIS-INF-008, EMR-004.
  final List<String> links;

  /// Each group needs at least one of its findings present.
  final List<List<String>> required;
  final String status;
  final String? verifiedAgainst;

  bool get isPublished => status == 'published';

  factory DdxCondition.fromMap(Map<String, dynamic> m, Map<String, int> weights) => DdxCondition(
        key: m['key'] as String,
        name: m['name'] as String,
        category: m['category'] as String,
        commonness: m['commonness'] as String? ?? 'common',
        mustNotMiss: m['must_not_miss'] == true,
        links: ((m['links'] as List?) ?? const []).map((e) => e.toString()).toList(),
        required: [
          for (final g in (m['required'] as List? ?? const [])) (g as List).map((e) => e.toString()).toList(),
        ],
        status: m['status'] as String? ?? 'published',
        verifiedAgainst: m['verified_against'] as String?,
        weights: weights,
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'name': name,
        'category': category,
        'commonness': commonness,
        'must_not_miss': mustNotMiss,
        'links': links,
        'required': required,
        'status': status,
        'verified_against': verifiedAgainst,
        'weights': weights,
      };
}

enum DdxGroup { mustNotMiss, mostConsistent, alsoConsider }

class DdxResult {
  const DdxResult({
    required this.condition,
    required this.score,
    required this.matched,
    required this.lookFor,
    required this.group,
  });

  final DdxCondition condition;
  final double score;

  /// Entered findings that fit this condition.
  final List<String> matched;

  /// Characteristic or common findings not yet entered: what to check next.
  final List<String> lookFor;
  final DdxGroup group;
}

class DdxIndex {
  DdxIndex({required List<DdxFinding> findings, required this.conditions})
      : findings = {for (final f in findings) f.key: f};

  final Map<String, DdxFinding> findings;
  final List<DdxCondition> conditions;

  static const _bonus = {'common': 1.0, 'uncommon': 0.5, 'rare': 0.0};

  List<DdxFinding> search(String query, {Set<String> exclude = const {}}) => findings.values
      .where((f) => !exclude.contains(f.key) && f.matches(query))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Ranks conditions for the entered findings and groups them by clinical
  /// relevance: dangerous conditions that fit are always shown first.
  List<DdxResult> rank(Iterable<String> entered) {
    final s = entered.toSet();
    if (s.isEmpty) return const [];
    final scored = <(DdxCondition, double, List<String>)>[];
    for (final c in conditions) {
      final matched = [for (final f in s) if (c.weights.containsKey(f)) f];
      if (matched.isEmpty) continue;
      if (!c.required.every((group) => group.any(s.contains))) continue;
      final hasKey = matched.any((f) => c.weights[f] == 3);
      if (s.length > 1 && matched.length < 2 && !hasKey) continue;
      final matchedWeight = matched.fold<int>(0, (sum, f) => sum + c.weights[f]!);
      final totalWeight = c.weights.values.fold<int>(0, (sum, w) => sum + w);
      final coverage = matchedWeight / totalWeight;
      final explained = matched.length / s.length;
      final score = matchedWeight + 3 * coverage + 3 * explained + (_bonus[c.commonness] ?? 0);
      scored.add((c, score, matched));
    }
    if (scored.isEmpty) return const [];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final top = scored.first.$2;

    final results = <DdxResult>[];
    var must = 0, likely = 0, also = 0;
    for (final (c, score, matched) in scored) {
      final relative = score / top;
      DdxGroup? group;
      if (c.mustNotMiss && relative >= 0.4 && must < 6) {
        group = DdxGroup.mustNotMiss;
        must++;
      } else if (!c.mustNotMiss && relative >= 0.6 && likely < 6) {
        group = DdxGroup.mostConsistent;
        likely++;
      } else if (relative >= 0.3 && also < 8) {
        group = DdxGroup.alsoConsider;
        also++;
      }
      if (group == null) continue;
      final lookFor = (c.weights.entries.where((e) => e.value >= 2 && !s.contains(e.key)).toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(4)
          .map((e) => e.key)
          .toList();
      matched.sort((a, b) => c.weights[b]!.compareTo(c.weights[a]!));
      results.add(DdxResult(condition: c, score: score, matched: matched, lookFor: lookFor, group: group));
    }
    return results;
  }

  Map<String, dynamic> toJson() => {
        'findings': [for (final f in findings.values) f.toMap()],
        'conditions': [for (final c in conditions) c.toMap()],
      };

  factory DdxIndex.fromJson(Map<String, dynamic> json) => DdxIndex(
        findings: [
          for (final f in (json['findings'] as List? ?? const [])) DdxFinding.fromMap(Map<String, dynamic>.from(f as Map)),
        ],
        conditions: [
          for (final c in (json['conditions'] as List? ?? const []))
            DdxCondition.fromMap(
              Map<String, dynamic>.from(c as Map),
              Map<String, dynamic>.from((c)['weights'] as Map).map((k, v) => MapEntry(k, (v as num).toInt())),
            ),
        ],
      );

  /// Builds the index from database rows (conditions, their finding links).
  factory DdxIndex.fromRows({
    required List<Map<String, dynamic>> findings,
    required List<Map<String, dynamic>> conditions,
    required List<Map<String, dynamic>> links,
  }) {
    final weights = <String, Map<String, int>>{};
    for (final l in links) {
      (weights[l['condition_key'] as String] ??= {})[l['finding_key'] as String] = (l['weight'] as num).toInt();
    }
    return DdxIndex(
      findings: findings.map(DdxFinding.fromMap).toList(),
      conditions: [
        for (final c in conditions) DdxCondition.fromMap(c, weights[c['key']] ?? const {}),
      ],
    );
  }
}
