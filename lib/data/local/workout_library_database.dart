import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/workout.dart';

/// Local cache for the workout library. Separate SQLite file so library
/// reads don't contend with activity tracking writes.
///
/// Tables:
///   workouts    — one row per workout, with muscles serialized as a JSON
///                 string column. Small enough (<50 entries) that we don't
///                 need a normalized join table on the client.
///   metadata    — single-row cache-invalidation state (count + lastEditAt)
///                 matched against the backend's /api/workouts/status.
class WorkoutLibraryDatabase {
  static Database? _db;

  static const _tableWorkouts = 'workouts';
  static const _tableMetadata = 'library_metadata';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'trackon_library.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableWorkouts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            recommended_sets INTEGER NOT NULL,
            recommended_reps INTEGER NOT NULL,
            approx_duration_minutes INTEGER,
            rest_time_seconds INTEGER,
            tutorial_video_url TEXT,
            muscles_json TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_workouts_category ON $_tableWorkouts(category)');
        await db.execute(
            'CREATE INDEX idx_workouts_name ON $_tableWorkouts(name)');

        await db.execute('''
          CREATE TABLE $_tableMetadata (
            key TEXT PRIMARY KEY,
            count INTEGER NOT NULL,
            last_edit_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ============ WORKOUTS ============

  static Future<List<Workout>> getAll() async {
    final db = await database;
    final rows = await db.query(_tableWorkouts, orderBy: 'name ASC');
    return rows.map(_rowToWorkout).toList();
  }

  static Future<int> count() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $_tableWorkouts');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Replace the entire cache atomically. Either the old rows are still
  /// there (no change) or the new rows are in — never an intermediate state.
  static Future<void> replaceAll(
    List<Workout> workouts,
    WorkoutLibraryStatus status,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableWorkouts);
      for (final w in workouts) {
        await txn.insert(_tableWorkouts, _workoutToRow(w));
      }
      await txn.insert(
        _tableMetadata,
        {
          'key': 'workouts',
          'count': status.count,
          'last_edit_at': status.lastEditAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ============ METADATA ============

  static Future<WorkoutLibraryStatus?> getCachedStatus() async {
    final db = await database;
    final rows = await db.query(
      _tableMetadata,
      where: 'key = ?',
      whereArgs: ['workouts'],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return WorkoutLibraryStatus(
      count: row['count'] as int,
      lastEditAt: DateTime.parse(row['last_edit_at'] as String),
    );
  }

  /// Nuke the cache entirely. Used by the "force refresh" code path and
  /// sign-out cleanup.
  static Future<void> clear() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableWorkouts);
      await txn.delete(_tableMetadata);
    });
  }

  // ============ ROW <-> MODEL ============

  static Map<String, Object?> _workoutToRow(Workout w) {
    return {
      'id': w.id,
      'name': w.name,
      'category': w.category.value,
      'recommended_sets': w.recommendedSets,
      'recommended_reps': w.recommendedReps,
      'approx_duration_minutes': w.approxDurationMinutes,
      'rest_time_seconds': w.restTimeSeconds,
      'tutorial_video_url': w.tutorialVideoUrl,
      'muscles_json': jsonEncode(w.muscles.map((m) => m.toJson()).toList()),
    };
  }

  static Workout _rowToWorkout(Map<String, Object?> row) {
    final musclesJson = row['muscles_json'] as String? ?? '[]';
    final muscles = (jsonDecode(musclesJson) as List<dynamic>)
        .map((e) => WorkoutMuscle.fromJson(e as Map<String, dynamic>))
        .toList();
    return Workout(
      id: row['id'] as String,
      name: row['name'] as String,
      category: WorkoutCategory.fromValue(row['category'] as String),
      recommendedSets: row['recommended_sets'] as int,
      recommendedReps: row['recommended_reps'] as int,
      approxDurationMinutes: row['approx_duration_minutes'] as int?,
      restTimeSeconds: row['rest_time_seconds'] as int?,
      tutorialVideoUrl: row['tutorial_video_url'] as String?,
      muscles: muscles,
    );
  }
}
