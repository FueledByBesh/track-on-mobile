import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'logger_service.dart';

/// Abstraction over location providers.
/// Current implementation: Geolocator (foreground only).
/// Future: ForegroundServiceLocationTracker for background tracking.
abstract class LocationTracker {
  /// Get a one-shot current position. Returns null on permission denial / error.
  Future<Position?> getCurrentPosition();

  /// Start streaming positions. Caller must call [stopTracking] when done.
  /// Filter parameter is the minimum distance (meters) between updates.
  Stream<Position> startTracking({double distanceFilter = 5});

  /// Stop the active stream.
  Future<void> stopTracking();

  /// Whether the tracker has location permission and service enabled.
  Future<bool> isAvailable();
}

class GeolocatorLocationTracker implements LocationTracker {
  StreamSubscription<Position>? _subscription;
  StreamController<Position>? _controller;

  @override
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await _ensurePermission()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Position> startTracking({double distanceFilter = 5}) {
    stopTracking();
    _controller = StreamController<Position>.broadcast();

    _ensurePermission().then((granted) {
      if (!granted) {
        _controller?.addError('Location permission not granted');
        return;
      }
      _subscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter.toInt(),
        ),
      ).listen(
        (pos) {
          final ageMs = DateTime.now().millisecondsSinceEpoch -
              pos.timestamp.millisecondsSinceEpoch;
          Logger.d(
            'GPS',
            'pos acc=${pos.accuracy.toStringAsFixed(1)}m '
                'ts=${pos.timestamp.toIso8601String()} ageMs=$ageMs',
          );
          _controller?.add(pos);
        },
        onError: (e) {
          Logger.w('GPS', 'stream error: $e');
          _controller?.addError(e);
        },
      );
    });

    return _controller!.stream;
  }

  @override
  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
  }

  @override
  Future<bool> isAvailable() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }
}
