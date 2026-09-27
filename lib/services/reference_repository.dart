import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/offline_service.dart';

/// A published topic in a reference list.
class TopicSummary {
  const TopicSummary({
    required this.code,
    required this.type,
    required this.title,
    required this.savedOffline,
    this.category,
    this.synonyms = const [],
    this.summary,
  });

  final String code;
  final String type;
  final String title;
  final String? category;
  final List<String> synonyms;
  final String? summary;
  final bool savedOffline;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        (category?.toLowerCase().contains(q) ?? false) ||
        synonyms.any((s) => s.toLowerCase().contains(q));
  }
}

/// Where a page's content came from.
enum TopicSource { device, online }

/// Reads PUBLISHED content only: from the offline library when the topic
/// is saved on the device, otherwise from Medivo cloud.
class ReferenceRepository {
  static const Duration _timeout = Duration(seconds: 12);

  /// Published topics of one type. Falls back to the device when offline.
  static Future<({List<TopicSummary> topics, bool fromDevice})> list(String type) async {
    final offline = OfflineService.instance;
    final local = offline.supported ? await offline.itemsOfType(type) : <OfflineItem>[];
    final savedCodes = {for (final item in local) item.code};

    try {
      final rows = await Supabase.instance.client
          .from('content_items')
          .select('code, type, title, category, synonyms, '
              'version:content_versions!content_items_current_version_fk(summary)')
          .eq('type', type)
          .not('current_version_id', 'is', null)
          .order('title')
          .timeout(_timeout);

      final topics = rows.map((row) {
        final version = row['version'] as Map<String, dynamic>?;
        return TopicSummary(
          code: row['code'] as String,
          type: row['type'] as String,
          title: row['title'] as String,
          category: row['category'] as String?,
          synonyms: ((row['synonyms'] as List?) ?? const []).map((s) => s.toString()).toList(),
          summary: version?['summary'] as String?,
          savedOffline: savedCodes.contains(row['code']),
        );
      }).toList();
      return (topics: topics, fromDevice: false);
    } catch (e) {
      debugPrint('Reference list online failed, using device: $e');
      final topics = local
          .map((item) => TopicSummary(
                code: item.code,
                type: item.type,
                title: item.title,
                category: item.category,
                synonyms: item.synonyms,
                summary: item.summary,
                savedOffline: true,
              ))
          .toList();
      return (topics: topics, fromDevice: true);
    }
  }

  /// One published topic: from the device if saved, otherwise online.
  /// Returns null when the topic is not available (for example offline
  /// and not downloaded).
  static Future<({OfflineItem? item, TopicSource source})> topic(String code) async {
    final offline = OfflineService.instance;
    if (offline.supported) {
      final saved = await offline.itemByCode(code);
      if (saved != null) return (item: saved, source: TopicSource.device);
    }

    final row = await Supabase.instance.client
        .from('content_items')
        .select('id, code, type, title, category, synonyms, is_essential, '
            'version:content_versions!content_items_current_version_fk('
            'id, version_label, title, summary, body_markdown, sources, metadata, '
            'author_name, approver_name, published_at, last_reviewed_at, next_review_at)')
        .eq('code', code)
        .not('current_version_id', 'is', null)
        .maybeSingle()
        .timeout(_timeout);

    final version = row?['version'] as Map<String, dynamic>?;
    if (row == null || version == null) return (item: null, source: TopicSource.online);

    DateTime? date(String key) {
      final value = version[key] as String?;
      return value == null ? null : DateTime.tryParse(value)?.toLocal();
    }

    return (
      item: OfflineItem(
        itemId: row['id'] as String,
        code: row['code'] as String,
        type: row['type'] as String,
        title: (version['title'] as String?) ?? row['title'] as String,
        category: row['category'] as String?,
        synonyms: ((row['synonyms'] as List?) ?? const []).map((s) => s.toString()).toList(),
        isEssential: row['is_essential'] == true,
        versionId: version['id'] as String,
        versionLabel: version['version_label'] as String?,
        summary: version['summary'] as String?,
        body: (version['body_markdown'] as String?) ?? '',
        sources: version['sources'] as String?,
        metadata: (version['metadata'] as Map<String, dynamic>?) ?? const {},
        authorName: version['author_name'] as String?,
        approverName: version['approver_name'] as String?,
        publishedAt: date('published_at'),
        lastReviewedAt: date('last_reviewed_at'),
        nextReviewAt: date('next_review_at'),
      ),
      source: TopicSource.online,
    );
  }
}
