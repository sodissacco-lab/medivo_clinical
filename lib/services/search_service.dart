import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../calculators/calculator_registry.dart';
import '../offline/offline_service.dart';
import 'calculator_catalog.dart';

/// One search result (blueprint §34).
class SearchResult {
  const SearchResult({
    required this.code,
    required this.type,
    required this.title,
    required this.score,
    required this.matched,
    required this.savedOffline,
    this.category,
    this.summary,
  });

  final String code;
  final String type;
  final String title;
  final String? category;
  final String? summary;
  final int score;

  /// Why it matched: title, search term, synonym, category or text.
  final String matched;
  final bool savedOffline;

  SearchResult copyWith({bool? savedOffline}) => SearchResult(
        code: code,
        type: type,
        title: title,
        category: category,
        summary: summary,
        score: score,
        matched: matched,
        savedOffline: savedOffline ?? this.savedOffline,
      );
}

class SearchOutcome {
  const SearchOutcome({required this.results, required this.fromDevice, this.expandedTo = const []});

  final List<SearchResult> results;

  /// True when there was no internet and only saved topics were searched.
  final bool fromDevice;

  /// What an abbreviation or lay term was understood as, e.g. HTN → hypertension.
  final List<String> expandedTo;
}

/// Universal search across all published content. Searches Medivo cloud,
/// and falls back to the offline library when there is no internet.
class SearchService {
  /// Lets the Home search box put the cursor straight into the Search tab.
  static final FocusNode focusNode = FocusNode();

  static final List<String> _memoryRecent = [];
  static const int _maxRecent = 10;

  static String normalise(String query) =>
      query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static Future<SearchOutcome> search(String query) async {
    final q = normalise(query);
    if (q.length < 2) return const SearchOutcome(results: [], fromDevice: false);

    final offline = OfflineService.instance;
    final synonyms = offline.supported ? await offline.synonyms() : const <String, List<String>>{};
    final expansions = (synonyms[q] ?? const <String>[]).map((e) => e.toLowerCase()).toList();
    final local = offline.supported ? await offline.allItems() : const <OfflineItem>[];
    final savedCodes = {for (final item in local) item.code};

    try {
      final rows = await Supabase.instance.client
          .rpc('search_content', params: {'p_query': q, 'p_limit': 80})
          .timeout(const Duration(seconds: 12));
      final results = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((row) => SearchResult(
                code: row['code'] as String,
                type: row['type'] as String,
                title: row['title'] as String,
                category: row['category'] as String?,
                summary: row['summary'] as String?,
                score: (row['score'] as num).toInt(),
                matched: row['matched'] as String,
                savedOffline: savedCodes.contains(row['code']),
              ))
          .toList();
      return SearchOutcome(
          results: _withCalculators(results, q, expansions), fromDevice: false, expandedTo: expansions);
    } catch (e) {
      debugPrint('Online search failed, searching the device: $e');
      final results = <SearchResult>[];
      for (final item in local) {
        final (score, matched) = _score(item, q, expansions);
        if (score > 0) {
          results.add(SearchResult(
            code: item.code,
            type: item.type,
            title: item.title,
            category: item.category,
            summary: item.summary,
            score: score,
            matched: matched,
            savedOffline: true,
          ));
        }
      }
      return SearchOutcome(
          results: _withCalculators(results, q, expansions), fromDevice: true, expandedTo: expansions);
    }
  }

  /// Calculators are built into the app, so they work without internet.
  /// Adds any the person can open that the results do not already hold
  /// (e.g. while offline, or unpublished ones in a staff preview).
  static List<SearchResult> _withCalculators(
      List<SearchResult> results, String q, List<String> expansions) {
    final catalog = CalculatorCatalog.instance;
    final merged = [
      for (final r in results) r.type == 'calculator' ? r.copyWith(savedOffline: true) : r,
    ];
    final have = {for (final r in merged) r.code};
    for (final calc in allCalculators) {
      if (have.contains(calc.code) || !catalog.canOpen(calc.code)) continue;
      final title = calc.title.toLowerCase();
      final synonyms = calc.synonyms;
      final int score;
      final String matched;
      if (title == q) {
        score = 100;
        matched = 'title';
      } else if (synonyms.contains(q)) {
        score = 90;
        matched = 'search term';
      } else if (title.startsWith(q)) {
        score = 80;
        matched = 'title';
      } else if (title.contains(q)) {
        score = 70;
        matched = 'title';
      } else if (synonyms.any((s) => s.contains(q))) {
        score = 60;
        matched = 'title';
      } else if (expansions.any((e) => title.contains(e) || synonyms.contains(e))) {
        score = 55;
        matched = 'synonym';
      } else {
        continue;
      }
      merged.add(SearchResult(
        code: calc.code,
        type: 'calculator',
        title: calc.title,
        category: calc.category,
        summary: calc.purpose,
        score: score,
        matched: matched,
        savedOffline: true,
      ));
    }
    merged.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.title.compareTo(b.title));
    return merged;
  }

  /// The same ranking as the server's search_content (blueprint §34).
  static (int, String) _score(OfflineItem item, String q, List<String> expansions) {
    final title = item.title.toLowerCase();
    final synonyms = item.synonyms.map((s) => s.toLowerCase()).toList();
    final category = (item.category ?? '').toLowerCase();
    final body = item.body.toLowerCase();
    final words = q.split(' ').where((w) => w.length >= 3).toList();
    bool inBody(String text) {
      final parts = text.split(' ').where((w) => w.length >= 3).toList();
      return parts.isNotEmpty && parts.every(body.contains);
    }

    if (title == q) return (100, 'title');
    if (synonyms.contains(q)) return (90, 'search term');
    if (expansions.contains(title)) return (85, 'synonym');
    if (title.startsWith(q)) return (80, 'title');
    if (title.contains(q)) return (70, 'title');
    if (synonyms.any((s) => s.contains(q))) return (60, 'title');
    if (expansions.any(title.startsWith)) return (58, 'synonym');
    if (expansions.any((e) => title.contains(e) || synonyms.contains(e))) return (55, 'synonym');
    if (category.contains(q)) return (30, 'category');
    if (words.isNotEmpty && inBody(q)) return (20, 'text');
    if (expansions.any(inBody)) return (15, 'text');
    return (0, '');
  }

  // ---- Recent searches and search history (blueprint §24, §32) ----------

  static Future<List<String>> recent() async {
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) return offline.recentSearches();
    return List.unmodifiable(_memoryRecent);
  }

  static Future<void> clearRecent() async {
    _memoryRecent.clear();
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) await offline.saveRecentSearches(const []);
  }

  /// Keeps the search in Recent searches and adds it to the anonymous
  /// top-searches statistics. Never interrupts the person if it fails.
  static Future<void> record(String query, int resultCount) async {
    final q = query.trim();
    if (q.length < 2) return;

    final current = [...await recent()];
    current.removeWhere((s) => s.toLowerCase() == q.toLowerCase());
    current.insert(0, q);
    final trimmed = current.take(_maxRecent).toList();
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) {
      await offline.saveRecentSearches(trimmed);
    } else {
      _memoryRecent
        ..clear()
        ..addAll(trimmed);
    }

    try {
      final client = Supabase.instance.client;
      await client.from('search_history').insert({
        'query': q.length > 100 ? q.substring(0, 100) : q,
        'result_count': resultCount,
        'user_id': client.auth.currentUser?.id,
      });
    } catch (e) {
      debugPrint('Search history not recorded: $e');
    }
  }
}