import '../local/workout_library_database.dart';
import '../models/workout.dart';
import 'logger_service.dart';
import 'workout_service.dart';

/// Orchestrates the workout library cache. The public contract:
///
///   ensureFresh() — cheap: hits /api/workouts/status, compares count +
///                   lastEditAt against the local cache, and refetches
///                   the full library only if they differ (or the
///                   cache is empty). Safe to call on every app open.
///
///   getAll()      — returns the cached workouts. Fast, local read.
///
/// Offline behavior: if the status probe fails (no network, backend
/// down), ensureFresh silently falls back to the existing cache.
/// getAll() still returns whatever's local.
class WorkoutLibraryService {
  final WorkoutApiService _api;

  WorkoutLibraryService(this._api);

  /// Returns the fresh library. If cache is missing, it's a hard error
  /// on first launch without network — caller should surface it.
  Future<List<Workout>> ensureFresh() async {
    try {
      final serverStatus = await _api.getStatus();
      final cachedStatus = await WorkoutLibraryDatabase.getCachedStatus();

      final stale = cachedStatus == null ||
          cachedStatus.count != serverStatus.count ||
          serverStatus.lastEditAt.isAfter(cachedStatus.lastEditAt);

      if (!stale) {
        Logger.d('LIB', 'Cache hit (count=${serverStatus.count})');
        return WorkoutLibraryDatabase.getAll();
      }

      Logger.i(
        'LIB',
        'Cache stale — refetching '
            '(cached=${cachedStatus?.count ?? 0}/${cachedStatus?.lastEditAt ?? "never"} '
            'server=${serverStatus.count}/${serverStatus.lastEditAt})',
      );
      final fresh = await _api.getAll();
      await WorkoutLibraryDatabase.replaceAll(fresh, serverStatus);
      return fresh;
    } catch (e) {
      // Network or backend error — fall back to whatever we have cached.
      // First-launch case (no cache + no network) returns an empty list;
      // the UI's empty state handles it.
      Logger.w('LIB', 'ensureFresh failed, using cache: $e');
      return WorkoutLibraryDatabase.getAll();
    }
  }

  /// Reads from cache only, no network. Used when we just need the
  /// current library without forcing a probe.
  Future<List<Workout>> getAll() => WorkoutLibraryDatabase.getAll();

  /// Force a full refetch, ignoring the cache's status. Used by the
  /// user-triggered "pull to refresh" gesture.
  Future<List<Workout>> forceRefresh() async {
    Logger.i('LIB', 'Force refresh');
    final serverStatus = await _api.getStatus();
    final fresh = await _api.getAll();
    await WorkoutLibraryDatabase.replaceAll(fresh, serverStatus);
    return fresh;
  }

  Future<void> clearCache() => WorkoutLibraryDatabase.clear();
}
