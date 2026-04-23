import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Dev-only on-device log store. Separate SQLite file so reads/writes don't
/// contend with the activity or step DBs. Not used in production.
class LoggerDatabase {
  static Database? _db;

  static const String table = 'logs';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'trackon_logs.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp_ms INTEGER NOT NULL,
            level TEXT NOT NULL,
            tag TEXT NOT NULL,
            message TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_logs_ts ON $table(timestamp_ms DESC)');
      },
    );
  }

  /// Batch insert — one transaction, one write. Cheaper than N inserts.
  static Future<void> insertBatch(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(table, row);
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, Object?>>> getAll({int limit = 2000}) async {
    final db = await database;
    return db.query(
      table,
      orderBy: 'timestamp_ms DESC, id DESC',
      limit: limit,
    );
  }

  static Future<void> truncate() async {
    final db = await database;
    await db.delete(table);
  }
}
