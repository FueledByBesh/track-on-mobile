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
    // Detach any prior resources into locals BEFORE reassigning instance
    // fields. If we let the old stopTracking work on `_subscription` /
    // `_controller` directly, its awaits yield microtasks that resume
    // *after* we've already stored the NEW controller — and the await-on-
    // close ends up closing the controller we just created. Classic
    // async self-interference bug.
    final prevSub = _subscription;
    final prevCtrl = _controller;
    _subscription = null;
    _controller = null;
    if (prevSub != null || prevCtrl != null) {
      // Fire-and-forget: cleans up old resources without touching fields.
      _disposeOld(prevSub, prevCtrl);
    }

    // Regular (non-broadcast) controller — single subscriber (the
    // ActivityRecorder), and buffering is desirable if the listener
    // hasn't attached by the time the first position arrives.
    final controller = StreamController<Position>();
    _controller = controller;

    _ensurePermission().then((granted) {
      if (!granted) {
        controller.addError('Location permission not granted');
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
          // Close over the LOCAL controller, not the field — even if
          // _controller gets reassigned later, this callback still adds
          // to the controller it was created for.
          if (!controller.isClosed) {
            controller.add(pos);
          }
        },
        onError: (e) {
          Logger.w('GPS', 'stream error: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
        },
      );
    });

    return controller.stream;
  }

  @override
  Future<void> stopTracking() async {
    // Same detach-then-cleanup pattern as startTracking: capture the
    // current references into locals, clear the fields, then do the
    // async cleanup on the locals so a concurrent startTracking can't
    // see half-cleaned state.
    final sub = _subscription;
    final ctrl = _controller;
    _subscription = null;
    _controller = null;
    await _disposeOld(sub, ctrl);
  }

  Future<void> _disposeOld(
    StreamSubscription<Position>? sub,
    StreamController<Position>? ctrl,
  ) async {
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await ctrl?.close();
    } catch (_) {}
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
