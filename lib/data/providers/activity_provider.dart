import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/activity.dart';
import '../services/activity_recorder.dart';
import 'activity_history_provider.dart';

/// Wraps ActivityRecorder for UI consumption.
/// Notifies listeners when recorder state changes.
class ActivityProvider extends ChangeNotifier {
  final ActivityRecorder _recorder;
  final ActivityHistoryProvider _historyProvider;

  ActivityProvider(this._recorder, this._historyProvider) {
    _recorder.onStateChanged = notifyListeners;
  }

  // ============ STATE GETTERS ============

  Activity? get currentActivity => _recorder.currentActivity;
  bool get isTracking => _recorder.isTracking;
  bool get isPaused => _recorder.isPaused;
  double get liveDistance => _recorder.liveDistance;
  int get liveDuration => _recorder.liveDuration;
  List<Position> get routePoints => _recorder.routePoints;
  String? get activityType => _recorder.activityType;

  // ============ ACTIONS ============

  Future<bool> start(String type) => _recorder.start(type);

  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  Future<Activity?> stop() async {
    final result = await _recorder.stop();
    // Refresh history silently after stop
    await _historyProvider.refreshAfterStop();
    return result;
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
