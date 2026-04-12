import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/activity.dart';
import 'activity_service.dart';
import 'location_tracker.dart';

/// Owns the in-progress activity state.
/// Single source of truth for: current activity, route points, live distance,
/// live duration, pause state. Subscribes to a single GPS stream.
class ActivityRecorder {
  final ActivityApiService _api;
  final LocationTracker _locationTracker;

  ActivityRecorder(this._api, this._locationTracker);

  // ============ STATE ============

  Activity? _currentActivity;
  bool _isPaused = false;
  String? _activityType;

  final List<Position> _routePoints = [];
  final List<Position> _backendBuffer = [];

  double _liveDistance = 0; // km, computed locally for instant updates
  int _liveDuration = 0; // seconds

  StreamSubscription<Position>? _locationSub;
  Timer? _durationTimer;
  Timer? _flushTimer;

  /// Notify the wrapping provider that internal state changed.
  VoidCallback? onStateChanged;

  // ============ GETTERS ============

  Activity? get currentActivity => _currentActivity;
  bool get isTracking => _currentActivity != null;
  bool get isPaused => _isPaused;
  double get liveDistance => _liveDistance;
  int get liveDuration => _liveDuration;
  List<Position> get routePoints => List.unmodifiable(_routePoints);
  String? get activityType => _activityType;

  // ============ LIFECYCLE ============

  Future<bool> start(String type) async {
    if (_currentActivity != null) return false;

    try {
      _currentActivity = await _api.startActivity(type);
      _activityType = type;
      _isPaused = false;
      _liveDistance = 0;
      _liveDuration = 0;
      _routePoints.clear();
      _backendBuffer.clear();

      _startLocationStream();
      _startDurationTimer();
      _startFlushTimer();

      _notify();
      return true;
    } catch (e) {
      debugPrint('Error starting activity: $e');
      return false;
    }
  }

  Future<void> pause() async {
    if (_currentActivity == null || _isPaused) return;
    try {
      _currentActivity = await _api.pauseActivity(_currentActivity!.id);
      _isPaused = true;
      _durationTimer?.cancel();
      _notify();
    } catch (e) {
      debugPrint('Error pausing activity: $e');
    }
  }

  Future<void> resume() async {
    if (_currentActivity == null || !_isPaused) return;
    try {
      _currentActivity = await _api.resumeActivity(_currentActivity!.id);
      _isPaused = false;
      _startDurationTimer();
      _notify();
    } catch (e) {
      debugPrint('Error resuming activity: $e');
    }
  }

  Future<Activity?> stop() async {
    if (_currentActivity == null) return null;
    try {
      await _flushBackendBuffer();
      final result = await _api.stopActivity(_currentActivity!.id);
      _cleanup();
      _notify();
      return result;
    } catch (e) {
      debugPrint('Error stopping activity: $e');
      _cleanup();
      _notify();
      return null;
    }
  }

  void _cleanup() {
    _currentActivity = null;
    _activityType = null;
    _isPaused = false;
    _stopLocationStream();
    _durationTimer?.cancel();
    _durationTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  // ============ LOCATION STREAM ============

  void _startLocationStream() {
    _locationSub?.cancel();
    _locationSub = _locationTracker
        .startTracking(distanceFilter: 5)
        .listen(_onLocationUpdate, onError: (e) {
      debugPrint('Location stream error: $e');
    });
  }

  void _stopLocationStream() {
    _locationSub?.cancel();
    _locationSub = null;
    _locationTracker.stopTracking();
  }

  void _onLocationUpdate(Position pos) {
    if (_isPaused || _currentActivity == null) return;

    if (_routePoints.isNotEmpty) {
      final prev = _routePoints.last;
      _liveDistance += _haversine(
        prev.latitude, prev.longitude,
        pos.latitude, pos.longitude,
      );
    }

    _routePoints.add(pos);
    _backendBuffer.add(pos);
    _notify();
  }

  // ============ TIMERS ============

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _liveDuration++;
      _notify();
    });
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _flushBackendBuffer();
    });
  }

  Future<void> _flushBackendBuffer() async {
    if (_backendBuffer.isEmpty || _currentActivity == null) return;
    try {
      final batch = _backendBuffer
          .map((p) => LocationPointData(
                latitude: p.latitude,
                longitude: p.longitude,
                altitude: p.altitude,
              ))
          .toList();
      _backendBuffer.clear();
      await _api.addLocations(_currentActivity!.id, batch);
    } catch (e) {
      debugPrint('Error flushing location buffer: $e');
    }
  }

  // ============ HELPERS ============

  void _notify() => onStateChanged?.call();

  /// Haversine distance in km.
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  void dispose() {
    _cleanup();
  }
}
