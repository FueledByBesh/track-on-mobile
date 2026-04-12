import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/activity_history_provider.dart';

class RunningHistorySheet extends StatelessWidget {
  const RunningHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityHistoryProvider>();
    final history = provider.history;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Running History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: provider.isLoading ? null : () => provider.forceRefresh(),
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

                  IconData icon;
                  switch (run.activityType) {
                    case 'RUNNING':
                      icon = Icons.directions_run;
                      break;
                    case 'BIKING':
                      icon = Icons.directions_bike;
                      break;
                    default:
                      icon = Icons.directions_walk;
                  }

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
                                  Icon(icon, size: 18, color: const Color(0xFF6B5FFF)),
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
