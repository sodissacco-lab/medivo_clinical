import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/offline_service.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.linkCode,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? linkCode;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        kind: m['kind'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        linkCode: m['link_code'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

const Map<String, String> notificationKindLabels = {
  'new_content': 'New clinical content',
  'content_update': 'Content updated',
  'guideline_update': 'Guideline updated',
  'drug_safety': 'Drug safety update',
  'cpd_event': 'CPD event',
  'announcement': 'Announcement',
};

/// In-app notifications (blueprint §27). Read state is kept on the phone.
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  List<AppNotification> items = const [];
  Set<String> _read = {};
  bool loaded = false;

  int get unread => items.where((n) => !_read.contains(n.id)).length;
  bool isRead(String id) => _read.contains(id);

  Future<void> refresh() async {
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready && _read.isEmpty) {
      _read = await offline.readNotificationIds();
    }
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id, kind, title, body, link_code, created_at')
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 12));
      items = rows.map(AppNotification.fromMap).toList();
    } catch (e) {
      debugPrint('Notifications not refreshed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    _read.addAll(items.map((n) => n.id));
    await _saveRead();
  }

  Future<void> markRead(String id) async {
    if (_read.add(id)) await _saveRead();
  }

  Future<void> _saveRead() async {
    // Keep only ids still shown, so the list does not grow for ever.
    _read = _read.intersection(items.map((n) => n.id).toSet());
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) await offline.saveReadNotificationIds(_read);
    notifyListeners();
  }

  /// Super administrators: post a notice (drug safety, CPD event, announcement).
  static Future<void> post({
    required String kind,
    required String title,
    String? body,
    String? linkCode,
    String audience = 'all',
    required String createdBy,
  }) async {
    await Supabase.instance.client.from('notifications').insert({
      'kind': kind,
      'title': title,
      'body': body,
      'link_code': linkCode,
      'audience': audience,
      'created_by': createdBy,
    });
  }

  static Future<void> delete(String id) async {
    await Supabase.instance.client.from('notifications').delete().eq('id', id);
  }
}
