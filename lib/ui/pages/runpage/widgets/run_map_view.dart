import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map-implementation-agnostic controller.
/// When swapping to MapBox, only the implementation inside RunMapView changes.
class RunMapViewController {
  _RunMapViewState? _state;

  void _attach(_RunMapViewState state) => _state = state;
  void _detach() => _state = null;

  /// Recenter the map on the given position.
  void recenterTo(LatLng position, {double zoom = 16}) {
    _state?._recenterTo(position, zoom);
  }
}

/// Pure display widget — receives data, renders the map.
/// Currently uses flutter_map. Designed so we can swap to MapBox by
/// rewriting only this widget's internal implementation.
class RunMapView extends StatefulWidget {
  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final RunMapViewController? controller;

  const RunMapView({
    super.key,
    required this.currentPosition,
    required this.routePoints,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.controller,
  });

  @override
  State<RunMapView> createState() => _RunMapViewState();
}

class _RunMapViewState extends State<RunMapView> {
  final MapController _mapController = MapController();
  bool _hasInitiallyCentered = false;

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
    // Auto-follow user position during a run
    if (widget.currentPosition != null &&
        widget.currentPosition != oldWidget.currentPosition &&
        _hasInitiallyCentered) {
      _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  void _recenterTo(LatLng position, double zoom) {
    _mapController.move(position, zoom);
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

    // Center on first build
    if (!_hasInitiallyCentered) {
      _hasInitiallyCentered = true;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.currentPosition!,
        initialZoom: 16.0,
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
