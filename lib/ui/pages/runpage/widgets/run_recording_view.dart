import 'package:flutter/material.dart';
import 'package:trackon_mobile/data/models/map_point.dart';
import 'run_map_view.dart';

/// Recording-state UI.
///
/// Layout:
///   - Full-screen locked-camera map.
///   - Wide action bar pinned to the bottom. When actively recording
///     it's a single "Pause" button at ~75% screen width; when paused
///     it splits into three: Stop (left) / Continue (center) / Cancel
///     (right).
///   - Floating info banner above the action bar. Collapsed it shows
///     distance · time · pace inline with an expand chevron; tapping
///     grows it into a scrollable panel that stops short of the action
///     bar so the controls remain visible and tappable.
class RunRecordingView extends StatefulWidget {
  final MapPoint? currentPosition;
  final List<List<MapPoint>> routeSegments;
  final RunMapViewController mapController;
  final int durationSeconds;
  final double distanceKm;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onCancel;
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
    required this.onCancel,
    required this.onMyLocation,
  });

  @override
  State<RunRecordingView> createState() => _RunRecordingViewState();
}

class _RunRecordingViewState extends State<RunRecordingView> {
  static const double _actionBarHeight = 64;
  static const double _bottomGap = 24;
  static const double _bannerGap = 12;
  static const double _collapsedBannerHeight = 72;
  static const double _contentWidthFraction = 0.82;

  bool _bannerExpanded = false;

  String get _formattedDuration {
    final h = widget.durationSeconds ~/ 3600;
    final m = (widget.durationSeconds % 3600) ~/ 60;
    final s = widget.durationSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  String get _formattedPace {
    if (widget.distanceKm <= 0) return "--'--\"";
    final paceMinPerKm = (widget.durationSeconds / 60) / widget.distanceKm;
    final mins = paceMinPerKm.floor();
    final secs = ((paceMinPerKm - mins) * 60).round();
    return "$mins'${secs.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final topInset = mq.padding.top;
    final bottomInset = mq.padding.bottom;

    final contentWidth = screenWidth * _contentWidthFraction;
    final sideMargin = (screenWidth - contentWidth) / 2;

    // Where the action bar sits.
    final actionBarBottom = bottomInset + _bottomGap;
    // Where the banner sits when collapsed.
    final bannerBottom = actionBarBottom + _actionBarHeight + _bannerGap;
    // Collapsed banner's top edge, so AnimatedPositioned has both
    // top + bottom to interpolate between.
    final collapsedTop =
        screenHeight - bannerBottom - _collapsedBannerHeight;
    // Vertical padding the action bar + its own gap occupy, so
    // scrollable content inside the expanded banner doesn't hide
    // behind the buttons.
    final scrollBottomPadding =
        _actionBarHeight + _bannerGap + _bottomGap + bottomInset + 16;

    return Stack(
      children: [
        // ---------- Full-screen locked map ----------
        Positioned.fill(
          child: RunMapView(
            currentPosition: widget.currentPosition,
            routeSegments: widget.routeSegments,
            controller: widget.mapController,
            cameraMode: CameraMode.locked,
          ),
        ),

        // ---------- Top overlays ----------
        if (widget.isPaused)
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
                mainAxisSize: MainAxisSize.min,
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
        Positioned(
          top: 16 + topInset,
          right: 16,
          child: _RoundButton(
            icon: Icons.my_location,
            onTap: widget.onMyLocation,
          ),
        ),

        // ---------- Info banner (animated expand to full screen) ----------
        // AnimatedPositioned interpolates all four edges between the
        // collapsed card (margins + sitting above the action bar) and
        // the full-screen rect. The action bar is rendered *after*
        // this child so it stays on top of the expanded banner —
        // that's why we can let the banner grow to bottom: 0 without
        // the buttons disappearing.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: _bannerExpanded ? 0 : sideMargin,
          right: _bannerExpanded ? 0 : sideMargin,
          top: _bannerExpanded ? 0 : collapsedTop,
          bottom: _bannerExpanded ? 0 : bannerBottom,
          child: _InfoBanner(
            expanded: _bannerExpanded,
            distanceKm: widget.distanceKm,
            durationStr: _formattedDuration,
            paceStr: _formattedPace,
            isPaused: widget.isPaused,
            scrollBottomPadding: scrollBottomPadding,
            topInset: topInset,
            onToggle: () =>
                setState(() => _bannerExpanded = !_bannerExpanded),
          ),
        ),

        // ---------- Action bar ----------
        Positioned(
          left: sideMargin,
          right: sideMargin,
          bottom: actionBarBottom,
          child: SizedBox(
            height: _actionBarHeight,
            child: widget.isPaused
                ? _PausedActionBar(
                    onStop: widget.onStop,
                    onResume: widget.onResume,
                    onCancel: widget.onCancel,
                  )
                : _PauseActionBar(onPause: widget.onPause),
          ),
        ),
      ],
    );
  }
}

// ============ INFO BANNER ============

class _InfoBanner extends StatelessWidget {
  final bool expanded;
  final double distanceKm;
  final String durationStr;
  final String paceStr;
  final bool isPaused;

  /// Bottom padding inside the expanded ListView — reserves space
  /// for the action bar so the last scroll item isn't hidden
  /// behind the buttons.
  final double scrollBottomPadding;

  /// Status bar inset — pushes the expanded-banner content down so
  /// the collapse button isn't glued to the very top edge of the
  /// screen.
  final double topInset;

  final VoidCallback onToggle;

  const _InfoBanner({
    required this.expanded,
    required this.distanceKm,
    required this.durationStr,
    required this.paceStr,
    required this.isPaused,
    required this.scrollBottomPadding,
    required this.topInset,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    // Numbers fade when paused so the UI reads "not counting."
    final numberColor =
        isPaused ? scheme.onSurfaceVariant : scheme.onSurface;

    // When expanded the banner reaches the screen edges; rounding
    // every corner would leave see-through notches at the bottom
    // where the map peeks through. Round top corners only.
    final borderRadius = expanded
        ? const BorderRadius.vertical(top: Radius.circular(20))
        : BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: expanded
          ? _ExpandedBanner(
              distanceKm: distanceKm,
              durationStr: durationStr,
              paceStr: paceStr,
              numberColor: numberColor,
              scrollBottomPadding: scrollBottomPadding,
              topInset: topInset,
              onCollapse: onToggle,
            )
          : _CollapsedBanner(
              distanceKm: distanceKm,
              durationStr: durationStr,
              paceStr: paceStr,
              numberColor: numberColor,
              onExpand: onToggle,
            ),
    );
  }
}

class _CollapsedBanner extends StatelessWidget {
  final double distanceKm;
  final String durationStr;
  final String paceStr;
  final Color numberColor;
  final VoidCallback onExpand;

  const _CollapsedBanner({
    required this.distanceKm,
    required this.durationStr,
    required this.paceStr,
    required this.numberColor,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 10,
      letterSpacing: 1.1,
      color: scheme.onSurfaceVariant,
    );
    final valueStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: numberColor,
    );

    return InkWell(
      onTap: onExpand,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _CollapsedStat(
                value: '${distanceKm.toStringAsFixed(2)} km',
                label: 'DIST',
                valueStyle: valueStyle,
                labelStyle: labelStyle,
              ),
            ),
            _VerticalDivider(color: scheme.outlineVariant),
            Expanded(
              child: _CollapsedStat(
                value: durationStr,
                label: 'TIME',
                valueStyle: valueStyle,
                labelStyle: labelStyle,
              ),
            ),
            _VerticalDivider(color: scheme.outlineVariant),
            Expanded(
              child: _CollapsedStat(
                value: paceStr,
                label: 'PACE',
                valueStyle: valueStyle,
                labelStyle: labelStyle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.expand_less, color: scheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CollapsedStat extends StatelessWidget {
  final String value;
  final String label;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  const _CollapsedStat({
    required this.value,
    required this.label,
    required this.valueStyle,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: labelStyle),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final Color color;
  const _VerticalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ExpandedBanner extends StatelessWidget {
  final double distanceKm;
  final String durationStr;
  final String paceStr;
  final Color numberColor;
  final double scrollBottomPadding;
  final double topInset;
  final VoidCallback onCollapse;

  const _ExpandedBanner({
    required this.distanceKm,
    required this.durationStr,
    required this.paceStr,
    required this.numberColor,
    required this.scrollBottomPadding,
    required this.topInset,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapse button row — pinned at top, not part of scroll.
        Padding(
          padding: EdgeInsets.fromLTRB(8, topInset + 8, 8, 0),
          child: Row(
            children: [
              const Spacer(),
              IconButton(
                tooltip: 'Collapse',
                onPressed: onCollapse,
                icon: Icon(Icons.expand_more, color: scheme.primary),
              ),
            ],
          ),
        ),
        // Scrollable stats body.
        Expanded(
          child: ListView(
            padding:
                EdgeInsets.fromLTRB(20, 0, 20, scrollBottomPadding),
            children: [
              Text(
                distanceKm.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                  height: 1,
                ),
              ),
              Text(
                'KILOMETERS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(
                      label: 'TIME',
                      value: durationStr,
                      valueColor: numberColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: scheme.outlineVariant,
                  ),
                  Expanded(
                    child: _BigStat(
                      label: 'PACE /KM',
                      value: paceStr,
                      valueColor: numberColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _BigStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ============ ACTION BAR ============

class _PauseActionBar extends StatelessWidget {
  final VoidCallback onPause;
  const _PauseActionBar({required this.onPause});

  @override
  Widget build(BuildContext context) {
    return _WideActionButton(
      icon: Icons.pause,
      label: 'Pause',
      color: Colors.orange,
      onTap: onPause,
    );
  }
}

class _PausedActionBar extends StatelessWidget {
  final VoidCallback onStop;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _PausedActionBar({
    required this.onStop,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _WideActionButton(
            icon: Icons.stop,
            label: 'Stop',
            color: Colors.red,
            onTap: onStop,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _WideActionButton(
            icon: Icons.play_arrow,
            label: 'Continue',
            color: scheme.primary,
            onTap: onResume,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _WideActionButton(
            icon: Icons.close,
            label: 'Cancel',
            color: scheme.onSurfaceVariant,
            onTap: onCancel,
          ),
        ),
      ],
    );
  }
}

class _WideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WideActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(32),
      elevation: 6,
      shadowColor: color.withAlpha(140),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: SizedBox.expand(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ UTILITY ============

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
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
        child: Icon(icon, size: 22, color: scheme.primary),
      ),
    );
  }
}
