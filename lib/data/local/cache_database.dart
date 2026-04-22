import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Generic on-device HTTP response cache. One row per (endpoint, key)
/// pair with the raw JSON payload + the server's ETag + when we fetched
/// it. The combination of payload + etag drives conditional GETs via
/// `If-None-Match` so repeated reads short-circuit to 304 on the wire
/// and the client pays near-zero for unchanged data.
///
/// Keys are namespaced strings controlled by the caller, e.g.:
/// `user:me`, `user:{uuid}`, `user:handle:{handle}`,
/// `user-stats:{uuid}`, `club:{uuid}`, `feed:home:page:{n}`.
///
/// Not a cache of bytes — we deliberately store the parsed-then-
/// re-encoded JSON so the eviction/inspection tooling can show readable
/// entries in the debug memory inspector.
class CacheDatabase {
  static Database? _db;

  static const String table = 'cache_entries';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'trackon_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            etag TEXT,
            fetched_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_cache_fetched_at ON $table(fetched_at)');
      },
    );
  }

  static Future<Map<String, Object?>?> get(String key) async {
    final db = await database;
    final rows = await db.query(table, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> put({
    required String key,
    required String payload,
    String? etag,
    required int fetchedAtMs,
  }) async {
    final db = await database;
    await db.insert(
      table,
      {
        'key': key,
        'payload': payload,
        'etag': etag,
        'fetched_at': fetchedAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update only the fetched_at timestamp — used after a 304 so we know
  /// the cached payload was just re-validated.
  static Future<void> touchFetchedAt(String key, int fetchedAtMs) async {
    final db = await database;
    await db.update(
      table,
      {'fetched_at': fetchedAtMs},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  static Future<void> remove(String key) async {
    final db = await database;
    await db.delete(table, where: 'key = ?', whereArgs: [key]);
  }

  /// Delete every row whose key starts with [prefix]. Used for scoped
  /// invalidation (e.g. `user:*` after a follow action).
  static Future<int> removeByPrefix(String prefix) async {
    final db = await database;
    return db.delete(
      table,
      where: 'key LIKE ?',
      whereArgs: ['$prefix%'],
    );
  }

  static Future<void> clear() async {
    final db = await database;
    await db.delete(table);
  }
}
