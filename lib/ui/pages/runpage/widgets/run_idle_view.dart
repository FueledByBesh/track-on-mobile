import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'activity_type_selector.dart';
import 'run_map_view.dart';

/// Idle state UI: free-pan map, type selector, start button.
class RunIdleView extends StatelessWidget {
  final LatLng? currentPosition;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final RunMapViewController mapController;
  final ActivityType selectedType;
  final ValueChanged<ActivityType> onTypeChanged;
  final VoidCallback onStart;
  final VoidCallback onShowHistory;
  final VoidCallback onMyLocation;

  const RunIdleView({
    super.key,
    required this.currentPosition,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.mapController,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onStart,
    required this.onShowHistory,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              RunMapView(
                currentPosition: currentPosition,
                routePoints: const [],
                isLoading: isLoading,
                error: error,
                onRetry: onRetry,
                controller: mapController,
                cameraMode: CameraMode.free,
              ),
              // Floating action buttons (top right)
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    _FloatingIconButton(
                      icon: Icons.history,
                      onTap: onShowHistory,
                    ),
                    const SizedBox(height: 12),
                    _FloatingIconButton(
                      icon: Icons.my_location,
                      onTap: onMyLocation,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Bottom panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              ActivityTypeSelector(
                selected: selectedType,
                onChanged: onTypeChanged,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B5FFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selectedType.icon, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Start ${selectedType.label}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(icon, color: const Color(0xFF6B5FFF), size: 22),
      ),
    );
  }
}
