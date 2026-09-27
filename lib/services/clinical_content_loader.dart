import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/offline_service.dart';
import 'published_index.dart';
import 'reference_repository.dart';

/// Content ready to show, and whether it is a staff preview of a version
/// that has not been published.
class LoadedContent {
  const LoadedContent({required this.item, required this.source, this.previewStatus});

  final OfflineItem item;
  final TopicSource source;

  /// Set only for a staff preview, e.g. 'draft' or 'peer_review'.
  final String? previewStatus;

  bool get isPreview => previewStatus != null;
}

class ClinicalContentLoader {
  static const Duration _timeout = Duration(seconds: 12);

  /// The published version (from the device first, so it is instant and
  /// works without internet). Content staff get the latest unpublished
  /// version as a preview when nothing is published yet.
  /// Returns null when the item is not available to this person.
  static Future<LoadedContent?> load(String code) async {
    Object? onlineError;
    try {
      final published = await ReferenceRepository.topic(code);
      if (published.item != null) {
        return LoadedContent(item: published.item!, source: published.source);
      }
    } catch (e) {
      onlineError = e;
    }

    if (!PublishedIndex.isStaff) {
      if (onlineError != null) throw onlineError;
      return null;
    }

    final client = Supabase.instance.client;
    final row = await client
        .from('content_items')
        .select('id, code, type, title, category, synonyms, is_essential')
        .eq('code', code)
        .maybeSingle()
        .timeout(_timeout);
    if (row == null) return null;
    final version = await client
        .from('content_versions')
        .select('id, version_label, status, title, summary, body_markdown, sources, metadata, author_name')
        .eq('item_id', row['id'] as String)
        .order('version_number', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(_timeout);
    if (version == null) return null;

    return LoadedContent(
      source: TopicSource.online,
      previewStatus: version['status'] as String? ?? 'draft',
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
      ),
    );
  }
}
