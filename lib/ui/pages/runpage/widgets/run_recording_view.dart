import 'package:flutter/material.dart';
import 'package:trackon_mobile/data/models/map_point.dart';
import 'run_map_view.dart';

/// Recording state UI: locked-camera map, big stats overlay, pause/stop controls.
class RunRecordingView extends StatelessWidget {
  final MapPoint? currentPosition;
  final List<List<MapPoint>> routeSegments;
  final RunMapViewController mapController;
  final int durationSeconds;
  final double distanceKm;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onMyLocation;

  const RunRecordingView({
    super.key,
    required this.currentPosition,
    required this.routeSegments,
    required this.mapController,
    required this.durationSeconds,
    required this.distanceKm,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onMyLocation,
  });

  String get _formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _formattedPace {
    if (distanceKm <= 0) return "--'--\"";
    final paceMinPerKm = (durationSeconds / 60) / distanceKm;
    final mins = paceMinPerKm.floor();
    final secs = ((paceMinPerKm - mins) * 60).round();
    return "$mins'${secs.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final pausedColor = Colors.grey.shade400;
    final activeColor = Colors.white;
    final textColor = isPaused ? pausedColor : activeColor;
    final topInset = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              RunMapView(
                currentPosition: currentPosition,
                routeSegments: routeSegments,
                controller: mapController,
                cameraMode: CameraMode.locked,
              ),
              // My location button (top right, below status bar)
              Positioned(
                top: 16 + topInset,
                right: 16,
                child: GestureDetector(
                  onTap: onMyLocation,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location, color: Color(0xFF6B5FFF), size: 22),
                  ),
                ),
              ),
              // Paused indicator
              if (isPaused)
                Positioned(
                  top: 16 + topInset,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.pause, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Paused',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Big stats overlay — SafeArea(top: false) gives bottom inset for home indicator
        SafeArea(
          top: false,
          child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2A3A),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Distance — biggest
              Column(
                children: [
                  Text(
                    distanceKm.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    'KILOMETERS',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Duration + Pace
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatColumn(label: 'TIME', value: _formattedDuration, color: textColor),
                  Container(width: 1, height: 40, color: Colors.grey.shade800),
                  _StatColumn(label: 'PACE /KM', value: _formattedPace, color: textColor),
                ],
              ),
              const SizedBox(height: 24),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BigCircleButton(
                    icon: Icons.stop,
                    color: Colors.red,
                    size: 64,
                    onTap: onStop,
                  ),
                  _BigCircleButton(
                    icon: isPaused ? Icons.play_arrow : Icons.pause,
                    color: isPaused ? Colors.green : Colors.orange,
                    size: 80,
                    onTap: isPaused ? onResume : onPause,
                  ),
                  const SizedBox(width: 64), // spacer to balance the row
                ],
              ),
            ],
          ),
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

class _BigCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _BigCircleButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(120),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
