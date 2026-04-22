import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/map_point.dart';
import 'package:trackon_mobile/data/providers/activity_history_provider.dart';
import 'package:trackon_mobile/data/providers/activity_provider.dart';
import 'package:trackon_mobile/data/providers/permission_provider.dart';
import 'package:trackon_mobile/data/services/location_tracker.dart';
import 'package:trackon_mobile/data/services/permission_service.dart';
import 'widgets/activity_type_selector.dart';
import 'widgets/run_idle_view.dart';
import 'widgets/run_map_view.dart';
import 'widgets/run_recording_view.dart';
import 'run_history_page.dart';

class RunPage extends StatefulWidget {
  const RunPage({super.key});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> {
  // Shared map controller — same map widget is reused across both views
  final RunMapViewController _mapController = RunMapViewController();
  final LocationTracker _initialLocationTracker = GeolocatorLocationTracker();

  MapPoint? _initialPosition;
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
        _initialPosition = MapPoint(position.latitude, position.longitude);
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
    // Gate the start on actually having location permission. Previously,
    // tapping Start with denied permission silently failed inside the
    // recorder — now we surface the issue with a prompt or a settings
    // escalation so the user can fix it in one tap.
    final permissions = context.read<PermissionProvider>();
    var status = permissions.statusOf(AppPermission.location);

    if (status != AppPermissionStatus.granted) {
      status = await permissions.request(AppPermission.location);
    }
    if (!mounted) return;

    if (status != AppPermissionStatus.granted) {
      _showLocationDeniedSnackBar(status);
      return;
    }

    final provider = context.read<ActivityProvider>();
    await provider.start(_selectedType.value);
  }

  void _showLocationDeniedSnackBar(AppPermissionStatus status) {
    final permissions = context.read<PermissionProvider>();
    final isPermanent = status == AppPermissionStatus.permanentlyDenied;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPermanent
              ? 'Location is blocked. Enable it in Settings to start tracking.'
              : 'Location permission is required to start an activity.',
        ),
        action: isPermanent
            ? SnackBarAction(
                label: 'Open Settings',
                onPressed: () => permissions.openAppSettings(),
              )
            : null,
        duration: const Duration(seconds: 5),
      ),
    );
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
    final target = provider.lastPosition ?? _initialPosition;
    if (target != null) {
      _mapController.recenterTo(target);
    }
  }

  /// Destructive — drops the in-flight recording entirely, no server
  /// upload. Gated behind a confirmation dialog because there's no
  /// undo path and the user could have been running for an hour.
  Future<void> _cancel() async {
    final provider = context.read<ActivityProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this activity?'),
        content: const Text(
          "You'll lose everything you've recorded so far. "
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.discard();
    }
  }

  void _showHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RunHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityProvider = context.watch<ActivityProvider>();
    final isTracking = activityProvider.isTracking;

    final routeSegments = activityProvider.routeSegments;
    final currentPosition = activityProvider.lastPosition ?? _initialPosition;

    return isTracking
          ? RunRecordingView(
              currentPosition: currentPosition,
              routeSegments: routeSegments,
              mapController: _mapController,
              durationSeconds: activityProvider.liveDuration,
              distanceKm: activityProvider.liveDistance,
              isPaused: activityProvider.isPaused,
              onPause: () => activityProvider.pause(),
              onResume: () => activityProvider.resume(),
              onStop: _stop,
              onCancel: _cancel,
              onMyLocation: _recenter,
            )
          : RunIdleView(
              currentPosition: currentPosition,
              isLoading: _loadingInitial,
              error: _locationError,
              onRetry: () async {
                // Retry failures are usually permission-denied — nudge the
                // user through the OS prompt before re-trying the fetch.
                final permissions = context.read<PermissionProvider>();
                if (!permissions.isGranted(AppPermission.location)) {
                  await permissions.request(AppPermission.location);
                }
                if (!mounted) return;
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
