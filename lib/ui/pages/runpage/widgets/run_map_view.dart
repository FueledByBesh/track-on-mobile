import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum CameraMode {
  /// User can pan freely. No auto-follow.
  free,

  /// Map auto-follows currentPosition. If user pans manually,
  /// auto-follow pauses for [softLockTimeout] then resumes.
  locked,
}

/// Map-implementation-agnostic controller.
/// When swapping to MapBox, only the implementation inside RunMapView changes.
class RunMapViewController {
  _RunMapViewState? _state;

  void _attach(_RunMapViewState state) => _state = state;
  void _detach() => _state = null;

  /// Force-recenter the map on the given position.
  void recenterTo(LatLng position, {double zoom = 16}) {
    _state?._recenterTo(position, zoom);
  }
}

/// Pure display widget. Render flutter_map now, easy to swap to MapBox.
class RunMapView extends StatefulWidget {
  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final RunMapViewController? controller;
  final CameraMode cameraMode;

  /// Time after a user gesture before auto-follow resumes (in locked mode).
  static const Duration softLockTimeout = Duration(seconds: 5);

  /// Zoom level when auto-following during recording.
  static const double recordingZoom = 17.5;

  /// Default zoom in idle (free) mode.
  static const double idleZoom = 16.0;

  const RunMapView({
    super.key,
    required this.currentPosition,
    required this.routePoints,
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
  final MapController _mapController = MapController();
  bool _hasInitiallyCentered = false;
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

    // Camera mode just switched to locked → recenter immediately and zoom in.
    if (widget.cameraMode == CameraMode.locked &&
        oldWidget.cameraMode != CameraMode.locked &&
        widget.currentPosition != null) {
      _autoFollowSuspended = false;
      _mapController.move(widget.currentPosition!, RunMapView.recordingZoom);
    }

    // Camera mode just switched to free → zoom out.
    if (widget.cameraMode == CameraMode.free &&
        oldWidget.cameraMode != CameraMode.free &&
        widget.currentPosition != null) {
      _mapController.move(widget.currentPosition!, RunMapView.idleZoom);
    }

    // Auto-follow in locked mode
    if (widget.cameraMode == CameraMode.locked &&
        widget.currentPosition != null &&
        widget.currentPosition != oldWidget.currentPosition &&
        !_autoFollowSuspended &&
        _hasInitiallyCentered) {
      _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _resumeFollowTimer?.cancel();
    widget.controller?._detach();
    super.dispose();
  }

  void _recenterTo(LatLng position, double zoom) {
    _autoFollowSuspended = false;
    _resumeFollowTimer?.cancel();
    _mapController.move(position, zoom);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    if (widget.cameraMode != CameraMode.locked) return;

    // User panned during locked mode → suspend auto-follow temporarily.
    _autoFollowSuspended = true;
    _resumeFollowTimer?.cancel();
    _resumeFollowTimer = Timer(RunMapView.softLockTimeout, () {
      if (!mounted) return;
      _autoFollowSuspended = false;
      if (widget.currentPosition != null) {
        _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
      }
    });
  }

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

    if (!_hasInitiallyCentered) {
      _hasInitiallyCentered = true;
    }

    final initialZoom = widget.cameraMode == CameraMode.locked
        ? RunMapView.recordingZoom
        : RunMapView.idleZoom;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.currentPosition!,
        initialZoom: initialZoom,
        onPositionChanged: _onPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.trackon.mobile',
          maxZoom: 20,
        ),
        if (widget.routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                strokeWidth: 4.0,
                color: const Color(0xFF6B5FFF),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.currentPosition!,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF6B5FFF).withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B5FFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B5FFF).withAlpha(100),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
