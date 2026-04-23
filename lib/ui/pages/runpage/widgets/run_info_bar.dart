import 'package:flutter/material.dart';

/// Top stats card showing duration and distance during a run.
class RunInfoBar extends StatelessWidget {
  final int durationSeconds;
  final double distanceKm;

  const RunInfoBar({
    super.key,
    required this.durationSeconds,
    required this.distanceKm,
  });

  String get _formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Metric(
            label: 'Time',
            value: _formattedDuration,
            color: Theme.of(context).colorScheme.primary,
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          _Metric(
            label: 'Distance',
            value: '${distanceKm.toStringAsFixed(2)} km',
            color: Colors.orange,
            crossAxisAlignment: CrossAxisAlignment.end,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final CrossAxisAlignment crossAxisAlignment;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    required this.crossAxisAlignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}
