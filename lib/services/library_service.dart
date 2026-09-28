import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/offline_service.dart';
import 'account_controller.dart';

/// A saved topic, calculator, protocol, algorithm or guideline (§25).
class Bookmark {
  const Bookmark({
    required this.code,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.type,
    this.folderId,
    this.deleted = false,
  });

  final String code;
  final String title;
  final String? type;
  final String? folderId;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bookmark copyWith({String? title, String? folderId, bool clearFolder = false, bool? deleted}) => Bookmark(
        code: code,
        title: title ?? this.title,
        type: type,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, Object?> toRow() => {
        'code': code,
        'title': title,
        'type': type,
        'folder_id': folderId,
        'deleted': deleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Bookmark.fromRow(Map<String, Object?> r) => Bookmark(
        code: r['code'] as String,
        title: r['title'] as String,
        type: r['type'] as String?,
        folderId: r['folder_id'] as String?,
        deleted: r['deleted'] == 1 || r['deleted'] == true,
        createdAt: DateTime.parse(r['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(r['updated_at'] as String).toUtc(),
      );
}

class BookmarkFolder {
  const BookmarkFolder({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool deleted;
  final DateTime updatedAt;

  BookmarkFolder copyWith({String? name, bool? deleted}) => BookmarkFolder(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder,
        deleted: deleted ?? this.deleted,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'sort_order': sortOrder,
        'deleted': deleted ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BookmarkFolder.fromRow(Map<String, Object?> r) => BookmarkFolder(
        id: r['id'] as String,
        name: r['name'] as String,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
        deleted: r['deleted'] == 1 || r['deleted'] == true,
        updatedAt: DateTime.parse(r['updated_at'] as String).toUtc(),
      );
}

class RecentView {
  const RecentView({required this.code, required this.title, required this.viewedAt, this.type});

  final String code;
  final String title;
  final String? type;
  final DateTime viewedAt;
}

/// Saved content, folders and recently viewed (blueprint §25, §26).
/// Kept on the phone so it works offline; bookmarks and folders are also
/// copied to the signed-in account.
class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  static const int _maxRecent = 100;

  /// Starter folders from blueprint §25.
  static const _defaultFolders = [
    ('emergency', 'My Emergency'),
    ('paediatrics', 'My Paediatrics'),
    ('drugs', 'My Drugs'),
    ('exams', 'My Exams'),
    ('practice', 'My Practice'),
  ];

  final Map<String, Bookmark> _bookmarks = {};
  final Map<String, BookmarkFolder> _folders = {};
  final List<RecentView> _recent = [];
  bool _started = false;
  String? _syncedUser;
  Timer? _syncTimer;

  Database? get _db {
    final offline = OfflineService.instance;
    return offline.supported && offline.ready ? offline.database : null;
  }

  List<Bookmark> get bookmarks =>
      _bookmarks.values.where((b) => !b.deleted).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<BookmarkFolder> get folders =>
      _folders.values.where((f) => !f.deleted).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<RecentView> get recent => List.unmodifiable(_recent);

  bool isSaved(String code) => _bookmarks[code]?.deleted == false;
  Bookmark? bookmark(String code) => isSaved(code) ? _bookmarks[code] : null;
  BookmarkFolder? folder(String? id) => id == null ? null : _folders[id];

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final db = _db;
    if (db != null) {
      for (final r in await db.query('bookmark_folders')) {
        final f = BookmarkFolder.fromRow(r);
        _folders[f.id] = f;
      }
      for (final r in await db.query('bookmarks')) {
        final b = Bookmark.fromRow(r);
        _bookmarks[b.code] = b;
      }
      for (final r in await db.query('recent_views', orderBy: 'viewed_at DESC', limit: _maxRecent)) {
        _recent.add(RecentView(
          code: r['code'] as String,
          title: r['title'] as String,
          type: r['type'] as String?,
          viewedAt: DateTime.parse(r['viewed_at'] as String).toLocal(),
        ));
      }
    }
    if (_folders.isEmpty) {
      var order = 0;
      for (final (id, name) in _defaultFolders) {
        await _putFolder(BookmarkFolder(id: id, name: name, sortOrder: order++, updatedAt: DateTime.utc(2026)));
      }
    }
    notifyListeners();
    AccountController.instance.addListener(_onAccountChange);
    _onAccountChange();
  }

  void _onAccountChange() {
    final id = AccountController.instance.profile?.id;
    if (id != null && id != _syncedUser) {
      _syncedUser = id;
      unawaited(sync());
    }
    if (id == null) _syncedUser = null;
  }

  // ---- Bookmarks -------------------------------------------------------------

  Future<void> save(String code, String title, String? type, {String? folderId}) async {
    final existing = _bookmarks[code];
    final now = DateTime.now().toUtc();
    final b = existing == null
        ? Bookmark(code: code, title: title, type: type, folderId: folderId, createdAt: now, updatedAt: now)
        : existing.copyWith(title: title, folderId: folderId, clearFolder: folderId == null, deleted: false);
    await _putBookmark(b);
  }

  Future<void> remove(String code) async {
    final b = _bookmarks[code];
    if (b == null) return;
    await _putBookmark(b.copyWith(deleted: true));
  }

  Future<void> moveTo(String code, String? folderId) async {
    final b = _bookmarks[code];
    if (b == null) return;
    await _putBookmark(b.copyWith(folderId: folderId, clearFolder: folderId == null));
  }

  Future<void> _putBookmark(Bookmark b) async {
    _bookmarks[b.code] = b;
    await _db?.insert('bookmarks', b.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
    _scheduleSync();
  }

  // ---- Folders ---------------------------------------------------------------

  Future<String> addFolder(String name) async {
    final id = 'f${DateTime.now().microsecondsSinceEpoch}';
    final order = _folders.values.fold<int>(0, (m, f) => f.sortOrder >= m ? f.sortOrder + 1 : m);
    await _putFolder(BookmarkFolder(id: id, name: name.trim(), sortOrder: order, updatedAt: DateTime.now().toUtc()));
    return id;
  }

  Future<void> renameFolder(String id, String name) async {
    final f = _folders[id];
    if (f != null) await _putFolder(f.copyWith(name: name.trim()));
  }

  /// Deletes the folder; its bookmarks stay saved, outside any folder.
  Future<void> deleteFolder(String id) async {
    final f = _folders[id];
    if (f == null) return;
    for (final b in _bookmarks.values.where((b) => b.folderId == id && !b.deleted).toList()) {
      await _putBookmark(b.copyWith(clearFolder: true));
    }
    await _putFolder(f.copyWith(deleted: true));
  }

  Future<void> _putFolder(BookmarkFolder f) async {
    _folders[f.id] = f;
    await _db?.insert('bookmark_folders', f.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
    _scheduleSync();
  }

  // ---- Recently viewed (§26), on this phone only ---------------------------

  Future<void> recordView(String code, String title, String? type) async {
    _recent.removeWhere((r) => r.code == code);
    final now = DateTime.now();
    _recent.insert(0, RecentView(code: code, title: title, type: type, viewedAt: now));
    if (_recent.length > _maxRecent) _recent.removeRange(_maxRecent, _recent.length);
    final db = _db;
    if (db != null) {
      await db.insert(
        'recent_views',
        {'code': code, 'title': title, 'type': type, 'viewed_at': now.toUtc().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.rawDelete(
          'DELETE FROM recent_views WHERE code NOT IN (SELECT code FROM recent_views ORDER BY viewed_at DESC LIMIT $_maxRecent)');
    }
    notifyListeners();
  }

  Future<void> removeRecent(String code) async {
    _recent.removeWhere((r) => r.code == code);
    await _db?.delete('recent_views', where: 'code = ?', whereArgs: [code]);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _recent.clear();
    await _db?.delete('recent_views');
    notifyListeners();
  }

  // ---- Copy to the account ------------------------------------------------

  void _scheduleSync() {
    if (AccountController.instance.profile == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () => unawaited(sync()));
  }

  /// Merges this phone's bookmarks and folders with the account's copy.
  /// For each entry the most recent change wins (deletions included).
  Future<void> sync() async {
    final userId = AccountController.instance.profile?.id;
    if (userId == null) return;
    try {
      final client = Supabase.instance.client;
      final serverFolders = await client.from('user_bookmark_folders').select();
      final serverBookmarks = await client.from('user_bookmarks').select();

      final pushFolders = <Map<String, Object?>>[];
      final remoteFolders = {for (final r in serverFolders) r['id'] as String: BookmarkFolder.fromRow(r)};
      for (final f in remoteFolders.values) {
        final local = _folders[f.id];
        if (local == null || f.updatedAt.isAfter(local.updatedAt)) {
          _folders[f.id] = f;
          await _db?.insert('bookmark_folders', f.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final f in _folders.values) {
        final remote = remoteFolders[f.id];
        if (remote == null || f.updatedAt.isAfter(remote.updatedAt)) {
          pushFolders.add({...f.toRow(), 'deleted': f.deleted, 'user_id': userId});
        }
      }

      final pushBookmarks = <Map<String, Object?>>[];
      final remoteBookmarks = {for (final r in serverBookmarks) r['code'] as String: Bookmark.fromRow(r)};
      for (final b in remoteBookmarks.values) {
        final local = _bookmarks[b.code];
        if (local == null || b.updatedAt.isAfter(local.updatedAt)) {
          _bookmarks[b.code] = b;
          await _db?.insert('bookmarks', b.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final b in _bookmarks.values) {
        final remote = remoteBookmarks[b.code];
        if (remote == null || b.updatedAt.isAfter(remote.updatedAt)) {
          pushBookmarks.add({...b.toRow(), 'deleted': b.deleted, 'user_id': userId});
        }
      }

      if (pushFolders.isNotEmpty) await client.from('user_bookmark_folders').upsert(pushFolders);
      if (pushBookmarks.isNotEmpty) await client.from('user_bookmarks').upsert(pushBookmarks);
      notifyListeners();
    } catch (e) {
      debugPrint('Bookmarks not synced: $e');
    }
  }
}
