import 'package:flutter/foundation.dart';

import '../local/activity_database.dart';
import '../models/activity.dart';
import 'activity_service.dart';

/// Uploads finalized local sessions to the backend. Decoupled from the
/// recorder so the recording loop never blocks on network.
///
/// Strategy: fire-and-forget on stop; on failure the row stays marked
/// unsynced and can be retried later (e.g. on connectivity regained).
class ActivitySyncService {
  final ActivityApiService _api;

  ActivitySyncService(this._api);

  /// Try to upload one specific local session. Swallows errors — the row
  /// stays unsynced and will be picked up on the next sweep.
  Future<bool> syncSession(String localId) async {
    try {
      final payload = await _buildPayload(localId);
      if (payload == null) return false;
      final serverId = await _api.uploadActivity(payload);
      await ActivityDatabase.markSynced(localId, serverId);
      return true;
    } catch (e) {
      debugPrint('ActivitySyncService: failed to sync $localId: $e');
      await ActivityDatabase.incrementSyncAttempts(localId);
      return false;
    }
  }

  /// Upload every completed-but-unsynced session. Call on app start, on
  /// connectivity regained, and after a stop.
  Future<void> syncAll() async {
    final rows = await ActivityDatabase.getUnsyncedSessions();
    for (final row in rows) {
      await syncSession(row['id'] as String);
    }
  }

  Future<ActivityUploadPayload?> _buildPayload(String localId) async {
    final session = await ActivityDatabase.getSession(localId);
    if (session == null) return null;
    if (session['ended_at'] == null) return null; // not finalized yet

    final pointRows = await ActivityDatabase.getPoints(localId);
    final pauseRows = await ActivityDatabase.getPauses(localId);

    final startedAtMs = session['started_at'] as int;
    final startedAtLocal = session['started_at_local'] as String;
    final endedAtMs = session['ended_at'] as int;
    final endedAtLocal = session['ended_at_local'] as String;
    final pausedMs = session['paused_ms'] as int;
    final distanceKm = (session['distance_km'] as num).toDouble();

    final durationSec =
        ((endedAtMs - startedAtMs - pausedMs) ~/ 1000).clamp(0, 1 << 31);

    final route = pointRows
        .map((r) => RoutePoint(
              lat: (r['lat'] as num).toDouble(),
              lon: (r['lon'] as num).toDouble(),
              timestampMs: r['timestamp'] as int,
              altitude: (r['altitude'] as num?)?.toDouble(),
              accuracy: (r['accuracy'] as num?)?.toDouble(),
              speed: (r['speed'] as num?)?.toDouble(),
              segmentIndex: r['segment_index'] as int? ?? 0,
            ))
        .toList();

    final pauses = pauseRows
        .where((r) => r['pause_end'] != null)
        .map((r) => PauseInterval(
              startMs: r['pause_start'] as int,
              endMs: r['pause_end'] as int,
            ))
        .toList();

    return ActivityUploadPayload(
      clientId: localId,
      activityType: session['activity_type'] as String,
      startedAtMs: startedAtMs,
      startedAtLocal: startedAtLocal,
      endedAtMs: endedAtMs,
      endedAtLocal: endedAtLocal,
      distanceKm: distanceKm,
      durationSeconds: durationSec,
      pausedMs: pausedMs,
      route: route,
      pauses: pauses,
    );
  }
}
