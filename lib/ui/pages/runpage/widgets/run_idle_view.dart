import 'package:flutter/material.dart';
import 'package:trackon_mobile/data/models/map_point.dart';
import 'activity_type_selector.dart';
import 'run_map_view.dart';

/// Idle state UI: free-pan map with floating action buttons.
class RunIdleView extends StatelessWidget {
  final MapPoint? currentPosition;
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
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        RunMapView(
          currentPosition: currentPosition,
          routeSegments: const [],
          isLoading: isLoading,
          error: error,
          onRetry: onRetry,
          controller: mapController,
          cameraMode: CameraMode.free,
        ),
        // Top-right floating buttons (history + my location)
        Positioned(
          top: 16 + topInset,
          right: 16,
          child: Column(
            children: [
              _FloatingIconButton(icon: Icons.history, onTap: onShowHistory),
              const SizedBox(height: 12),
              _FloatingIconButton(icon: Icons.my_location, onTap: onMyLocation),
            ],
          ),
        ),
        // Bottom row: activity type popup + start button
        Positioned(
          left: 16,
          right: 16,
          // Sit just above the bottom nav bar (kBottomNavigationBarHeight = 56)
          bottom: bottomInset + 8,
          child: Row(
            children: [
              _ActivityTypePopupButton(
                selected: selectedType,
                onChanged: onTypeChanged,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StartButton(type: selectedType, onTap: onStart),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============ Activity type popup button ============

class _ActivityTypePopupButton extends StatelessWidget {
  final ActivityType selected;
  final ValueChanged<ActivityType> onChanged;

  const _ActivityTypePopupButton({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<ActivityType>(
        tooltip: 'Activity type',
        position: PopupMenuPosition.over,
        offset: const Offset(0, -160),
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: onChanged,
        itemBuilder: (context) => ActivityType.all.map((type) {
          final isSelected = type.value == selected.value;
          return PopupMenuItem<ActivityType>(
            value: type,
            child: Row(
              children: [
                Icon(
                  type.icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  type.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(selected.icon, color: Theme.of(context).colorScheme.primary, size: 26),
        ),
      ),
    );
  }
}

// ============ Start button ============

class _StartButton extends StatelessWidget {
  final ActivityType type;
  final VoidCallback onTap;

  const _StartButton({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withAlpha(120),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, color: Colors.white, size: 26),
            const SizedBox(width: 6),
            Text(
              'Start ${type.label}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Top-right floating button ============

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
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      ),
    );
  }
}
