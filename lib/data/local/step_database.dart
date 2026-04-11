import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class StepDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'trackon_steps.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE steps_display (
            date TEXT PRIMARY KEY,
            step_count INTEGER NOT NULL DEFAULT 0,
            distance_km REAL NOT NULL DEFAULT 0.0,
            calories REAL NOT NULL DEFAULT 0.0,
            goal INTEGER NOT NULL DEFAULT 10000,
            trusted INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE steps_raw (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time_utc TEXT NOT NULL,
            end_time_utc TEXT NOT NULL,
            start_time_local TEXT NOT NULL,
            end_time_local TEXT NOT NULL,
            steps_value INTEGER NOT NULL,
            date TEXT NOT NULL,
            source TEXT
          )
        ''');

        // Unique constraint to avoid duplicate raw intervals
        await db.execute('''
          CREATE UNIQUE INDEX idx_raw_unique
          ON steps_raw (start_time_utc, end_time_utc)
        ''');

        await db.execute('''
          CREATE TABLE sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ============ DISPLAY DATA ============

  static Future<void> upsertDisplay({
    required String date,
    required int stepCount,
    required double distanceKm,
    required double calories,
    required int goal,
    required bool trusted,
  }) async {
    final db = await database;
    await db.insert('steps_display', {
      'date': date,
      'step_count': stepCount,
      'distance_km': distanceKm,
      'calories': calories,
      'goal': goal,
      'trusted': trusted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getDisplay(String date) async {
    final db = await database;
    final rows = await db.query(
      'steps_display',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<List<Map<String, dynamic>>> getDisplayRange(
    String fromDate,
    String toDate,
  ) async {
    final db = await database;
    return db.query(
      'steps_display',
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
      orderBy: 'date DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getUntrustedDisplays() async {
    final db = await database;
    return db.query('steps_display', where: 'trusted = 0');
  }

  static Future<String?> getEarliestUntrustedDate() async {
    final db = await database;
    final rows = await db.query(
      'steps_display',
      columns: ['date'],
      where: 'trusted = 0',
      orderBy: 'date ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['date'] as String;
  }

  static Future<void> deleteDisplayBefore(String beforeDate) async {
    final db = await database;
    await db.delete(
      'steps_display',
      where: 'date < ?',
      whereArgs: [beforeDate],
    );
  }

  // ============ RAW DATA ============

  static Future<void> insertRaw({
    required String startTimeUtc,
    required String endTimeUtc,
    required String startTimeLocal,
    required String endTimeLocal,
    required int stepsValue,
    required String date,
    String? source,
  }) async {
    final db = await database;
    await db.insert('steps_raw', {
      'start_time_utc': startTimeUtc,
      'end_time_utc': endTimeUtc,
      'start_time_local': startTimeLocal,
      'end_time_local': endTimeLocal,
      'steps_value': stepsValue,
      'date': date,
      'source': source,
    }, conflictAlgorithm: ConflictAlgorithm.ignore); // skip duplicates
  }

  static Future<List<Map<String, dynamic>>> getRawSince(
    String sinceTimestamp,
  ) async {
    final db = await database;
    return db.query(
      'steps_raw',
      where: 'start_time_utc >= ?',
      whereArgs: [sinceTimestamp],
      orderBy: 'start_time_utc ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getRawForDate(String date) async {
    final db = await database;
    return db.query(
      'steps_raw',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_time ASC',
    );
  }

  /// Delete raw data that's been successfully synced to backend.
  static Future<void> deleteRawBefore(String beforeTimestamp) async {
    final db = await database;
    await db.delete(
      'steps_raw',
      where: 'end_time_utc < ?',
      whereArgs: [beforeTimestamp],
    );
  }

  // ============ SYNC METADATA ============

  static Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  static Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('sync_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static const String keyLastBackendSync = 'last_backend_sync';
  static const String keyLastMobileDedup = 'last_mobile_dedup';
}
