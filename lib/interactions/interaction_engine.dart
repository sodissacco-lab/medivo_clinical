/// The drug interaction checker (blueprint §15). Plain Dart, no Flutter,
/// so the matching rules can be unit-tested (test/interactions_test.dart).

/// A drug, or a class of drugs such as "NSAIDs".
class InteractionTerm {
  const InteractionTerm({
    required this.key,
    required this.name,
    required this.isClass,
    this.synonyms = const [],
    this.classes = const [],
  });

  final String key;
  final String name;
  final bool isClass;
  final List<String> synonyms;

  /// For drugs: the class keys the drug belongs to.
  final List<String> classes;

  factory InteractionTerm.fromMap(Map<String, dynamic> m) => InteractionTerm(
        key: m['key'] as String,
        name: m['name'] as String,
        isClass: m['kind'] == 'class',
        synonyms: ((m['synonyms'] as List?) ?? const []).map((e) => e.toString()).toList(),
        classes: ((m['classes'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'name': name,
        'kind': isClass ? 'class' : 'drug',
        'synonyms': synonyms,
        'classes': classes,
      };

  /// True if [query] matches the name, a synonym or a brand.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || synonyms.any((s) => s.toLowerCase().contains(q));
  }
}

enum InteractionSeverity { contraindicated, major, moderate, minor }

InteractionSeverity interactionSeverityFrom(String s) => switch (s) {
      'contraindicated' => InteractionSeverity.contraindicated,
      'major' => InteractionSeverity.major,
      'moderate' => InteractionSeverity.moderate,
      _ => InteractionSeverity.minor,
    };

const Map<InteractionSeverity, String> severityLabels = {
  InteractionSeverity.contraindicated: 'Do not combine',
  InteractionSeverity.major: 'Major interaction',
  InteractionSeverity.moderate: 'Moderate interaction',
  InteractionSeverity.minor: 'Minor interaction',
};

class DrugInteraction {
  const DrugInteraction({
    required this.id,
    required this.code,
    required this.termA,
    required this.termB,
    required this.severity,
    required this.summary,
    required this.status,
    this.mechanism,
    this.consequence,
    this.action,
    this.monitoring,
    this.verifiedAgainst,
    this.suggestedSources,
    this.publishedAt,
    this.approvedByName,
  });

  final String id;
  final String code;
  final String termA;
  final String termB;
  final InteractionSeverity severity;
  final String summary;
  final String status;
  final String? mechanism;
  final String? consequence;
  final String? action;
  final String? monitoring;
  final String? verifiedAgainst;
  final String? suggestedSources;
  final DateTime? publishedAt;
  final String? approvedByName;

  bool get isPublished => status == 'published';

  factory DrugInteraction.fromMap(Map<String, dynamic> m) => DrugInteraction(
        id: m['id'] as String,
        code: m['code'] as String,
        termA: m['term_a'] as String,
        termB: m['term_b'] as String,
        severity: interactionSeverityFrom(m['severity'] as String),
        summary: m['summary'] as String,
        status: m['status'] as String? ?? 'published',
        mechanism: m['mechanism'] as String?,
        consequence: m['consequence'] as String?,
        action: m['action'] as String?,
        monitoring: m['monitoring'] as String?,
        verifiedAgainst: m['verified_against'] as String?,
        suggestedSources: m['suggested_sources'] as String?,
        publishedAt: m['published_at'] == null ? null : DateTime.tryParse(m['published_at'] as String),
        approvedByName: m['approved_by_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'term_a': termA,
        'term_b': termB,
        'severity': severity.name,
        'summary': summary,
        'status': status,
        'mechanism': mechanism,
        'consequence': consequence,
        'action': action,
        'monitoring': monitoring,
        'verified_against': verifiedAgainst,
        'suggested_sources': suggestedSources,
        'published_at': publishedAt?.toIso8601String(),
        'approved_by_name': approvedByName,
      };
}

/// One interaction found between two of the chosen drugs.
class InteractionHit {
  const InteractionHit({required this.drugA, required this.drugB, required this.interaction});

  final InteractionTerm drugA;
  final InteractionTerm drugB;
  final DrugInteraction interaction;
}

class InteractionIndex {
  InteractionIndex({required List<InteractionTerm> terms, required this.interactions})
      : terms = {for (final t in terms) t.key: t};

  final Map<String, InteractionTerm> terms;
  final List<DrugInteraction> interactions;

  /// Drugs a person can pick (classes are matched automatically).
  List<InteractionTerm> get drugs =>
      terms.values.where((t) => !t.isClass).toList()..sort((a, b) => a.name.compareTo(b.name));

  List<InteractionTerm> search(String query, {Set<String> exclude = const {}}) =>
      drugs.where((d) => !exclude.contains(d.key) && d.matches(query)).toList();

  /// A drug's key plus the keys of every class it belongs to.
  Set<String> _expand(String key) => {key, ...?terms[key]?.classes};

  /// Every interaction between each pair of [drugKeys].
  ///
  /// When a pair matches both a drug-to-drug entry and a broader class
  /// entry, only the most specific entries are shown (e.g. rifampicin +
  /// nevirapine, not the general "enzyme inducers + nevirapine").
  /// Results are sorted from most to least severe.
  List<InteractionHit> check(List<String> drugKeys) {
    final keys = drugKeys.toSet().toList();
    final hits = <InteractionHit>[];
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        final a = keys[i];
        final b = keys[j];
        final termsA = _expand(a);
        final termsB = _expand(b);
        final matches = <(DrugInteraction, int)>[];
        for (final x in interactions) {
          final forward = termsA.contains(x.termA) && termsB.contains(x.termB);
          final reverse = termsA.contains(x.termB) && termsB.contains(x.termA);
          if (!forward && !reverse) continue;
          // Specificity: 1 point for each side named as the drug itself.
          final specific = (x.termA == a || x.termA == b ? 1 : 0) + (x.termB == a || x.termB == b ? 1 : 0);
          matches.add((x, specific));
        }
        if (matches.isEmpty) continue;
        final best = matches.map((m) => m.$2).reduce((p, q) => p > q ? p : q);
        final seen = <String>{};
        for (final (x, specific) in matches) {
          if (specific == best && seen.add(x.id)) {
            hits.add(InteractionHit(drugA: terms[a]!, drugB: terms[b]!, interaction: x));
          }
        }
      }
    }
    hits.sort((p, q) => p.interaction.severity.index.compareTo(q.interaction.severity.index));
    return hits;
  }

  Map<String, dynamic> toJson() => {
        'terms': [for (final t in terms.values) t.toMap()],
        'interactions': [for (final x in interactions) x.toMap()],
      };

  factory InteractionIndex.fromJson(Map<String, dynamic> json) => InteractionIndex(
        terms: [
          for (final t in (json['terms'] as List? ?? const []))
            InteractionTerm.fromMap(Map<String, dynamic>.from(t as Map)),
        ],
        interactions: [
          for (final x in (json['interactions'] as List? ?? const []))
            DrugInteraction.fromMap(Map<String, dynamic>.from(x as Map)),
        ],
      );
}
