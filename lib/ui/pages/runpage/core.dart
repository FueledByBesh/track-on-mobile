import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/location_service.dart';
import 'package:trackon_mobile/data/providers/activity_provider.dart';

class RunPage extends StatefulWidget {
  const RunPage({super.key});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  LatLng? _currentPosition;
  bool _loadingLocation = true;
  String? _locationError;
  final List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadHistory();
    });
  }

  Future<void> _initLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
    } else {
      setState(() {
        _locationError = 'Could not get location. Check permissions.';
        _loadingLocation = false;
      });
    }
  }

  Future<void> _startRun() async {
    final provider = context.read<ActivityProvider>();
    final activity = await provider.startActivity('RUNNING');
    if (activity != null) {
      _routePoints.clear();
      if (_currentPosition != null) {
        _routePoints.add(_currentPosition!);
      }
      _locationService.startTracking(
        onPosition: (Position pos) {
          final newPos = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _currentPosition = newPos;
            _routePoints.add(newPos);
          });
          _mapController.move(newPos, _mapController.camera.zoom);
        },
        distanceFilter: 5,
      );
    }
  }

  Future<void> _stopRun() async {
    _locationService.stopTracking();
    final provider = context.read<ActivityProvider>();
    final result = await provider.stopActivity();
    if (result != null && mounted) {
      _routePoints.clear();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Run Complete!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Distance: ${result.distanceKm.toStringAsFixed(2)} km'),
              Text('Duration: ${result.formattedDuration}'),
              Text('Avg Pace: ${result.formattedPace} /km'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityProvider = context.watch<ActivityProvider>();
    final isRunning = activityProvider.isTracking;
    final seconds = activityProvider.liveDuration;
    final distance = activityProvider.liveDistance;
    final minutes = seconds ~/ 60;
    final displaySeconds = seconds % 60;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                // Top Info Bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            Text(
                              '${minutes.toString().padLeft(2, '0')}:${displaySeconds.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6B5FFF),
                                  ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Distance',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            Text(
                              '${distance.toStringAsFixed(2)} km',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => const RunningHistorySheet(),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.history),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (isRunning) {
                          _stopRun();
                        } else {
                          _startRun();
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isRunning
                              ? Colors.red
                              : const Color(0xFF6B5FFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isRunning
                                      ? Colors.red
                                      : const Color(0xFF6B5FFF))
                                  .withAlpha(150),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isRunning ? Icons.stop : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_currentPosition != null) {
                          _mapController.move(_currentPosition!, 16.0);
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!isRunning) {
                        _startRun();
                      } else {
                        _stopRun();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning
                          ? Colors.red.shade600
                          : const Color(0xFF6B5FFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isRunning ? 'Finish Run' : 'Start a Run',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_loadingLocation) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B5FFF)),
      );
    }

    if (_locationError != null || _currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _locationError ?? 'Location unavailable',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loadingLocation = true;
                  _locationError = null;
                });
                _initLocation();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition!,
        initialZoom: 16.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.trackon.mobile',
          maxZoom: 20,
        ),
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: const Color(0xFF6B5FFF),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _currentPosition!,
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

class RunningHistorySheet extends StatelessWidget {
  const RunningHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<ActivityProvider>().history;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Running History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No activities yet', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final run = history[index];
                  final dur = run.durationSeconds ?? 0;
                  final mins = dur ~/ 60;
                  final secs = dur % 60;
                  final dateStr = run.startTime.isNotEmpty
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(run.startTime))
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    run.activityType == 'RUNNING'
                                        ? Icons.directions_run
                                        : run.activityType == 'BIKING'
                                            ? Icons.directions_bike
                                            : Icons.directions_walk,
                                    size: 18,
                                    color: const Color(0xFF6B5FFF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dateStr,
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${run.distanceKm.toStringAsFixed(1)} km',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                              if (run.avgPaceMinPerKm != null)
                                Text(
                                  'Pace: ${run.avgPaceMinPerKm!.toStringAsFixed(1)} min/km',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
