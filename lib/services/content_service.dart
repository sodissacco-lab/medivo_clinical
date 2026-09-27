import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/content_options.dart';
import 'account_controller.dart';

/// One version of a clinical topic (blueprint §31).
class ContentVersion {
  const ContentVersion({
    required this.id,
    required this.itemId,
    required this.code,
    required this.type,
    required this.versionNumber,
    required this.status,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.category,
    this.synonyms = const [],
    this.isEssential = false,
    this.versionLabel,
    this.summary,
    this.sources,
    this.changeNote,
    this.metadata = const {},
    this.authorId,
    this.authorName,
    this.editorName,
    this.peerReviewerId,
    this.peerReviewerName,
    this.approverName,
    this.publisherName,
    this.submittedAt,
    this.approvedAt,
    this.publishedAt,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  final String id;
  final String itemId;
  final String code;
  final String type;
  final String? category;
  final List<String> synonyms;
  final bool isEssential;
  final int versionNumber;
  final String? versionLabel;
  final String status;
  final String title;
  final String? summary;
  final String body;
  final String? sources;
  final String? changeNote;
  final Map<String, dynamic> metadata;
  final String? authorId;
  final String? authorName;
  final String? editorName;
  final String? peerReviewerId;
  final String? peerReviewerName;
  final String? approverName;
  final String? publisherName;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? publishedAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final DateTime updatedAt;

  String get typeLabel => contentTypes[type] ?? type;
  String get statusLabel => statusLabels[status] ?? status;
  String get versionText =>
      versionLabel != null ? 'Version $versionLabel' : 'Working version $versionNumber';

  bool get hasOpenReviewerNotes => body.contains('## Reviewer notes');

  factory ContentVersion.fromMap(Map<String, dynamic> map) {
    final item = (map['item'] as Map<String, dynamic>?) ?? const {};
    DateTime? date(String key) {
      final value = map[key];
      return value == null ? null : DateTime.tryParse(value as String)?.toLocal();
    }

    return ContentVersion(
      id: map['id'] as String,
      itemId: map['item_id'] as String,
      code: (item['code'] as String?) ?? '',
      type: (item['type'] as String?) ?? '',
      category: item['category'] as String?,
      synonyms: ((item['synonyms'] as List?) ?? const []).map((s) => s.toString()).toList(),
      isEssential: item['is_essential'] == true,
      versionNumber: (map['version_number'] as num?)?.toInt() ?? 1,
      versionLabel: map['version_label'] as String?,
      status: map['status'] as String,
      title: (map['title'] as String?) ?? '',
      summary: map['summary'] as String?,
      body: (map['body_markdown'] as String?) ?? '',
      sources: map['sources'] as String?,
      changeNote: map['change_note'] as String?,
      metadata: (map['metadata'] as Map<String, dynamic>?) ?? const {},
      authorId: map['author_id'] as String?,
      authorName: map['author_name'] as String?,
      editorName: map['editor_name'] as String?,
      peerReviewerId: map['peer_reviewer_id'] as String?,
      peerReviewerName: map['peer_reviewer_name'] as String?,
      approverName: map['approver_name'] as String?,
      publisherName: map['publisher_name'] as String?,
      submittedAt: date('submitted_at'),
      approvedAt: date('approved_at'),
      publishedAt: date('published_at'),
      lastReviewedAt: date('last_reviewed_at'),
      nextReviewAt: date('next_review_at'),
      updatedAt: date('updated_at') ?? DateTime.now(),
    );
  }
}

/// One step in a topic's review history.
class ReviewEvent {
  const ReviewEvent({
    required this.action,
    required this.createdAt,
    this.actorName,
    this.note,
    this.toStatus,
  });

  final String action;
  final String? actorName;
  final String? note;
  final String? toStatus;
  final DateTime createdAt;

  String get label => actionHistoryLabels[action] ?? action;

  factory ReviewEvent.fromMap(Map<String, dynamic> map) {
    return ReviewEvent(
      action: map['action'] as String,
      actorName: map['actor_name'] as String?,
      note: map['note'] as String?,
      toStatus: map['to_status'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String)?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Talks to the content engine in Supabase. The database enforces every
/// rule; this class only asks.
class ContentService {
  static SupabaseClient get _db => Supabase.instance.client;

  static const String _select =
      '*, item:content_items!content_versions_item_id_fkey(code, type, category, synonyms, is_essential)';

  static Future<List<ContentVersion>> list(List<String> statuses) async {
    final rows = await _db
        .from('content_versions')
        .select(_select)
        .inFilter('status', statuses)
        .order('updated_at', ascending: false);
    return rows.map(ContentVersion.fromMap).toList();
  }

  /// Published topics whose periodic review is due within 30 days.
  static Future<List<ContentVersion>> dueForReview() async {
    final limit = DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String();
    final rows = await _db
        .from('content_versions')
        .select(_select)
        .eq('status', 'published')
        .lte('next_review_at', limit)
        .order('next_review_at');
    return rows.map(ContentVersion.fromMap).toList();
  }

  static Future<ContentVersion> get(String versionId) async {
    final row = await _db.from('content_versions').select(_select).eq('id', versionId).single();
    return ContentVersion.fromMap(row);
  }

  static Future<List<ContentVersion>> versionsOf(String itemId) async {
    final rows = await _db
        .from('content_versions')
        .select(_select)
        .eq('item_id', itemId)
        .order('version_number', ascending: false);
    return rows.map(ContentVersion.fromMap).toList();
  }

  static Future<List<ReviewEvent>> history(String itemId) async {
    final rows = await _db
        .from('content_reviews')
        .select()
        .eq('item_id', itemId)
        .order('created_at', ascending: false);
    return rows.map(ReviewEvent.fromMap).toList();
  }

  /// Returns the id of the new topic's first draft.
  static Future<String> create({
    required String type,
    required String code,
    required String title,
    String? category,
    List<String> synonyms = const [],
  }) async {
    final result = await _db.rpc('create_content_item', params: {
      'p_code': code,
      'p_type': type,
      'p_title': title,
      'p_category': category,
      'p_synonyms': synonyms,
    });
    return result as String;
  }

  static Future<void> saveDraft({
    required String versionId,
    required String title,
    required String summary,
    required String body,
    required String sources,
    required String changeNote,
  }) async {
    final rows = await _db
        .from('content_versions')
        .update({
          'title': title.trim(),
          'summary': _blankToNull(summary),
          'body_markdown': body,
          'sources': _blankToNull(sources),
          'change_note': _blankToNull(changeNote),
        })
        .eq('id', versionId)
        .select('id');
    if (rows.isEmpty) {
      throw Exception('You cannot edit this draft.');
    }
  }

  /// Replaces a draft's structured details (e.g. a guideline's official
  /// link and licence status). Only drafts can be changed.
  static Future<void> saveMetadata(String versionId, Map<String, dynamic> metadata) async {
    final rows = await _db
        .from('content_versions')
        .update({'metadata': metadata})
        .eq('id', versionId)
        .select('id');
    if (rows.isEmpty) {
      throw Exception('You cannot edit this draft.');
    }
  }

  /// Returns the new status.
  static Future<String> transition(String versionId, String action, {String? note}) async {
    final result = await _db.rpc('content_transition', params: {
      'p_version_id': versionId,
      'p_action': action,
      'p_note': note,
    });
    return result as String;
  }

  /// Medical reviewers and super admins choose what goes in the Essential Pack.
  static Future<void> setEssential(String itemId, bool essential) async {
    await _db.rpc('set_content_essential', params: {
      'p_item_id': itemId,
      'p_essential': essential,
    });
  }

  /// Returns the id of the new (or already open) draft.
  static Future<String> startRevision(String itemId) async {
    final result = await _db.rpc('start_revision', params: {'p_item_id': itemId});
    return result as String;
  }

  static String? _blankToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

/// What the signed-in person may do with this version right now.
/// The database checks the same rules again; this only decides which
/// buttons to show.
List<String> availableActions(ContentVersion v) {
  final account = AccountController.instance;
  final role = account.profile?.role ?? '';
  final me = account.user?.id;
  final isAuthor = v.authorId != null && v.authorId == me;
  final isStaff = contentStaffRoles.contains(role);
  final isReviewer = role == 'medical_reviewer';
  final isEditor = role == 'content_editor';

  switch (v.status) {
    case 'draft':
      return isStaff ? ['submit'] : [];
    case 'editor_review':
      return [
        if ((isEditor || isReviewer) && !isAuthor) ...['editor_pass', 'request_changes'],
        if (isAuthor) 'withdraw',
      ];
    case 'peer_review':
      return [
        if (isReviewer && !isAuthor) ...['peer_pass', 'request_changes'],
        if (isAuthor) 'withdraw',
      ];
    case 'clinical_approval':
      return [
        if (isReviewer && !isAuthor && v.peerReviewerId != me) 'approve',
        if ((isEditor || isReviewer) && !isAuthor) 'request_changes',
        if (isAuthor) 'withdraw',
      ];
    case 'approved':
      return [
        if (isReviewer || role == 'super_admin') 'publish',
        if (isEditor || isReviewer) 'request_changes',
      ];
    case 'published':
      return [
        if (isReviewer) 'confirm_review',
        if (isReviewer || role == 'super_admin') 'archive',
      ];
    default:
      return [];
  }
}

bool canEditDraft(ContentVersion v) {
  final account = AccountController.instance;
  final role = account.profile?.role ?? '';
  return v.status == 'draft' &&
      contentStaffRoles.contains(role) &&
      (v.authorId == null || v.authorId == account.user?.id || role == 'content_editor');
}

/// Plain-language message for a content engine error. The database's own
/// workflow messages are already written for people, so they are shown as-is.
String contentError(Object error) {
  if (error is PostgrestException) {
    final message = error.message;
    debugPrint('Content error ${error.code}: $message');
    if (error.code == '23505') {
      return 'This topic already has a version in progress.';
    }
    if (error.code == 'P0001') {
      return message; // raised by our workflow rules
    }
    if (message.toLowerCase().contains('permission denied')) {
      return 'You are not permitted to do that.';
    }
    return 'Something went wrong. Please try again.';
  }
  if (error.toString().contains('cannot edit this draft')) {
    return 'You cannot edit this draft.';
  }
  return friendlyError(error);
}