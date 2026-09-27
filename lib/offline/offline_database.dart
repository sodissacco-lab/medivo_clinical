import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The on-phone SQLite database that holds downloaded content (blueprint §22).
class OfflineDatabase {
  static Database? _db;

  static Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final folder = await getDatabasesPath();
    final db = await openDatabase(
      p.join(folder, 'medivo_offline.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            item_id          TEXT PRIMARY KEY,
            code             TEXT NOT NULL,
            type             TEXT NOT NULL,
            title            TEXT NOT NULL,
            category         TEXT,
            synonyms         TEXT NOT NULL DEFAULT '[]',
            is_essential     INTEGER NOT NULL DEFAULT 0,
            version_id       TEXT NOT NULL,
            version_label    TEXT,
            summary          TEXT,
            body             TEXT NOT NULL,
            sources          TEXT,
            metadata         TEXT NOT NULL DEFAULT '{}',
            author_name      TEXT,
            approver_name    TEXT,
            published_at     TEXT,
            last_reviewed_at TEXT,
            next_review_at   TEXT,
            saved_at         TEXT NOT NULL
          )''');
        await db.execute('CREATE INDEX items_type_idx ON items (type)');
        await db.execute('CREATE INDEX items_code_idx ON items (code)');
        await db.execute('''
          CREATE TABLE packs (
            code           TEXT PRIMARY KEY,
            name           TEXT NOT NULL,
            description    TEXT NOT NULL,
            content_types  TEXT NOT NULL,
            essential_only INTEGER NOT NULL,
            sort_order     INTEGER NOT NULL,
            selected       INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    _db = db;
    return db;
  }
}
