import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/notification.dart';

/// Dedicated on-device cache for notifications. Kept in its own DB
/// file (not the generic `CacheStore`) because notifications are
/// mutated in place — mark-read, delete, and merged-insert from
/// incremental deltas — rather than replaced wholesale.
///
/// Single table: `notifications`, keyed by server id so incremental
/// fetches upsert safely. The delta cursor is derived at query time
/// from `MAX(created_at)` instead of a separately-stored client
/// timestamp, so it's immune to client clock skew and
/// self-healing if the cache ever gets manually cleared.
class NotificationCacheDatabase {
  static Database? _db;

  static const String tableNotifications = 'notifications';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'trackon_notifications.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableNotifications (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            marked_as_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_notifications_created_at '
            'ON $tableNotifications(created_at DESC)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2: drop the `meta` table that held the
        // last_fetched_at cursor. The cursor is now derived from
        // MAX(created_at) on the notifications table itself.
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS meta');
        }
      },
    );
  }

  // ============ LIST ============

  /// Returns everything we've cached, newest first. Matches the order
  /// the server already sorts in, so the UI can render this directly.
  static Future<List<AppNotification>> readAll() async {
    final db = await database;
    final rows = await db.query(
      tableNotifications,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_rowToNotification).toList();
  }

  /// Max cached `created_at`, used as the `?since=` cursor on the
  /// delta fetch. Null means the cache is empty — the caller should
  /// fall back to a full resync rather than a delta.
  static Future<String?> maxCreatedAt() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(created_at) AS m FROM $tableNotifications',
    );
    final v = rows.first['m'];
    return v is String ? v : null;
  }

  // ============ WRITE PATHS ============

  /// Insert-or-replace in a single transaction. Used by both the
  /// delta merge (upsert newer rows) and the full resync (after a
  /// [clear]).
  static Future<void> upsertAll(List<AppNotification> items) async {
    if (items.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final n in items) {
        batch.insert(
          tableNotifications,
          _notificationToRow(n),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Update a single row — used when the user toggles read/unread
  /// locally before the server write completes.
  static Future<void> upsertOne(AppNotification item) async {
    final db = await database;
    await db.insert(
      tableNotifications,
      _notificationToRow(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeById(String id) async {
    final db = await database;
    await db.delete(tableNotifications, where: 'id = ?', whereArgs: [id]);
  }

  /// Wipe every notification row. Used by "full resync" before
  /// writing the freshly-fetched authoritative list back.
  static Future<void> clear() async {
    final db = await database;
    await db.delete(tableNotifications);
  }

  // ============ ROW ↔ MODEL ============

  static Map<String, Object?> _notificationToRow(AppNotification n) {
    return {
      'id': n.id,
      'title': n.title,
      'description': n.description,
      'marked_as_read': n.markedAsRead ? 1 : 0,
      'created_at': n.createdAt,
    };
  }

  static AppNotification _rowToNotification(Map<String, Object?> row) {
    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      markedAsRead: (row['marked_as_read'] as int) != 0,
      createdAt: row['created_at'] as String,
    );
  }
}
