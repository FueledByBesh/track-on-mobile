import 'package:flutter/material.dart';

class ActivityType {
  final String value;
  final String label;
  final IconData icon;

  const ActivityType(this.value, this.label, this.icon);

  static const running = ActivityType('RUNNING', 'Run', Icons.directions_run);
  static const biking = ActivityType('BIKING', 'Bike', Icons.directions_bike);
  static const walking = ActivityType('WALKING', 'Walk', Icons.directions_walk);

  static const all = [running, biking, walking];
}

/// Segmented control for picking activity type.
/// Shown only when not currently tracking.
class ActivityTypeSelector extends StatelessWidget {
  final ActivityType selected;
  final ValueChanged<ActivityType> onChanged;

  const ActivityTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ActivityType.all.map((type) {
          final isSelected = type.value == selected.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type.icon,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
