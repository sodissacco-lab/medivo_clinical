import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/account_controller.dart';
import 'offline_database.dart';

/// A download pack (blueprint §22), e.g. Essential Pack or Drugs.
class OfflinePack {
  const OfflinePack({
    required this.code,
    required this.name,
    required this.description,
    required this.types,
    required this.essentialOnly,
    required this.sortOrder,
    required this.selected,
  });

  final String code;
  final String name;
  final String description;
  final List<String> types;
  final bool essentialOnly;
  final int sortOrder;
  final bool selected;

  bool includes(String type, bool isEssential) =>
      types.contains(type) && (!essentialOnly || isEssential);

  factory OfflinePack.fromRow(Map<String, Object?> row) {
    return OfflinePack(
      code: row['code'] as String,
      name: row['name'] as String,
      description: row['description'] as String,
      types: (jsonDecode(row['content_types'] as String) as List).cast<String>(),
      essentialOnly: row['essential_only'] == 1,
      sortOrder: row['sort_order'] as int,
      selected: row['selected'] == 1,
    );
  }
}

/// One downloaded, published topic.
class OfflineItem {
  const OfflineItem({
    required this.itemId,
    required this.code,
    required this.type,
    required this.title,
    required this.body,
    required this.versionId,
    this.category,
    this.synonyms = const [],
    this.isEssential = false,
    this.versionLabel,
    this.summary,
    this.sources,
    this.metadata = const {},
    this.authorName,
    this.approverName,
    this.publishedAt,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  final String itemId;
  final String code;
  final String type;
  final String title;
  final String? category;
  final List<String> synonyms;
  final bool isEssential;
  final String versionId;
  final String? versionLabel;
  final String? summary;
  final String body;
  final String? sources;
  final Map<String, dynamic> metadata;
  final String? authorName;
  final String? approverName;
  final DateTime? publishedAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  factory OfflineItem.fromRow(Map<String, Object?> row) {
    DateTime? date(String key) {
      final value = row[key] as String?;
      return value == null ? null : DateTime.tryParse(value)?.toLocal();
    }

    return OfflineItem(
      itemId: row['item_id'] as String,
      code: row['code'] as String,
      type: row['type'] as String,
      title: row['title'] as String,
      category: row['category'] as String?,
      synonyms: (jsonDecode(row['synonyms'] as String) as List).cast<String>(),
      isEssential: row['is_essential'] == 1,
      versionId: row['version_id'] as String,
      versionLabel: row['version_label'] as String?,
      summary: row['summary'] as String?,
      body: row['body'] as String,
      sources: row['sources'] as String?,
      metadata: (jsonDecode(row['metadata'] as String) as Map).cast<String, dynamic>(),
      authorName: row['author_name'] as String?,
      approverName: row['approver_name'] as String?,
      publishedAt: date('published_at'),
      lastReviewedAt: date('last_reviewed_at'),
      nextReviewAt: date('next_review_at'),
    );
  }
}

/// Keeps published content on the phone and in step with Medivo cloud.
/// Only content that has passed clinical review and been published is
/// ever downloaded.
class OfflineService extends ChangeNotifier {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  /// The offline library is part of the mobile app. The web version reads online.
  bool get supported => !kIsWeb;

  Database? _db;
  bool ready = false;
  List<OfflinePack> packs = const [];
  DateTime? lastUpdated;
  int itemCount = 0;
  Map<String, int> _counts = const {}; // "type|essential" → count
  bool syncing = false;
  int done = 0;
  int total = 0;
  String? error;

  static const Duration _syncEvery = Duration(hours: 12);

  Future<void> init() async {
    if (!supported) return;
    try {
      _db = await OfflineDatabase.open();
      await _loadLocal();
      ready = true;
    } catch (e) {
      debugPrint('Offline library could not open: $e');
      error = 'The offline library could not be opened on this device.';
    }
    notifyListeners();
  }

  /// Called at start-up: updates in the background when it is time to.
  Future<void> syncIfDue() async {
    if (!ready || syncing) return;
    final last = lastUpdated;
    if (packs.isEmpty || last == null || DateTime.now().difference(last) > _syncEvery) {
      await sync();
    }
  }

  Future<void> setPackSelected(String code, bool selected) async {
    final db = _db;
    if (db == null) return;
    await db.update('packs', {'selected': selected ? 1 : 0},
        where: 'code = ?', whereArgs: [code]);
    await _loadLocal();
    notifyListeners();
    await sync();
  }

  int itemsInPack(OfflinePack pack) {
    var count = 0;
    _counts.forEach((key, value) {
      final parts = key.split('|');
      if (pack.includes(parts[0], parts[1] == '1')) count += value;
    });
    return count;
  }

  Future<void> sync() async {
    final db = _db;
    if (db == null || syncing) return;
    syncing = true;
    error = null;
    done = 0;
    total = 0;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      await _refreshPacks(db, client);
      await _refreshSynonyms(db, client);
      final chosen = packs.where((p) => p.selected).toList();

      // 1. What is published now, and which of it the chosen packs cover.
      final List<Map<String, dynamic>> published = chosen.isEmpty
          ? const []
          : await client
              .from('content_items')
              .select('id, code, type, title, category, synonyms, is_essential, current_version_id')
              .not('current_version_id', 'is', null);
      final wanted = <String, Map<String, dynamic>>{
        for (final row in published)
          if (chosen.any((p) => p.includes(row['type'] as String, row['is_essential'] == true)))
            row['id'] as String: row,
      };

      // 2. Compare with what is on the phone.
      final local = await db.query('items', columns: ['item_id', 'version_id']);
      final localVersion = {
        for (final row in local) row['item_id'] as String: row['version_id'] as String,
      };
      final toDownload = wanted.values
          .where((row) => localVersion[row['id']] != row['current_version_id'])
          .toList();
      final toRemove = localVersion.keys.where((id) => !wanted.containsKey(id)).toList();

      total = toDownload.length;
      notifyListeners();

      // 3. Download new and updated topics, 25 at a time.
      for (var start = 0; start < toDownload.length; start += 25) {
        final chunk = toDownload.sublist(start, math.min(start + 25, toDownload.length));
        final versions = await client
            .from('content_versions')
            .select('id, version_label, title, summary, body_markdown, sources, metadata, '
                'author_name, approver_name, published_at, last_reviewed_at, next_review_at')
            .inFilter('id', chunk.map((row) => row['current_version_id'] as String).toList());
        final byId = {for (final v in versions) v['id'] as String: v};

        final batch = db.batch();
        final savedAt = DateTime.now().toUtc().toIso8601String();
        for (final item in chunk) {
          final v = byId[item['current_version_id']];
          if (v == null) continue;
          batch.insert(
            'items',
            {
              'item_id': item['id'],
              'code': item['code'],
              'type': item['type'],
              'title': v['title'] ?? item['title'],
              'category': item['category'],
              'synonyms': jsonEncode(item['synonyms'] ?? const []),
              'is_essential': item['is_essential'] == true ? 1 : 0,
              'version_id': v['id'],
              'version_label': v['version_label'],
              'summary': v['summary'],
              'body': v['body_markdown'] ?? '',
              'sources': v['sources'],
              'metadata': jsonEncode(v['metadata'] ?? const {}),
              'author_name': v['author_name'],
              'approver_name': v['approver_name'],
              'published_at': v['published_at'],
              'last_reviewed_at': v['last_reviewed_at'],
              'next_review_at': v['next_review_at'],
              'saved_at': savedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        done += chunk.length;
        notifyListeners();
      }

      // 4. Remove topics that were archived, replaced or are no longer in a chosen pack.
      for (var start = 0; start < toRemove.length; start += 500) {
        final chunk = toRemove.sublist(start, math.min(start + 500, toRemove.length));
        await db.delete('items',
            where: 'item_id IN (${List.filled(chunk.length, '?').join(', ')})',
            whereArgs: chunk);
      }

      await _setMeta(db, 'last_sync', DateTime.now().toUtc().toIso8601String());
      await _loadLocal();
    } catch (e) {
      error = friendlyError(e);
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Deletes everything downloaded and unticks every pack.
  Future<void> removeAll() async {
    final db = _db;
    if (db == null || syncing) return;
    await db.delete('items');
    await db.update('packs', {'selected': 0});
    await db.delete('meta', where: 'key = ?', whereArgs: ['last_sync']);
    await _loadLocal();
    notifyListeners();
  }

  // ---- Reading downloaded content (used by the reference modules) ------

  Future<List<OfflineItem>> itemsOfType(String type) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('items', where: 'type = ?', whereArgs: [type], orderBy: 'title');
    return rows.map(OfflineItem.fromRow).toList();
  }

  Future<OfflineItem?> itemByCode(String code) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('items', where: 'code = ?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : OfflineItem.fromRow(rows.first);
  }

  /// Every saved topic, for searching without internet.
  Future<List<OfflineItem>> allItems() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('items');
    return rows.map(OfflineItem.fromRow).toList();
  }

  /// Clinical synonyms and abbreviations saved at the last update
  /// (e.g. htn → hypertension), for searching without internet.
  Future<Map<String, List<String>>> synonyms() async {
    final db = _db;
    if (db == null) return const {};
    final raw = await _getMeta(db, 'synonyms');
    if (raw == null) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as List).cast<String>()));
  }

  Future<List<String>> recentSearches() async {
    final db = _db;
    if (db == null) return const [];
    final raw = await _getMeta(db, 'recent_searches');
    return raw == null ? const [] : (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    final db = _db;
    if (db == null) return;
    await _setMeta(db, 'recent_searches', jsonEncode(searches));
  }

  // ---- Internals ---------------------------------------------------------

  Future<void> _refreshSynonyms(Database db, SupabaseClient client) async {
    try {
      final rows = await client.from('search_synonyms').select('term, expands_to');
      final map = {
        for (final row in rows)
          row['term'] as String: ((row['expands_to'] as List?) ?? const []).cast<String>(),
      };
      await _setMeta(db, 'synonyms', jsonEncode(map));
    } catch (e) {
      // Never let the synonym list stop the rest of the update.
      debugPrint('Search synonyms not updated: $e');
    }
  }

  Future<void> _refreshPacks(Database db, SupabaseClient client) async {
    final rows = await client.from('offline_packs').select().order('sort_order');
    final firstTime = await _getMeta(db, 'packs_initialised') == null;
    final previous = {for (final p in packs) p.code: p.selected};

    final batch = db.batch();
    batch.delete('packs');
    for (final row in rows) {
      final code = row['code'] as String;
      final selected = firstTime ? code == 'essential' : (previous[code] ?? false);
      batch.insert('packs', {
        'code': code,
        'name': row['name'],
        'description': row['description'] ?? '',
        'content_types': jsonEncode(row['content_types'] ?? const []),
        'essential_only': row['essential_only'] == true ? 1 : 0,
        'sort_order': row['sort_order'] ?? 100,
        'selected': selected ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
    if (firstTime) await _setMeta(db, 'packs_initialised', 'yes');
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    final db = _db;
    if (db == null) return;
    final packRows = await db.query('packs', orderBy: 'sort_order');
    packs = packRows.map(OfflinePack.fromRow).toList();

    final countRows = await db.rawQuery(
        'SELECT type, is_essential, COUNT(*) AS n FROM items GROUP BY type, is_essential');
    _counts = {
      for (final row in countRows) '${row['type']}|${row['is_essential']}': row['n'] as int,
    };
    itemCount = _counts.values.fold(0, (sum, n) => sum + n);

    final last = await _getMeta(db, 'last_sync');
    lastUpdated = last == null ? null : DateTime.tryParse(last)?.toLocal();
  }

  Future<String?> _getMeta(Database db, String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setMeta(Database db, String key, String value) async {
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// "26 September 2026", as in blueprint §22.
String formatLongDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}