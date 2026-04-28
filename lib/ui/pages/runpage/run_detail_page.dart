import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:trackon_mobile/data/models/activity.dart';
import 'package:trackon_mobile/data/models/map_point.dart';
import 'package:trackon_mobile/data/services/activity_service.dart';

import 'widgets/run_map_view.dart';

/// Full activity detail. Fetches the activity by id from the backend,
/// then renders:
///   1. A map with the recorded route drawn as a polyline.
///   2. A stats header (distance / duration / pace / type / start).
///   3. Per-km splits (table of times + paces).
///   4. A pace-per-km chart.
///   5. An elevation-over-distance chart, hidden if the route carries
///      no altitudes.
///   6. An overflow menu with Delete — wired but currently a no-op.
class RunDetailPage extends StatefulWidget {
  /// Server-side activity id.
  final String activityId;

  const RunDetailPage({super.key, required this.activityId});

  @override
  State<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<RunDetailPage> {
  final RunMapViewController _mapController = RunMapViewController();
  Activity? _activity;
  bool _loading = true;
  String? _error;

  // ---- Derived values, computed ONCE per activity fetch. ----
  // The detail sheet's draggable behavior triggers many rebuilds per
  // second, so we must not recompute polylines / splits / elevation
  // inside the widget tree — walking hundreds of route points on every
  // frame drops frames visibly. Everything expensive that's a pure
  // function of `_activity.route` lives here.
  List<List<MapPoint>> _segments = const [];
  MapPoint? _mapCenter;
  List<_Split> _splits = const [];
  bool _hasAltitude = false;
  List<FlSpot> _elevationSpots = const [];
  bool _hasSpeed = false;
  List<FlSpot> _speedSpots = const [];
  /// Cumulative km positions where the user paused. Used to draw
  /// vertical markers on the elevation + speed charts.
  List<double> _pauseKms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ActivityApiService>();
      final act = await api.getById(widget.activityId);
      if (!mounted) return;
      setState(() {
        _activity = act;
        _segments = _Body._segmentsFrom(act.route);
        _mapCenter = _Body._centerOf(act.route);
        _splits = _Body._splitsFrom(act.route);
        _hasAltitude = act.route.any((p) => p.altitude != null);
        _elevationSpots = _hasAltitude
            ? _ElevationChart._buildElevationSpots(act.route)
            : const [];
        _hasSpeed = act.route.any((p) => p.speed != null && p.speed! > 0);
        _speedSpots = _hasSpeed
            ? _SpeedChart._buildSpeedSpots(act.route)
            : const [];
        _pauseKms = _Body._pauseKmsFrom(act.route);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load activity';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActivity = !_loading && _activity != null && _error == null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapLayer()),
          _FloatingTopBar(onMenu: _onMenu),
          if (hasActivity)
            _DetailSheet(
              activity: _activity!,
              splits: _splits,
              hasAltitude: _hasAltitude,
              elevationSpots: _elevationSpots,
              hasSpeed: _hasSpeed,
              speedSpots: _speedSpots,
              pauseKms: _pauseKms,
              onRecenter: _mapController.fitToRoute,
            ),
        ],
      ),
    );
  }

  Widget _buildMapLayer() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _activity == null) {
      return _ErrorState(onRetry: _load, message: _error);
    }

    // Extra bottom padding keeps the auto-fit from tucking the route
    // under the bottom sheet at its initial height.
    final sheetInitialHeight =
        MediaQuery.of(context).size.height * _DetailSheet.initialExtent;

    return RunMapView(
      currentPosition: _mapCenter,
      routeSegments: _segments,
      controller: _mapController,
      cameraMode: CameraMode.free,
      fitToBoundsOnLoad: true,
      showUserLocation: false,
      fitBoundsPadding: EdgeInsets.fromLTRB(
        40,
        80,
        40,
        sheetInitialHeight + 24,
      ),
    );
  }

  void _onMenu(String value) {
    if (value == 'delete') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting activities is coming soon'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ============ FLOATING TOP BAR ============

/// Drawn above the map. Circle-backed back + overflow buttons that
/// stay readable regardless of what tile is under them.
class _FloatingTopBar extends StatelessWidget {
  final void Function(String value) onMenu;
  const _FloatingTopBar({required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: [
            _CircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            _CircleMenuButton(onSelected: onMenu),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: scheme.onSurface),
      ),
    );
  }
}

/// Circle button that re-fits the camera to the activity's route.
/// Visually matches the top-bar buttons so the page feels consistent.
class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Recenter on route',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.center_focus_strong,
            size: 22,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _CircleMenuButton extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _CircleMenuButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz, size: 20, color: scheme.onSurface),
        padding: EdgeInsets.zero,
        onSelected: onSelected,
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red, size: 18),
                SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ DRAGGABLE DETAIL SHEET ============

/// Expandable card on top of the map. Starts at ~35% of the screen
/// (enough to peek distance + one chip row), drags down to a handle
/// strip, up to 92% for the full stats + charts + splits view. The
/// inner scrollable uses the sheet's controller so dragging at the
/// top of the list either scrolls or resizes the sheet as expected.
class _DetailSheet extends StatelessWidget {
  static const double initialExtent = 0.35;
  static const double minExtent = 0.12;
  static const double maxExtent = 0.92;

  final Activity activity;
  final List<_Split> splits;
  final bool hasAltitude;
  final List<FlSpot> elevationSpots;
  final bool hasSpeed;
  final List<FlSpot> speedSpots;
  final List<double> pauseKms;
  final VoidCallback onRecenter;

  const _DetailSheet({
    required this.activity,
    required this.splits,
    required this.hasAltitude,
    required this.elevationSpots,
    required this.hasSpeed,
    required this.speedSpots,
    required this.pauseKms,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: initialExtent,
      minChildSize: minExtent,
      maxChildSize: maxExtent,
      snap: true,
      snapSizes: const [minExtent, initialExtent, maxExtent],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _SheetHeader(handleColor: scheme.outlineVariant),
            _StatsHeader(activity: activity, onRecenter: onRecenter),
            const SizedBox(height: 16),
            if (splits.isNotEmpty) ...[
              _Section(
                title: 'Pace',
                child: _PaceChart(splits: splits),
              ),
              const SizedBox(height: 12),
            ],
            if (hasSpeed) ...[
              _Section(
                title: 'Speed',
                child:
                    _SpeedChart(spots: speedSpots, pauseKms: pauseKms),
              ),
              const SizedBox(height: 12),
            ],
            if (hasAltitude) ...[
              _Section(
                title: 'Elevation',
                child: _ElevationChart(
                    spots: elevationSpots, pauseKms: pauseKms),
              ),
              const SizedBox(height: 12),
            ],
            if (splits.isNotEmpty)
              _Section(
                title: 'Splits',
                child: _SplitsTable(splits: splits),
              ),
          ],
        ),
      ),
    );
  }
}

/// Drag handle + recenter-on-route action packed into one row.
/// The handle sits at the center (SheetHandle affordance) while the
/// button is nudged to the right edge so it doesn't fight the drag
/// gesture. Using a Stack lets the handle stay visually centered
/// regardless of the button's width.
class _SheetHeader extends StatelessWidget {
  final Color handleColor;

  const _SheetHeader({required this.handleColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ============ ROUTE HELPERS ============

/// Used by both the map-layer projector and the detail sheet.
class _Body {
  /// Group route points into contiguous segments — a pause breaks the
  /// segment so the polyline is never drawn across the gap.
  static List<List<MapPoint>> _segmentsFrom(List<RoutePoint> route) {
    if (route.isEmpty) return const [];
    final List<List<MapPoint>> out = [];
    List<MapPoint> current = [];
    int segIndex = route.first.segmentIndex;
    for (final p in route) {
      if (p.segmentIndex != segIndex) {
        if (current.length >= 2) out.add(current);
        current = [];
        segIndex = p.segmentIndex;
      }
      current.add(MapPoint(p.lat, p.lon));
    }
    if (current.length >= 2) out.add(current);
    return out;
  }

  /// Rough centroid — plenty for an initial map-camera target. The
  /// real fit-to-bounds is a follow-up once the map view exposes it.
  static MapPoint? _centerOf(List<RoutePoint> route) {
    if (route.isEmpty) return null;
    double lat = 0, lon = 0;
    for (final p in route) {
      lat += p.lat;
      lon += p.lon;
    }
    return MapPoint(lat / route.length, lon / route.length);
  }

  /// Walk the route and record the cumulative km position at every
  /// pause boundary (where segmentIndex transitions). Used to draw
  /// vertical markers on the elevation + speed charts so users see
  /// where they stopped during the run.
  static List<double> _pauseKmsFrom(List<RoutePoint> route) {
    if (route.length < 2) return const [];
    final List<double> out = [];
    double cumKm = 0;
    int segIndex = route.first.segmentIndex;
    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];
      if (curr.segmentIndex != prev.segmentIndex) {
        // segmentIndex change marks the pause; record the position
        // (cumulative distance is unchanged across the pause).
        out.add(cumKm);
        segIndex = curr.segmentIndex;
        continue;
      }
      cumKm += Geolocator.distanceBetween(
            prev.lat, prev.lon, curr.lat, curr.lon,
          ) / 1000;
    }
    // Suppress unused-but-needed segIndex warning if compiler nags.
    assert(segIndex >= 0);
    return out;
  }

  /// Walks the route and records per-km splits: at every km boundary,
  /// emit the time spent + pace for that km. Pause gaps (segment
  /// boundary) are skipped so the split time reflects moving time.
  static List<_Split> _splitsFrom(List<RoutePoint> route) {
    if (route.length < 2) return const [];
    final List<_Split> splits = [];
    double cumMeters = 0;
    int kmIndex = 1;
    int kmStartMs = route.first.timestampMs;

    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];
      if (curr.segmentIndex != prev.segmentIndex) {
        // Pause — reset the km-start clock to the resumed point so
        // split durations only count moving time.
        kmStartMs += curr.timestampMs - prev.timestampMs;
        continue;
      }
      cumMeters += Geolocator.distanceBetween(
        prev.lat,
        prev.lon,
        curr.lat,
        curr.lon,
      );
      if (cumMeters >= kmIndex * 1000) {
        final durationMs = curr.timestampMs - kmStartMs;
        final paceMinPerKm = (durationMs / 1000) / 60;
        splits.add(
          _Split(
            km: kmIndex,
            duration: Duration(milliseconds: durationMs),
            paceMinPerKm: paceMinPerKm,
          ),
        );
        kmStartMs = curr.timestampMs;
        kmIndex++;
      }
    }
    return splits;
  }
}

class _Split {
  final int km;
  final Duration duration;
  final double paceMinPerKm;

  const _Split({
    required this.km,
    required this.duration,
    required this.paceMinPerKm,
  });
}

// ============ STATS HEADER ============

class _StatsHeader extends StatelessWidget {
  final Activity activity;
  final VoidCallback onRecenter;
  const _StatsHeader({required this.activity, required this.onRecenter});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = _typeFor(activity.activityType);
    final dateStr = _formatStart(activity.startTime);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: _RecenterButton(onTap: onRecenter),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('·', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${activity.distanceKm.toStringAsFixed(2)} km',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: 'Duration',
                      value: _formatDuration(activity.durationSeconds ?? 0),
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      label: 'Avg pace',
                      value: activity.avgPaceMinPerKm == null
                          ? '--'
                          : '${_formatPace(activity.avgPaceMinPerKm!)} /km',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
        return (Icons.directions_walk, type);
    }
  }

  static String _formatStart(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return DateFormat('MMM d, yyyy · HH:mm').format(dt);
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ============ PACE CHART ============

class _PaceChart extends StatelessWidget {
  final List<_Split> splits;

  const _PaceChart({required this.splits});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paces = splits.map((s) => s.paceMinPerKm).toList();
    // Invert Y: pace axis where *lower number* is faster. Chart shows
    // the mountain pointing down → fast kms dip low on screen.
    final minPace = paces.reduce((a, b) => a < b ? a : b);
    final maxPace = paces.reduce((a, b) => a > b ? a : b);
    final padding = (maxPace - minPace) * 0.2;
    final yMin = (minPace - padding).clamp(0, double.infinity).toDouble();
    final yMax = maxPace + padding;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: splits.length.toDouble(),
          minY: yMin,
          maxY: yMax,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final s in splits) FlSpot(s.km.toDouble(), s.paceMinPerKm),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              color: scheme.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: scheme.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withAlpha(30),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withAlpha(80),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (splits.length / 5).ceilToDouble().clamp(1, 9999),
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${value.toInt()}km',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  _formatPace(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ============ ELEVATION CHART ============

class _ElevationChart extends StatelessWidget {
  /// Precomputed at activity-fetch time by [_buildElevationSpots] —
  /// the chart itself does no route walking, so its build is cheap
  /// enough to run on every sheet-drag frame.
  final List<FlSpot> spots;
  final List<double> pauseKms;

  const _ElevationChart({required this.spots, this.pauseKms = const []});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // X = distance (km), Y = altitude (m). Spots were downsampled
    // to ~80 points upstream so long runs don't blow up chart perf.
    if (spots.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No elevation data',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }
    final altitudes = spots.map((s) => s.y).toList();
    final minY = altitudes.reduce((a, b) => a < b ? a : b);
    final maxY = altitudes.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.15).clamp(2.0, double.infinity);
    final xRange = (spots.last.x - spots.first.x).abs();
    final xInterval =
        (xRange / 4).ceilToDouble().clamp(1.0, double.infinity);

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: minY - padding,
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: scheme.tertiary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.tertiary.withAlpha(40),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withAlpha(80),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: xInterval,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${value.toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) => Text(
                  '${value.toInt()}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              for (final km in pauseKms)
                VerticalLine(
                  x: km,
                  color: scheme.onSurfaceVariant.withAlpha(120),
                  strokeWidth: 1.2,
                  dashArray: const [4, 4],
                ),
            ],
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  static List<FlSpot> _buildElevationSpots(List<RoutePoint> route) {
    if (route.length < 2) return const [];

    // Anchor: the first point with a non-null altitude is treated as
    // 0m. The chart then shows climb/descent relative to the start —
    // 700m absolute readings stop dominating the Y axis on flat runs.
    double? baseline;
    for (final p in route) {
      if (p.altitude != null) {
        baseline = p.altitude;
        break;
      }
    }
    if (baseline == null) return const [];

    final List<FlSpot> raw = [];
    double cumKm = 0;
    for (int i = 0; i < route.length; i++) {
      if (i > 0) {
        final prev = route[i - 1];
        final curr = route[i];
        if (curr.segmentIndex == prev.segmentIndex) {
          cumKm +=
              Geolocator.distanceBetween(
                prev.lat,
                prev.lon,
                curr.lat,
                curr.lon,
              ) /
              1000;
        }
      }
      final alt = route[i].altitude;
      if (alt != null) raw.add(FlSpot(cumKm, alt - baseline));
    }
    if (raw.length <= 80) return raw;
    // Downsample by picking every Nth sample.
    final step = (raw.length / 80).ceil();
    return [for (int i = 0; i < raw.length; i += step) raw[i]];
  }
}

// ============ SPEED CHART ============

/// Speed (km/h) over distance. Mirrors [_ElevationChart] in shape:
/// raw `RoutePoint.speed` values (m/s, GPS-reported) are converted to
/// km/h, plotted against cumulative distance, then downsampled to keep
/// long routes from blowing up the chart.
class _SpeedChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<double> pauseKms;

  const _SpeedChart({required this.spots, this.pauseKms = const []});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (spots.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No speed data',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    final speeds = spots.map((s) => s.y).toList();
    final minY = speeds.reduce((a, b) => a < b ? a : b);
    final maxY = speeds.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.15).clamp(1.0, double.infinity);

    // Cap to ~5 ticks across the X axis so labels don't collide on
    // long routes. ceil so distance-units feel "round".
    final xRange = (spots.last.x - spots.first.x).abs();
    final xInterval =
        (xRange / 4).ceilToDouble().clamp(1.0, double.infinity);

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: (minY - padding).clamp(0, double.infinity).toDouble(),
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: scheme.secondary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.secondary.withAlpha(40),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withAlpha(80),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: xInterval,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${value.toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  '${value.toStringAsFixed(0)} km/h',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              for (final km in pauseKms)
                VerticalLine(
                  x: km,
                  color: scheme.onSurfaceVariant.withAlpha(120),
                  strokeWidth: 1.2,
                  dashArray: const [4, 4],
                ),
            ],
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  /// Walk the route, accumulate distance, and emit (km, speed_kmh)
  /// for every point that has a positive speed reading. Pause gaps
  /// (segmentIndex change) don't add to distance. Downsamples to ~80
  /// points so long routes stay snappy.
  static List<FlSpot> _buildSpeedSpots(List<RoutePoint> route) {
    if (route.length < 2) return const [];
    final List<FlSpot> raw = [];
    double cumKm = 0;
    for (int i = 0; i < route.length; i++) {
      if (i > 0) {
        final prev = route[i - 1];
        final curr = route[i];
        if (curr.segmentIndex == prev.segmentIndex) {
          cumKm += Geolocator.distanceBetween(
                prev.lat,
                prev.lon,
                curr.lat,
                curr.lon,
              ) /
              1000;
        }
      }
      final s = route[i].speed;
      if (s != null && s >= 0) {
        // m/s → km/h
        raw.add(FlSpot(cumKm, s * 3.6));
      }
    }
    if (raw.length <= 80) return raw;
    final step = (raw.length / 80).ceil();
    return [for (int i = 0; i < raw.length; i += step) raw[i]];
  }
}

// ============ SPLITS TABLE ============

class _SplitsTable extends StatelessWidget {
  final List<_Split> splits;
  const _SplitsTable({required this.splits});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final s in splits)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${s.km}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    _formatDuration(s.duration.inSeconds),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_formatPace(s.paceMinPerKm)} /km',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
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

// ============ COMMON ============

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message ?? 'Something went wrong'),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ============ FORMATTERS ============

String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

String _formatPace(double minPerKm) {
  if (minPerKm.isNaN || minPerKm.isInfinite) return '--';
  final m = minPerKm.floor();
  final s = ((minPerKm - m) * 60).round();
  return "$m'${s.toString().padLeft(2, '0')}\"";
}
