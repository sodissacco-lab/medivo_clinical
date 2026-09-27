import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../differentials/ddx_engine.dart';
import '../offline/offline_service.dart';

class DdxEvent {
  const DdxEvent({required this.action, required this.at, this.actorName, this.note});

  final String action;
  final DateTime at;
  final String? actorName;
  final String? note;
}

/// Loads the differential diagnosis knowledge base and supports staff review.
class DdxService {
  static const Duration _timeout = Duration(seconds: 12);
  static SupabaseClient get _db => Supabase.instance.client;
  static String? _webCache;

  static Future<({DdxIndex index, bool fromDevice})> load({bool includeDrafts = false}) async {
    try {
      final findings = await _db.from('ddx_findings').select('key, name, group_name, synonyms, sort_order').timeout(_timeout);
      var query = _db.from('ddx_conditions').select(ddxConditionColumns);
      query = includeDrafts ? query.neq('status', 'retired') : query.eq('status', 'published');
      final conditions = await query.timeout(_timeout);
      final links = await _db.from('ddx_condition_findings').select('condition_key, finding_key, weight').timeout(_timeout);
      final index = DdxIndex.fromRows(findings: findings, conditions: conditions, links: links);
      if (!includeDrafts) unawaited(_save(jsonEncode(index.toJson())));
      return (index: index, fromDevice: false);
    } catch (e) {
      debugPrint('Differentials online failed, using device: $e');
      final saved = await _saved();
      if (saved == null) rethrow;
      return (index: DdxIndex.fromJson(jsonDecode(saved) as Map<String, dynamic>), fromDevice: true);
    }
  }

  static Future<void> _save(String json) async {
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) {
      await offline.saveDdxIndexJson(json);
    } else {
      _webCache = json;
    }
  }

  static Future<String?> _saved() async {
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) return offline.ddxIndexJson();
    return _webCache;
  }

  // ---- Staff review --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> listByStatus(String status) async {
    final rows = await _db.from('ddx_conditions').select(ddxConditionColumns).eq('status', status).order('name');
    return rows;
  }

  static Future<Map<String, dynamic>> condition(String key) =>
      _db.from('ddx_conditions').select(ddxConditionColumns).eq('key', key).single();

  static Future<Map<String, int>> weights(String key) async {
    final rows = await _db.from('ddx_condition_findings').select('finding_key, weight').eq('condition_key', key);
    return {for (final r in rows) r['finding_key'] as String: (r['weight'] as num).toInt()};
  }

  static Future<List<DdxFinding>> allFindings() async {
    final rows = await _db.from('ddx_findings').select('key, name, group_name, synonyms, sort_order').order('sort_order');
    return rows.map(DdxFinding.fromMap).toList();
  }

  static Future<void> setWeight(String conditionKey, String findingKey, int? weight) async {
    final table = _db.from('ddx_condition_findings');
    if (weight == null) {
      await table.delete().eq('condition_key', conditionKey).eq('finding_key', findingKey);
    } else {
      await table.upsert({'condition_key': conditionKey, 'finding_key': findingKey, 'weight': weight});
    }
  }

  static Future<void> updateCondition(String key, Map<String, dynamic> fields) async {
    final rows = await _db.from('ddx_conditions').update(fields).eq('key', key).select('key');
    if (rows.isEmpty) throw Exception('Only drafts can be edited.');
  }

  static Future<String> transition(String key, String action, {String? note, String? verifiedAgainst}) async {
    final result = await _db.rpc('ddx_transition', params: {
      'p_key': key,
      'p_action': action,
      'p_note': note,
      'p_verified_against': verifiedAgainst,
    });
    return result as String;
  }

  static Future<List<DdxEvent>> history(String key) async {
    final rows = await _db
        .from('ddx_reviews')
        .select('action, actor_name, note, created_at')
        .eq('condition_key', key)
        .order('created_at', ascending: false);
    return rows
        .map((r) => DdxEvent(
              action: r['action'] as String,
              actorName: r['actor_name'] as String?,
              note: r['note'] as String?,
              at: DateTime.parse(r['created_at'] as String).toLocal(),
            ))
        .toList();
  }
}
