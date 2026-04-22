import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:trackon_mobile/data/models/activity.dart';
import 'package:trackon_mobile/data/providers/activity_history_provider.dart';
import 'package:trackon_mobile/ui/sharedwidgets/route_preview.dart';

import 'run_detail_page.dart';

/// Full-screen activity history.
///
/// Backed by [ActivityHistoryProvider] — which already does the
/// 5-min throttle + refresh-after-stop dance, so all this page has
/// to do is watch + render. Pull-to-refresh skips the throttle.
///
/// Card layout: a map-preview rectangle on top (mocked for now —
/// will become a real snapshot of the route once we wire it) with
/// the activity's stats stacked beneath. Tapping any card opens
/// [RunDetailPage] for that activity.
class RunHistoryPage extends StatefulWidget {
  const RunHistoryPage({super.key});

  @override
  State<RunHistoryPage> createState() => _RunHistoryPageState();
}

class _RunHistoryPageState extends State<RunHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityHistoryProvider>().loadHistory();
    });
  }

  Future<void> _refresh() {
    return context.read<ActivityHistoryProvider>().forceRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityHistoryProvider>();
    final history = provider.history;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isLoading ? null : _refresh,
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.isLoading && history.isEmpty
            ? _LoadingList(scheme: scheme)
            : history.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) => _HistoryCard(
                      activity: history[index],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RunDetailPage(
                            activityId: history[index].id,
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

// ============ CARD ============

class _HistoryCard extends StatelessWidget {
  final ActivitySummary activity;
  final VoidCallback onTap;

  const _HistoryCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final (icon, label) = _typeFor(activity.activityType);
    final dateStr = _relativeDate(activity.startTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SizedBox(
            height: 124,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: square-ish route preview clipped to the card's
                // left corners.
                SizedBox(
                  width: 124,
                  child: RoutePreview(
                    encodedPolyline: activity.previewPolyline,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                // Right: stats stack.
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '·',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${activity.distanceKm.toStringAsFixed(2)} km',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _StatChip(
                              icon: Icons.timer_outlined,
                              label: activity.formattedDuration,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: _StatChip(
                                icon: Icons.speed,
                                label: '${activity.formattedPace}/km',
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
        ),
      ),
    );
  }

  static (IconData, String) _typeFor(String type) {
    switch (type) {
      case 'RUNNING':
        return (Icons.directions_run, 'Run');
      case 'BIKING':
        return (Icons.directions_bike, 'Bike');
      case 'WALKING':
        return (Icons.directions_walk, 'Walk');
      default:
        return (Icons.directions_walk, _prettyCase(type));
    }
  }

  static String _prettyCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  /// "Today 08:14" / "Yesterday 19:02" / "Apr 19, 08:14" for older.
  static String _relativeDate(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;
    final timeStr = DateFormat('HH:mm').format(local);
    if (diff == 0) return 'Today $timeStr';
    if (diff == 1) return 'Yesterday $timeStr';
    if (local.year == now.year) {
      return '${DateFormat('MMM d').format(local)}, $timeStr';
    }
    return '${DateFormat('MMM d, yyyy').format(local)}, $timeStr';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============ STATES ============

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_run,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'No activities yet',
                  style: TextStyle(color: scheme.onSurface, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start a run and it will show up here.',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingList extends StatelessWidget {
  final ColorScheme scheme;
  const _LoadingList({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
