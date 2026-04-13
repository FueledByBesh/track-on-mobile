import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local-first activity DB. SQLite is the source of truth while a run is
/// in progress. Backend sync happens only after the session is finalized.
class ActivityDatabase {
  static Database? _db;

  static const String sessions = 'activity_sessions';
  static const String points = 'location_points';
  static const String pauses = 'pause_intervals';

  // Session status values
  static const String statusRecording = 'RECORDING';
  static const String statusPaused = 'PAUSED';
  static const String statusCompleted = 'COMPLETED';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'trackon_activities.db');
    return openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $sessions ADD COLUMN started_at_local TEXT');
          await db.execute('ALTER TABLE $sessions ADD COLUMN ended_at_local TEXT');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $sessions (
            id TEXT PRIMARY KEY,
            activity_type TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            started_at_local TEXT NOT NULL,
            ended_at INTEGER,
            ended_at_local TEXT,
            distance_km REAL NOT NULL DEFAULT 0,
            paused_ms INTEGER NOT NULL DEFAULT 0,
            synced INTEGER NOT NULL DEFAULT 0,
            sync_attempts INTEGER NOT NULL DEFAULT 0,
            server_id TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            altitude REAL,
            accuracy REAL,
            speed REAL,
            segment_index INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (session_id) REFERENCES $sessions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_points_session ON $points(session_id, seq)');

        await db.execute('''
          CREATE TABLE $pauses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            pause_start INTEGER NOT NULL,
            pause_end INTEGER,
            FOREIGN KEY (session_id) REFERENCES $sessions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_pauses_session ON $pauses(session_id)');
      },
    );
  }

  // ============ SESSIONS ============

  static Future<void> insertSession({
    required String id,
    required String activityType,
    required int startedAt,
    required String startedAtLocal,
  }) async {
    final db = await database;
    await db.insert(sessions, {
      'id': id,
      'activity_type': activityType,
      'status': statusRecording,
      'started_at': startedAt,
      'started_at_local': startedAtLocal,
      'distance_km': 0,
      'paused_ms': 0,
      'synced': 0,
      'sync_attempts': 0,
    });
  }

  static Future<void> updateSessionStatus(String id, String status) async {
    final db = await database;
    await db.update(sessions, {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateSessionDistance(String id, double distanceKm) async {
    final db = await database;
    await db.update(
      sessions,
      {'distance_km': distanceKm},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> completeSession({
    required String id,
    required int endedAt,
    required String endedAtLocal,
    required double distanceKm,
    required int pausedMs,
  }) async {
    final db = await database;
    await db.update(
      sessions,
      {
        'status': statusCompleted,
        'ended_at': endedAt,
        'ended_at_local': endedAtLocal,
        'distance_km': distanceKm,
        'paused_ms': pausedMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markSynced(String id, String serverId) async {
    final db = await database;
    await db.update(
      sessions,
      {'synced': 1, 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> incrementSyncAttempts(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $sessions SET sync_attempts = sync_attempts + 1 WHERE id = ?',
      [id],
    );
  }

  static Future<Map<String, dynamic>?> getSession(String id) async {
    final db = await database;
    final rows = await db.query(sessions, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Any session still marked RECORDING/PAUSED on app launch — needs recovery.
  static Future<Map<String, dynamic>?> getInProgressSession() async {
    final db = await database;
    final rows = await db.query(
      sessions,
      where: 'status IN (?, ?)',
      whereArgs: [statusRecording, statusPaused],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Completed sessions waiting to be uploaded.
  static Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    final db = await database;
    return db.query(
      sessions,
      where: 'status = ? AND synced = 0',
      whereArgs: [statusCompleted],
      orderBy: 'started_at ASC',
    );
  }

  static Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete(points, where: 'session_id = ?', whereArgs: [id]);
    await db.delete(pauses, where: 'session_id = ?', whereArgs: [id]);
    await db.delete(sessions, where: 'id = ?', whereArgs: [id]);
  }

  // ============ LOCATION POINTS ============

  static Future<int> insertPoint({
    required String sessionId,
    required int seq,
    required int timestamp,
    required double lat,
    required double lon,
    double? altitude,
    double? accuracy,
    double? speed,
    required int segmentIndex,
  }) async {
    final db = await database;
    return db.insert(points, {
      'session_id': sessionId,
      'seq': seq,
      'timestamp': timestamp,
      'lat': lat,
      'lon': lon,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'segment_index': segmentIndex,
    });
  }

  static Future<List<Map<String, dynamic>>> getPoints(String sessionId) async {
    final db = await database;
    return db.query(
      points,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'seq ASC',
    );
  }

  // ============ PAUSE INTERVALS ============

  static Future<int> openPause({
    required String sessionId,
    required int pauseStart,
  }) async {
    final db = await database;
    return db.insert(pauses, {
      'session_id': sessionId,
      'pause_start': pauseStart,
    });
  }

  static Future<void> closePause({
    required int pauseRowId,
    required int pauseEnd,
  }) async {
    final db = await database;
    await db.update(
      pauses,
      {'pause_end': pauseEnd},
      where: 'id = ?',
      whereArgs: [pauseRowId],
    );
  }

  /// Sum of all completed pauses for a session.
  static Future<int> totalPausedMs(String sessionId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(pause_end - pause_start), 0) AS total '
      'FROM $pauses WHERE session_id = ? AND pause_end IS NOT NULL',
      [sessionId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getPauses(String sessionId) async {
    final db = await database;
    return db.query(
      pauses,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'pause_start ASC',
    );
  }
}
