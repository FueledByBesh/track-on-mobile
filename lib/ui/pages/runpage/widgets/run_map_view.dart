import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../data/models/map_point.dart';

enum CameraMode {
  /// User can pan freely. No auto-follow.
  free,

  /// Map auto-follows currentPosition. If user pans manually,
  /// auto-follow pauses for [softLockTimeout] then resumes.
  locked,
}

/// Map-implementation-agnostic controller.
/// To swap maps, only this widget's internals change — the controller API stays.
class RunMapViewController {
  _RunMapViewState? _state;

  void _attach(_RunMapViewState state) => _state = state;
  void _detach() => _state = null;

  /// Force-recenter the map on the given position.
  void recenterTo(MapPoint position, {double zoom = 17}) {
    _state?._recenterTo(position, zoom);
  }
}

/// MapBox-backed map view. The public API uses MapPoint to stay
/// implementation-agnostic. Conversion to MapBox types happens internally.
///
/// Routes are passed in as [routeSegments] — a list of continuous polylines.
/// Each inner list is drawn as one polyline; pause gaps between segments
/// are NOT connected, so the rendered track matches the distance math.
class RunMapView extends StatefulWidget {
  final MapPoint? currentPosition;
  final List<List<MapPoint>> routeSegments;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final RunMapViewController? controller;
  final CameraMode cameraMode;

  /// Time after a user gesture before auto-follow resumes (in locked mode).
  static const Duration softLockTimeout = Duration(seconds: 5);

  /// Zoom level when auto-following during recording.
  static const double recordingZoom = 17.5;

  /// Pitch in locked (recording) mode for a 3D-perspective navigation feel.
  static const double recordingPitch = 50.0;

  /// Default zoom in idle (free) mode.
  static const double idleZoom = 16.0;

  const RunMapView({
    super.key,
    required this.currentPosition,
    required this.routeSegments,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.controller,
    this.cameraMode = CameraMode.free,
  });

  @override
  State<RunMapView> createState() => _RunMapViewState();
}

class _RunMapViewState extends State<RunMapView> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;

  /// One MapBox annotation per segment, parallel to widget.routeSegments.
  /// Frozen segments (pre-pause) are never re-sent to the SDK; only the
  /// currently-growing last segment gets in-place geometry updates.
  final List<PolylineAnnotation> _segmentAnnotations = [];

  /// Last-rendered length per segment. Skips the update call when a segment
  /// hasn't grown since the previous frame.
  final List<int> _renderedLengths = [];

  bool _styleReady = false;
  bool _autoFollowSuspended = false;
  Timer? _resumeFollowTimer;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant RunMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }

    if (!_styleReady) return;

    // Camera mode changed → re-apply
    if (widget.cameraMode != oldWidget.cameraMode) {
      _applyCameraMode();
    }

    // Auto-follow on currentPosition change in locked mode
    if (widget.cameraMode == CameraMode.locked &&
        widget.currentPosition != null &&
        widget.currentPosition != oldWidget.currentPosition &&
        !_autoFollowSuspended) {
      _moveCamera(widget.currentPosition!);
    }

    // Route changed → sync polylines. _syncPolylines is idempotent and
    // skips segments whose length hasn't changed, so calling it on every
    // rebuild is cheap.
    if (!_segmentsEqual(widget.routeSegments, oldWidget.routeSegments)) {
      _syncPolylines();
    }
  }

  @override
  void dispose() {
    _resumeFollowTimer?.cancel();
    widget.controller?._detach();
    super.dispose();
  }

  // ============ MAP LIFECYCLE ============

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Show user location dot (driven by OS GPS)
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: 0xFF6B5FFF,
      ),
    );

    // Hide default UI elements (we have our own)
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(AttributionSettings(
      marginBottom: 100, // push attribution above bottom nav
    ));

    // Polyline manager for the route
    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    setState(() => _styleReady = true);

    // Apply current state
    _applyCameraMode();
    if (widget.routeSegments.any((s) => s.length >= 2)) {
      _syncPolylines();
    }
  }

  void _onCameraChange(CameraChangedEventData data) {
    // We can't easily detect "user gesture" from this callback in v2.
    // Soft-lock is handled via gesture listeners below.
  }

  // ============ CAMERA ============

  void _applyCameraMode() {
    if (_mapboxMap == null || widget.currentPosition == null) return;
    final pos = widget.currentPosition!;
    final isLocked = widget.cameraMode == CameraMode.locked;

    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.lon, pos.lat)),
        zoom: isLocked ? RunMapView.recordingZoom : RunMapView.idleZoom,
        pitch: isLocked ? RunMapView.recordingPitch : 0.0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  void _moveCamera(MapPoint p) {
    if (_mapboxMap == null) return;
    _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(p.lon, p.lat)),
      ),
      MapAnimationOptions(duration: 300),
    );
  }

  void _recenterTo(MapPoint p, double zoom) {
    _autoFollowSuspended = false;
    _resumeFollowTimer?.cancel();
    if (_mapboxMap == null) return;
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(p.lon, p.lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  void _onUserGesture() {
    if (widget.cameraMode != CameraMode.locked) return;
    _autoFollowSuspended = true;
    _resumeFollowTimer?.cancel();
    _resumeFollowTimer = Timer(RunMapView.softLockTimeout, () {
      if (!mounted) return;
      _autoFollowSuspended = false;
      if (widget.currentPosition != null) {
        _moveCamera(widget.currentPosition!);
      }
    });
  }

  // ============ POLYLINE ============

  /// Reconcile the on-map polylines with widget.routeSegments. Per-segment
  /// state is tracked in [_segmentAnnotations] and [_renderedLengths], so:
  ///   - segments whose length hasn't changed since the last render are
  ///     skipped (zero SDK calls)
  ///   - a growing segment is updated in place (one update call, not
  ///     delete+create)
  ///   - new segments (after resume) get their own annotation
  ///   - if the segment count shrinks — e.g. a new session started —
  ///     stale annotations are deleted
  Future<void> _syncPolylines() async {
    final mgr = _polylineManager;
    if (mgr == null) return;
    final segments = widget.routeSegments;

    // 1. Drop trailing annotations we no longer need (new session, discard).
    while (_segmentAnnotations.length > segments.length) {
      final stale = _segmentAnnotations.removeLast();
      _renderedLengths.removeLast();
      await mgr.delete(stale);
    }

    // 2. Update or create for each segment in order.
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.length < 2) continue; // can't draw a line with one point

      if (i < _segmentAnnotations.length) {
        // Existing annotation — update only if it grew.
        if (_renderedLengths[i] == seg.length) continue;
        final coords = seg.map((p) => Position(p.lon, p.lat)).toList();
        _segmentAnnotations[i].geometry = LineString(coordinates: coords);
        await mgr.update(_segmentAnnotations[i]);
        _renderedLengths[i] = seg.length;
      } else {
        // First time we're rendering this segment — create.
        final coords = seg.map((p) => Position(p.lon, p.lat)).toList();
        final ann = await mgr.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: 0xFF6B5FFF,
            lineWidth: 5.0,
          ),
        );
        _segmentAnnotations.add(ann);
        _renderedLengths.add(seg.length);
      }
    }
  }

  // ============ HELPERS ============

  /// Fast "has anything changed?" check for segments. Compares lengths
  /// only — individual point contents are append-only within a segment,
  /// so length equality implies identity for our purposes.
  bool _segmentsEqual(List<List<MapPoint>> a, List<List<MapPoint>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
    }
    return true;
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B5FFF)),
      );
    }

    if (widget.error != null || widget.currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.error ?? 'Location unavailable',
              style: const TextStyle(color: Colors.grey),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    final initial = widget.currentPosition!;
    final isLocked = widget.cameraMode == CameraMode.locked;

    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(initial.lon, initial.lat)),
        zoom: isLocked ? RunMapView.recordingZoom : RunMapView.idleZoom,
        pitch: isLocked ? RunMapView.recordingPitch : 0.0,
      ),
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: _onMapCreated,
      onCameraChangeListener: _onCameraChange,
      onScrollListener: (_) => _onUserGesture(),
      onTapListener: (_) => _onUserGesture(),
    );
  }
}
