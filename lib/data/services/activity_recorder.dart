import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../local/activity_database.dart';
import '../models/activity.dart';
import '../models/map_point.dart';
import 'location_filter.dart';
import 'location_tracker.dart';

/// Owns an in-progress activity. Local-first: every accepted GPS fix is
/// persisted to SQLite before anything else. In-memory aggregates exist only
/// to feed the UI instantly — SQLite is the source of truth and survives
/// app kills, crashes, and reboots.
///
/// Backend is untouched during recording. The finalized session is uploaded
/// via ActivitySyncService after [stop].
///
/// Designed so a foreground-service GPS source can be dropped in without
/// touching the recorder: anything implementing [LocationTracker] works.
class ActivityRecorder {
  final LocationTracker _locationTracker;

  ActivityRecorder(this._locationTracker);

  // ============ CALLBACK ============

  /// Notifies the wrapping provider. Fired on:
  /// - state transitions (start / pause / resume / stop)
  /// - each accepted point
  /// - once per second while recording (for derived duration)
  VoidCallback? onStateChanged;

  // ============ CURRENT SESSION STATE ============

  _Session? _session;

  // Route grouped by continuous segment. A new inner list is pushed on each
  // resume so the renderer can draw disconnected polylines across pause gaps
  // instead of a straight line through whatever the user did while paused.
  final List<List<MapPoint>> _segments = [];

  // Latest accepted raw position — exposed so the map can center on it
  // even before any route has accumulated.
  MapPoint? _lastPosition;

  // Monotonic seq within the session.
  int _nextSeq = 0;

  // Incremented on each resume. Lets the renderer draw the polyline as
  // disconnected segments across pause gaps.
  int _currentSegment = 0;

  // Pause bookkeeping.
  int _accumulatedPausedMs = 0;
  int? _currentPauseStartMs;
  int? _currentPauseRowId;

  // Live-computed distance (km). Also written to DB after each accepted point.
  double _liveDistanceKm = 0;

  // Filter is created per-session so state resets cleanly.
  LocationFilter? _filter;

  // Subscription to the tracker's stream and the 1s UI tick.
  StreamSubscription<Position>? _locationSub;
  Timer? _tickTimer;

  // ============ PUBLIC GETTERS ============

  bool get isTracking => _session != null;
  bool get isPaused => _session?.status == ActivityDatabase.statusPaused;
  String? get activityType => _session?.activityType;
  /// Route grouped by continuous segment. Each inner list is a polyline
  /// that should be drawn without connecting to neighbors — pause gaps
  /// live in between.
  List<List<MapPoint>> get routeSegments =>
      List.unmodifiable(_segments.map(List.unmodifiable));
  MapPoint? get lastPosition => _lastPosition;
  double get liveDistanceKm => _liveDistanceKm;

  /// Seconds elapsed since start, excluding time spent paused.
  /// Derived from wall clock — unaffected by Timer drift or app suspension.
  int get liveDurationSeconds {
    if (_session == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var paused = _accumulatedPausedMs;
    if (_currentPauseStartMs != null) {
      paused += now - _currentPauseStartMs!;
    }
    final elapsedMs = now - _session!.startedAtMs - paused;
    return elapsedMs < 0 ? 0 : elapsedMs ~/ 1000;
  }

  // ============ LIFECYCLE ============

  /// Start a new local session. Returns false if one is already active.
  Future<bool> start(String activityType) async {
    if (_session != null) return false;

    final id = _generateId();
    final nowLocal = DateTime.now();
    final nowMs = nowLocal.millisecondsSinceEpoch;

    await ActivityDatabase.insertSession(
      id: id,
      activityType: activityType,
      startedAt: nowMs,
      startedAtLocal: _localIso(nowLocal),
    );

    _session = _Session(
      id: id,
      activityType: activityType,
      startedAtMs: nowMs,
      status: ActivityDatabase.statusRecording,
    );
    _segments
      ..clear()
      ..add(<MapPoint>[]);
    _lastPosition = null;
    _nextSeq = 0;
    _currentSegment = 0;
    _accumulatedPausedMs = 0;
    _currentPauseStartMs = null;
    _currentPauseRowId = null;
    _liveDistanceKm = 0;
    _filter = LocationFilter(
      maxSpeedMetersPerSec: _maxSpeedForType(activityType),
    );

    _startLocationStream();
    _startTickTimer();
    _notify();
    return true;
  }

  Future<void> pause() async {
    if (_session == null || isPaused) return;

    _currentPauseStartMs = DateTime.now().millisecondsSinceEpoch;
    _currentPauseRowId = await ActivityDatabase.openPause(
      sessionId: _session!.id,
      pauseStart: _currentPauseStartMs!,
    );
    _session = _session!.copyWith(status: ActivityDatabase.statusPaused);
    await ActivityDatabase.updateSessionStatus(
      _session!.id,
      ActivityDatabase.statusPaused,
    );

    // Cut the GPS subscription entirely — saves battery.
    await _stopLocationStream();
    _notify();
  }

  Future<void> resume() async {
    if (_session == null || !isPaused) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_currentPauseStartMs != null && _currentPauseRowId != null) {
      _accumulatedPausedMs += nowMs - _currentPauseStartMs!;
      await ActivityDatabase.closePause(
        pauseRowId: _currentPauseRowId!,
        pauseEnd: nowMs,
      );
    }
    _currentPauseStartMs = null;
    _currentPauseRowId = null;

    _session = _session!.copyWith(status: ActivityDatabase.statusRecording);
    await ActivityDatabase.updateSessionStatus(
      _session!.id,
      ActivityDatabase.statusRecording,
    );

    // New segment → next accepted point starts a fresh polyline instead of
    // connecting to the pre-pause point.
    _currentSegment++;
    _segments.add(<MapPoint>[]);
    _filter?.beginWarmup();

    _startLocationStream();
    _notify();
  }

  /// Finalize the session. Writes the completed row to SQLite and returns a
  /// summary. The caller (ActivityProvider) then hands the session to
  /// ActivitySyncService for upload.
  Future<CompletedSessionResult?> stop() async {
    if (_session == null) return null;

    // If we were paused, close the open interval.
    if (_currentPauseStartMs != null && _currentPauseRowId != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _accumulatedPausedMs += nowMs - _currentPauseStartMs!;
      await ActivityDatabase.closePause(
        pauseRowId: _currentPauseRowId!,
        pauseEnd: nowMs,
      );
    }

    final durationSec = liveDurationSeconds;
    final endedLocal = DateTime.now();
    final endedAtMs = endedLocal.millisecondsSinceEpoch;

    await ActivityDatabase.completeSession(
      id: _session!.id,
      endedAt: endedAtMs,
      endedAtLocal: _localIso(endedLocal),
      distanceKm: _liveDistanceKm,
      pausedMs: _accumulatedPausedMs,
    );

    final result = CompletedSessionResult(
      localId: _session!.id,
      distanceKm: _liveDistanceKm,
      durationSeconds: durationSec,
      avgPaceMinPerKm: _computePaceMinPerKm(durationSec, _liveDistanceKm),
    );

    await _stopLocationStream();
    _tickTimer?.cancel();
    _tickTimer = null;
    _session = null;
    _filter = null;
    _notify();
    return result;
  }

  /// Abandon the current session without uploading. Deletes the local rows.
  /// Useful if the user explicitly discards a run.
  Future<void> discard() async {
    final id = _session?.id;
    await _stopLocationStream();
    _tickTimer?.cancel();
    _tickTimer = null;
    if (id != null) {
      await ActivityDatabase.deleteSession(id);
    }
    _session = null;
    _filter = null;
    _segments.clear();
    _lastPosition = null;
    _liveDistanceKm = 0;
    _notify();
  }

  void dispose() {
    _locationSub?.cancel();
    _locationSub = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  // ============ LOCATION STREAM ============

  void _startLocationStream() {
    _locationSub?.cancel();
    _locationSub = _locationTracker
        .startTracking(distanceFilter: 5)
        .listen(_onPosition, onError: (e) {
      debugPrint('ActivityRecorder: location stream error: $e');
    });
  }

  Future<void> _stopLocationStream() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await _locationTracker.stopTracking();
  }

  Future<void> _onPosition(Position pos) async {
    if (_session == null || isPaused) return;
    final filter = _filter;
    if (filter == null) return;

    final outcome = filter.evaluate(pos);
    if (!outcome.isAccepted) return;

    _liveDistanceKm += outcome.addedKm;
    _lastPosition = MapPoint(pos.latitude, pos.longitude);
    // Guaranteed non-empty: start() and resume() both push a fresh segment.
    _segments.last.add(_lastPosition!);

    final sessionId = _session!.id;
    final seq = _nextSeq++;

    await ActivityDatabase.insertPoint(
      sessionId: sessionId,
      seq: seq,
      timestamp: pos.timestamp.millisecondsSinceEpoch,
      lat: pos.latitude,
      lon: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      segmentIndex: _currentSegment,
    );
    await ActivityDatabase.updateSessionDistance(sessionId, _liveDistanceKm);
    _notify();
  }

  // ============ TICK ============

  void _startTickTimer() {
    _tickTimer?.cancel();
    // Not a stopwatch — just a UI repaint trigger so the derived duration
    // getter re-renders each second.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session == null || isPaused) return;
      _notify();
    });
  }

  // ============ HELPERS ============

  void _notify() => onStateChanged?.call();

  static double? _computePaceMinPerKm(int durationSec, double distanceKm) {
    if (distanceKm <= 0 || durationSec <= 0) return null;
    return (durationSec / 60.0) / distanceKm;
  }

  static double _maxSpeedForType(String type) {
    switch (type) {
      case 'BIKING':
        return 25; // ~90 km/h ceiling
      case 'WALKING':
        return 4; // ~14 km/h ceiling
      case 'RUNNING':
      default:
        return 10; // ~36 km/h ceiling
    }
  }

  /// Local wall-clock as ISO-8601 with no offset suffix.
  /// Dart's DateTime.now() is local; toIso8601String() omits the offset for
  /// non-UTC instants — exactly the format the backend stores in local_date.
  static String _localIso(DateTime localDt) => localDt.toIso8601String();

  static final _rand = Random();
  static String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final r = _rand.nextInt(0xffffffff).toRadixString(16).padLeft(8, '0');
    return '$ts-$r';
  }
}

class _Session {
  final String id;
  final String activityType;
  final int startedAtMs;
  final String status;

  const _Session({
    required this.id,
    required this.activityType,
    required this.startedAtMs,
    required this.status,
  });

  _Session copyWith({String? status}) => _Session(
        id: id,
        activityType: activityType,
        startedAtMs: startedAtMs,
        status: status ?? this.status,
      );
}
