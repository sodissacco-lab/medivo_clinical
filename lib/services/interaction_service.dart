import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interactions/interaction_engine.dart';
import '../offline/offline_service.dart';

/// A draft or reviewed interaction entry for the staff review screens.
class InteractionEvent {
  const InteractionEvent({required this.action, required this.at, this.toStatus, this.actorName, this.note});

  final String action;
  final DateTime at;
  final String? toStatus;
  final String? actorName;
  final String? note;
}

class InteractionService {
  static const Duration _timeout = Duration(seconds: 12);
  static SupabaseClient get _db => Supabase.instance.client;
  static String? _webCache;

  /// The checker's data. Published entries only, unless [includeDrafts]
  /// (content staff preview). Falls back to the copy saved on the phone.
  static Future<({InteractionIndex index, bool fromDevice})> load({bool includeDrafts = false}) async {
    try {
      final terms = await _db.from('interaction_terms').select('key, name, kind, synonyms, classes').timeout(_timeout);
      var query = _db.from('drug_interactions').select(interactionColumns);
      query = includeDrafts ? query.neq('status', 'retired') : query.eq('status', 'published');
      final rows = await query.timeout(_timeout);
      final json = {'terms': terms, 'interactions': rows};
      if (!includeDrafts) unawaited(_save(jsonEncode(json)));
      return (index: InteractionIndex.fromJson(json), fromDevice: false);
    } catch (e) {
      debugPrint('Interactions online failed, using device: $e');
      final saved = await _saved();
      if (saved == null) rethrow;
      return (
        index: InteractionIndex.fromJson(jsonDecode(saved) as Map<String, dynamic>),
        fromDevice: true,
      );
    }
  }

  static Future<void> _save(String json) async {
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) {
      await offline.saveInteractionIndexJson(json);
    } else {
      _webCache = json;
    }
  }

  static Future<String?> _saved() async {
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) return offline.interactionIndexJson();
    return _webCache;
  }

  // ---- Staff review (blueprint §30 applied to interactions) -------------

  static Future<List<DrugInteraction>> listByStatus(String status) async {
    final rows = await _db
        .from('drug_interactions')
        .select(interactionColumns)
        .eq('status', status)
        .order('code')
        .timeout(_timeout);
    return rows.map(DrugInteraction.fromMap).toList();
  }

  static Future<DrugInteraction> get(String id) async {
    final row = await _db.from('drug_interactions').select(interactionColumns).eq('id', id).single();
    return DrugInteraction.fromMap(row);
  }

  static Future<void> saveDraft(DrugInteraction x, Map<String, String?> fields) async {
    final rows = await _db.from('drug_interactions').update(fields).eq('id', x.id).select('id');
    if (rows.isEmpty) throw Exception('Only drafts can be edited.');
  }

  static Future<String> transition(String id, String action, {String? note, String? verifiedAgainst}) async {
    final result = await _db.rpc('interaction_transition', params: {
      'p_id': id,
      'p_action': action,
      'p_note': note,
      'p_verified_against': verifiedAgainst,
    });
    return result as String;
  }

  static Future<List<InteractionEvent>> history(String id) async {
    final rows = await _db
        .from('drug_interaction_reviews')
        .select('action, to_status, actor_name, note, created_at')
        .eq('interaction_id', id)
        .order('created_at', ascending: false);
    return rows
        .map((r) => InteractionEvent(
              action: r['action'] as String,
              toStatus: r['to_status'] as String?,
              actorName: r['actor_name'] as String?,
              note: r['note'] as String?,
              at: DateTime.parse(r['created_at'] as String).toLocal(),
            ))
        .toList();
  }
}
