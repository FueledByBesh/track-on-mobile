import 'package:flutter/material.dart';
import '../api_client.dart';
import '../local/step_database.dart';
import '../models/daily_steps.dart';
import 'health_service.dart';
import 'step_service.dart';

/// Average stride length in km and calories per step — same as backend.
const double _avgStrideKm = 0.000762;
const double _caloriesPerStep = 0.04;

class StepSyncService {
  final StepApiService _api;
  final ApiClient _apiClient;

  StepSyncService(this._api, this._apiClient);

  /// Main entry point. Called when app activates or user refreshes.
  /// Returns display data for the last 7 days.
  Future<List<DailySteps>> syncAndGetDisplayData({
    required bool isOnline,
  }) async {
    if (isOnline) {
      return _onlineFlow();
    } else {
      return _offlineFlow();
    }
  }

  // ============ ONLINE FLOW ============

  Future<List<DailySteps>> _onlineFlow() async {
    debugPrint("Starting online sync flow");
    // 1. Get last backend sync timestamp
    DateTime? lastBackendSync = await _getLastBackendSync(isOnline: true);

    // 2. Determine the range to read from Health Connect
    final from =
        lastBackendSync ??
        DateTime.now().toUtc().subtract(const Duration(days: 30));

    // 3. Read raw intervals from Health Connect
    final rawIntervals = await HealthService.getSteps(since: from);

    // 4. Save raw intervals to local DB (safety net)
    for (final interval in rawIntervals) {
      await StepDatabase.insertRaw(
        startTimeUtc: interval.startTime,
        startTimeLocal: interval.startTimeLocal,
        endTimeUtc: interval.endTime,
        endTimeLocal: interval.endTimeLocal,
        stepsValue: interval.stepsValue,
        date: interval.date,
        source: interval.source,
      );
    }

    String rangeEnd = DateTime.now().toUtc().toIso8601String();
    // 5. Send raw data to backend
    try {
      final unsyncedRaw = await _getUnsyncedRaw(since: from);
      if (unsyncedRaw.isNotEmpty) {
        await _api.syncSteps(
          unsyncedRaw,
          rangeStart: from.toUtc().toIso8601String(),
          rangeEnd: rangeEnd,
        );
      }

      // 6. Reconcile untrusted data with backend
      //    Fetch from earliest untrusted date to overwrite local dedup values
      DateTime now = DateTime.now().toLocal();
      final today = now.toIso8601String().split('T')[0];
      final weekAgo = now
          .subtract(const Duration(days: 7))
          .toIso8601String()
          .split('T')[0];
      final earliestUntrusted = await StepDatabase.getEarliestUntrustedDate();
      final fetchFrom =
          earliestUntrusted != null && earliestUntrusted.compareTo(weekAgo) < 0
          ? earliestUntrusted
          : weekAgo;
      final trustedData = await _api.getHistory(fetchFrom, today);

      // 7. Cache trusted display data
      for (final day in trustedData) {
        var today = DateTime.now().toLocal().toIso8601String().split('T')[0];
        await StepDatabase.upsertDisplay(
          date: day.date,
          stepCount: day.stepCount,
          distanceKm: day.distanceKm,
          calories: day.caloriesBurned,
          goal: day.goal,
          // Mark as trusted if it's not today (today's data can still change as we get more intervals)
          trusted: day.date.compareTo(today) != 0,
        );
      }

      // 8. Update sync timestamps, clean up raw data, trim old display cache
      await StepDatabase.setMeta(StepDatabase.keyLastBackendSync, rangeEnd);
      await StepDatabase.setMeta(StepDatabase.keyLastMobileDedup, rangeEnd);
      await StepDatabase.deleteRawBefore(rangeEnd);
      final cutoff = now
          .subtract(const Duration(days: 30))
          .toIso8601String()
          .split('T')[0];
      await StepDatabase.deleteDisplayBefore(cutoff);

      // 9. Return 7-day history from local DB (all trusted now)
      final allRows = await StepDatabase.getDisplayRange(weekAgo, today);
      return allRows.map(_rowToDisplay).toList();
    } catch (e) {
      debugPrint('Backend sync failed, falling back to local: $e');
      // Backend unreachable mid-flow — fall back to offline behavior
      return _offlineFlow();
    }
  }

  // ============ OFFLINE FLOW ============

  Future<List<DailySteps>> _offlineFlow() async {
    final now = DateTime.now().toUtc();

    // 1. Determine what needs fresh dedup
    final lastDedupStr = await StepDatabase.getMeta(
      StepDatabase.keyLastMobileDedup,
    );
    final lastDedup = lastDedupStr != null
        ? DateTime.parse(lastDedupStr)
        : now.subtract(const Duration(days: 7));

    // 3. Read new data from Health Connect since last dedup
    final newRaw = await HealthService.getSteps(since: lastDedup);

    // 4. Save raw to local DB
    for (final interval in newRaw) {
      await StepDatabase.insertRaw(
        startTimeUtc: interval.startTime,
        startTimeLocal: interval.startTimeLocal,
        endTimeUtc: interval.endTime,
        endTimeLocal: interval.endTimeLocal,
        stepsValue: interval.stepsValue,
        date: interval.date,
        source: interval.source,
      );
    }

    // 5. Deduplicate and compute display values for affected dates
    final affectedDates = <String>{};
    for (final interval in newRaw) {
      affectedDates.add(interval.date);
    }

    for (final date in affectedDates) {
      // Check if we already have trusted data for this date
      final existing = await StepDatabase.getDisplay(date);
      if (existing != null && existing['trusted'] == 1) {
        // Trusted data exists — add new steps on top (incremental)
        final rawForDate = await StepDatabase.getRawForDate(date);
        final dedupedSteps = _deduplicateIntervals(rawForDate);
        final totalSteps = dedupedSteps > (existing['step_count'] as int)
            ? dedupedSteps
            : existing['step_count'] as int;
        await StepDatabase.upsertDisplay(
          date: date,
          stepCount: totalSteps,
          distanceKm: totalSteps * _avgStrideKm,
          calories: totalSteps * _caloriesPerStep,
          goal: existing['goal'] as int,
          trusted: false, // no longer fully trusted since we added local data
        );
      } else {
        // No trusted data — full local dedup
        final rawForDate = await StepDatabase.getRawForDate(date);
        final dedupedSteps = _deduplicateIntervals(rawForDate);
        await StepDatabase.upsertDisplay(
          date: date,
          stepCount: dedupedSteps,
          distanceKm: dedupedSteps * _avgStrideKm,
          calories: dedupedSteps * _caloriesPerStep,
          goal: 10000,
          trusted: false,
        );
      }
    }

    // 6. Update last mobile dedup
    await StepDatabase.setMeta(
      StepDatabase.keyLastMobileDedup,
      now.toUtc().subtract(Duration(seconds: 30)).toIso8601String(),
    );

    // 7. Return all display data for the week
    DateTime localNow = DateTime.now().toLocal();
    final today = localNow.toIso8601String().split('T')[0];
    final weekAgo = localNow
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .split('T')[0];
    final allRows = await StepDatabase.getDisplayRange(weekAgo, today);
    return allRows.map(_rowToDisplay).toList();
  }

  // ============ HELPERS ============

  /// Client-side deduplication: group by source, for overlapping intervals
  /// from different sources, pick the one with highest steps.
  int _deduplicateIntervals(List<Map<String, dynamic>> rawRows) {
    if (rawRows.isEmpty) return 0;

    // Group intervals by source
    final bySource = <String, List<Map<String, dynamic>>>{};
    for (final row in rawRows) {
      final source = (row['source'] as String?) ?? 'unknown';
      bySource.putIfAbsent(source, () => []).add(row);
    }

    if (bySource.length == 1) {
      // Single source — just sum all intervals (no overlap within same source)
      return rawRows.fold<int>(0, (sum, r) => sum + (r['steps_value'] as int));
    }

    // Multiple sources — sum each source's total, take the max
    // This is a simple heuristic: the source with the most steps likely has the best coverage
    int maxTotal = 0;
    for (final intervals in bySource.values) {
      final total = intervals.fold<int>(
        0,
        (sum, r) => sum + (r['steps_value'] as int),
      );
      if (total > maxTotal) maxTotal = total;
    }
    return maxTotal;
  }

  Future<DateTime?> _getLastBackendSync({required bool isOnline}) async {
    if (isOnline) {
      try {
        final response = await _apiClient.dio.get('/api/steps/last-sync');
        if (response.data['has_data'] == true) {
          return DateTime.parse(response.data['last_sync']);
        }
        // Backend explicitly says no data — return null regardless of local cache
        return null;
      } catch (_) {
        // Backend unreachable — fall through to local
      }
    }
    final local = await StepDatabase.getMeta(StepDatabase.keyLastBackendSync);
    return local != null ? DateTime.parse(local) : null;
  }

  /// Returns raw intervals newer than [since]. The caller (online flow)
  /// passes the backend-resolved cutoff so we don't accidentally re-upload
  /// rows the backend already has.
  Future<List<StepInterval>> _getUnsyncedRaw({required DateTime since}) async {
    final rows = await StepDatabase.getRawSince(since.toUtc().toIso8601String());
    return rows
        .map(
          (r) => StepInterval(
            startUtc: r['start_time_utc'] as String,
            startLocal: r['start_time_local'] as String,
            endUtc: r['end_time_utc'] as String,
            endLocal: r['end_time_local'] as String,
            stepsValue: r['steps_value'] as int,
            date: r['date'] as String,
            source: r['source'] as String?,
          ),
        )
        .toList();
  }

  DailySteps _rowToDisplay(Map<String, dynamic> row) {
    return DailySteps(
      date: row['date'] as String,
      stepCount: row['step_count'] as int,
      goal: row['goal'] as int,
      progressPercent: (row['goal'] as int) > 0
          ? ((row['step_count'] as int) * 100.0 / (row['goal'] as int)).clamp(
              0,
              100,
            )
          : 0,
      distanceKm: row['distance_km'] as double,
      caloriesBurned: row['calories'] as double,
    );
  }
}
