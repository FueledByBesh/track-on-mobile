import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/activity_history_provider.dart';
import 'package:trackon_mobile/data/providers/activity_provider.dart';
import 'package:trackon_mobile/data/services/location_tracker.dart';
import 'widgets/activity_type_selector.dart';
import 'widgets/run_idle_view.dart';
import 'widgets/run_map_view.dart';
import 'widgets/run_recording_view.dart';
import 'widgets/running_history_sheet.dart';

class RunPage extends StatefulWidget {
  const RunPage({super.key});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> {
  // Shared map controller — same map widget is reused across both views
  final RunMapViewController _mapController = RunMapViewController();
  final LocationTracker _initialLocationTracker = GeolocatorLocationTracker();

  LatLng? _initialPosition;
  bool _loadingInitial = true;
  String? _locationError;
  ActivityType _selectedType = ActivityType.running;

  @override
  void initState() {
    super.initState();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityHistoryProvider>().loadHistory();
    });
  }

  Future<void> _initLocation() async {
    final position = await _initialLocationTracker.getCurrentPosition();
    if (!mounted) return;
    if (position != null) {
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _loadingInitial = false;
      });
    } else {
      setState(() {
        _locationError = 'Could not get location. Check permissions.';
        _loadingInitial = false;
      });
    }
  }

  Future<void> _start() async {
    final provider = context.read<ActivityProvider>();
    await provider.start(_selectedType.value);
  }

  Future<void> _stop() async {
    final provider = context.read<ActivityProvider>();
    final result = await provider.stop();
    if (result != null && mounted) {
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

  void _recenter() {
    final provider = context.read<ActivityProvider>();
    final routePoints = provider.routePoints;
    LatLng? target;
    if (routePoints.isNotEmpty) {
      final last = routePoints.last;
      target = LatLng(last.latitude, last.longitude);
    } else if (_initialPosition != null) {
      target = _initialPosition;
    }
    if (target != null) {
      _mapController.recenterTo(target);
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const RunningHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityProvider = context.watch<ActivityProvider>();
    final isTracking = activityProvider.isTracking;

    final routePoints = activityProvider.routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    LatLng? currentPosition;
    if (routePoints.isNotEmpty) {
      currentPosition = routePoints.last;
    } else {
      currentPosition = _initialPosition;
    }

    return isTracking
          ? RunRecordingView(
              currentPosition: currentPosition,
              routePoints: routePoints,
              mapController: _mapController,
              durationSeconds: activityProvider.liveDuration,
              distanceKm: activityProvider.liveDistance,
              isPaused: activityProvider.isPaused,
              onPause: () => activityProvider.pause(),
              onResume: () => activityProvider.resume(),
              onStop: _stop,
              onMyLocation: _recenter,
            )
          : RunIdleView(
              currentPosition: currentPosition,
              isLoading: _loadingInitial,
              error: _locationError,
              onRetry: () {
                setState(() {
                  _loadingInitial = true;
                  _locationError = null;
                });
                _initLocation();
              },
              mapController: _mapController,
              selectedType: _selectedType,
              onTypeChanged: (type) => setState(() => _selectedType = type),
              onStart: _start,
              onShowHistory: _showHistory,
              onMyLocation: _recenter,
            );
  }
}
