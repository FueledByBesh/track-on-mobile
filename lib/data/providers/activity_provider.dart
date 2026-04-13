import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../models/map_point.dart';
import '../services/activity_recorder.dart';
import '../services/activity_sync_service.dart';
import 'activity_history_provider.dart';

/// UI-facing wrapper around ActivityRecorder. Forwards state and actions;
/// coordinates post-stop sync and history refresh.
class ActivityProvider extends ChangeNotifier {
  final ActivityRecorder _recorder;
  final ActivitySyncService _sync;
  final ActivityHistoryProvider _history;

  ActivityProvider(this._recorder, this._sync, this._history) {
    _recorder.onStateChanged = notifyListeners;
    // Best-effort sweep: any unsynced sessions from previous launches.
    _sync.syncAll().then((_) => _history.refreshAfterStop());
  }

  // ============ STATE ============

  bool get isTracking => _recorder.isTracking;
  bool get isPaused => _recorder.isPaused;
  String? get activityType => _recorder.activityType;
  List<MapPoint> get routePoints => _recorder.routePoints;
  MapPoint? get lastPosition => _recorder.lastPosition;
  double get liveDistance => _recorder.liveDistanceKm;
  int get liveDuration => _recorder.liveDurationSeconds;

  // ============ ACTIONS ============

  Future<bool> start(String type) => _recorder.start(type);

  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  Future<CompletedSessionResult?> stop() async {
    final result = await _recorder.stop();
    if (result != null) {
      // Fire-and-forget upload. History refreshes whether sync succeeds or
      // not — local sessions are visible to the user either way once we
      // wire a "pending upload" indicator.
      _sync.syncSession(result.localId).then((_) {
        _history.refreshAfterStop();
      });
    }
    return result;
  }

  Future<void> discard() => _recorder.discard();

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
