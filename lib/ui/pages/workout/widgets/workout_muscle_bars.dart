import 'package:flutter/material.dart';

import '../../../../data/models/workout.dart';

/// Reusable list of muscle-percentage bars. Renders each muscle as a
/// label + proportional fill bar + percentage. Used in the about-workout
/// page and potentially in training-session overlays.
class WorkoutMuscleBars extends StatelessWidget {
  final List<WorkoutMuscle> muscles;

  const WorkoutMuscleBars({super.key, required this.muscles});

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: muscles.map((m) => _MuscleRow(muscle: m)).toList(),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final WorkoutMuscle muscle;
  const _MuscleRow({required this.muscle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              muscle.name,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          SizedBox(
            width: 140,
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: muscle.percentage / 100.0,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${muscle.percentage}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
