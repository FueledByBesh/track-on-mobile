import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

class ActivityProvider extends ChangeNotifier {
  final ActivityApiService _service;

  Activity? _currentActivity;
  List<ActivitySummary> _history = [];
  List<LocationPointData> _locationBuffer = [];
  bool _isLoading = false;
  bool _isTracking = false;
  Timer? _locationTimer;

  // Live tracking stats
  double _liveDistance = 0;
  int _liveDuration = 0;
  Timer? _durationTimer;

  ActivityProvider(this._service);

  Activity? get currentActivity => _currentActivity;
  List<ActivitySummary> get history => _history;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;
  double get liveDistance => _liveDistance;
  int get liveDuration => _liveDuration;

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _history = await _service.getAll();
    } catch (e) {
      debugPrint('Error loading activity history: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Activity?> startActivity(String type) async {
    try {
      _currentActivity = await _service.startActivity(type);
      _isTracking = true;
      _liveDistance = 0;
      _liveDuration = 0;
      _locationBuffer.clear();
      _startLocationTracking();
      _startDurationTimer();
      notifyListeners();
      return _currentActivity;
    } catch (e) {
      debugPrint('Error starting activity: $e');
      return null;
    }
  }

  Future<void> pauseActivity() async {
    if (_currentActivity == null) return;
    try {
      _currentActivity = await _service.pauseActivity(_currentActivity!.id);
      _stopLocationTracking();
      _durationTimer?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing activity: $e');
    }
  }

  Future<void> resumeActivity() async {
    if (_currentActivity == null) return;
    try {
      _currentActivity = await _service.resumeActivity(_currentActivity!.id);
      _startLocationTracking();
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming activity: $e');
    }
  }

  Future<Activity?> stopActivity() async {
    if (_currentActivity == null) return null;
    try {
      // Flush any buffered locations
      await _flushLocationBuffer();
      final result = await _service.stopActivity(_currentActivity!.id);
      _currentActivity = null;
      _isTracking = false;
      _stopLocationTracking();
      _durationTimer?.cancel();
      await loadHistory();
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error stopping activity: $e');
      return null;
    }
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    // Solo run: batch every 30 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _captureAndSendLocation();
    });
    // Capture first location immediately
    _captureAndSendLocation();
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _liveDuration++;
      notifyListeners();
    });
  }

  Future<void> _captureAndSendLocation() async {
    if (_currentActivity == null) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final point = LocationPointData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
      );
      _locationBuffer.add(point);

      if (_locationBuffer.length >= 5) {
        await _flushLocationBuffer();
      }
    } catch (e) {
      debugPrint('Error capturing location: $e');
    }
  }

  Future<void> _flushLocationBuffer() async {
    if (_locationBuffer.isEmpty || _currentActivity == null) return;
    try {
      final points = List<LocationPointData>.from(_locationBuffer);
      _locationBuffer.clear();
      _currentActivity = await _service.addLocations(_currentActivity!.id, points);
      _liveDistance = _currentActivity!.distanceKm;
      notifyListeners();
    } catch (e) {
      debugPrint('Error flushing location buffer: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}
