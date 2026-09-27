import 'package:flutter/foundation.dart';

import '../data/content_options.dart';
import 'account_controller.dart';
import 'reference_repository.dart';

/// Which items of one content type are PUBLISHED (and so visible to users),
/// with their list details. Used by the Emergency and Algorithms hubs.
class PublishedIndex extends ChangeNotifier {
  PublishedIndex._(this.type);

  static final Map<String, PublishedIndex> _byType = {};

  /// One shared index per content type, e.g. 'emergency'.
  static PublishedIndex of(String type) => _byType.putIfAbsent(type, () => PublishedIndex._(type));

  final String type;
  Map<String, TopicSummary> _topics = {};
  bool loaded = false;
  bool fromDevice = false;

  Future<void> refresh() async {
    try {
      final result = await ReferenceRepository.list(type);
      _topics = {for (final t in result.topics) t.code: t};
      fromDevice = result.fromDevice;
    } catch (e) {
      debugPrint('Published $type list not refreshed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  Iterable<TopicSummary> get topics => _topics.values;
  bool isPublished(String code) => _topics.containsKey(code);
  TopicSummary? topic(String code) => _topics[code];

  static bool get isStaff => contentStaffRoles.contains(AccountController.instance.profile?.role);

  /// Users open published items; content staff may also preview drafts.
  bool canOpen(String code) => isPublished(code) || isStaff;
}
