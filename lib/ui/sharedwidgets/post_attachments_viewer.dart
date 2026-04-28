import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/activity.dart';
import '../../data/models/map_point.dart';
import '../../data/models/post.dart';
import '../../data/providers/activity_history_provider.dart';
import '../../data/services/activity_service.dart';
import 'route_preview.dart';

/// Horizontal carousel for a post's attachments. Shows one item at a
/// time with left/right swipe. A dot-indicator below tracks position.
/// Hidden entirely when [attachments] is empty.
///
/// IMAGE  → full-width image with rounded corners.
/// ACTIVITY / CHALLENGE_PROGRESS → compact activity card (tap navigates
///   to detail if [onActivityTap] is provided).
class PostAttachmentsViewer extends StatefulWidget {
  final List<PostAttachment> attachments;
  final void Function(String activityId)? onActivityTap;

  /// Tap handler for image attachments. Receives the tapped
  /// attachment's id; the caller decides what to do (e.g. open a
  /// full-screen gallery). When null, image slots are not tappable.
  final void Function(String attachmentId)? onImageTap;

  /// When true, activity slots show a floating "Open in full map" button
  /// over the route preview. Used in [PostDetailPage]; the feed cards
  /// keep this off and the whole slot is tappable instead.
  final bool showMapButton;

  const PostAttachmentsViewer({
    super.key,
    required this.attachments,
    this.onActivityTap,
    this.onImageTap,
    this.showMapButton = false,
  });

  @override
  State<PostAttachmentsViewer> createState() => _PostAttachmentsViewerState();
}

class _PostAttachmentsViewerState extends State<PostAttachmentsViewer> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.attachments;
    if (items.isEmpty) return const SizedBox.shrink();

    final single = items.length == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _ctrl,
            physics: single
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _AttachmentSlot(
              attachment: items[i],
              onActivityTap: widget.onActivityTap,
              onImageTap: widget.onImageTap,
              showMapButton: widget.showMapButton,
            ),
          ),
        ),
        if (!single) ...[
          const SizedBox(height: 8),
          _DotIndicator(count: items.length, active: _page),
        ],
      ],
    );
  }
}

class _AttachmentSlot extends StatelessWidget {
  final PostAttachment attachment;
  final void Function(String activityId)? onActivityTap;
  final void Function(String attachmentId)? onImageTap;
  final bool showMapButton;

  const _AttachmentSlot({
    required this.attachment,
    this.onActivityTap,
    this.onImageTap,
    this.showMapButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: switch (attachment.kind) {
        PostAttachmentKind.image =>
          _ImageSlot(attachment: attachment, onTap: onImageTap),
        PostAttachmentKind.activity ||
        PostAttachmentKind.challengeProgress =>
          _ActivitySlot(
            attachment: attachment,
            onTap: onActivityTap,
            showMapButton: showMapButton,
          ),
        PostAttachmentKind.unknown => const SizedBox.shrink(),
      },
    );
  }
}

class _ImageSlot extends StatelessWidget {
  final PostAttachment attachment;
  final void Function(String attachmentId)? onTap;

  const _ImageSlot({required this.attachment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = attachment.displayUrl;
    if (url == null) return const SizedBox.shrink();

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: scheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (_, _, _) => Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant, size: 40),
        ),
      ),
    );

    if (onTap == null) return image;
    return GestureDetector(
      onTap: () => onTap!(attachment.id),
      child: image,
    );
  }
}

// ── Activity slot — fetches real data, renders route preview + stats ──────────

class _ActivitySlot extends StatefulWidget {
  final PostAttachment attachment;
  final void Function(String activityId)? onTap;
  final bool showMapButton;
  const _ActivitySlot({
    required this.attachment,
    this.onTap,
    this.showMapButton = false,
  });

  @override
  State<_ActivitySlot> createState() => _ActivitySlotState();
}

class _ActivitySlotState extends State<_ActivitySlot> {
  ActivitySummary? _summary;
  List<MapPoint>? _routePoints; // fallback when no previewPolyline
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final refId = widget.attachment.refId;
    if (refId == null) {
      setState(() => _loading = false);
      return;
    }

    // 1. Check history cache first — free, covers the common case of
    //    sharing your own activity.
    final cached = context
        .read<ActivityHistoryProvider>()
        .history
        .where((a) => a.id == refId)
        .firstOrNull;

    if (cached != null) {
      setState(() {
        _summary = cached;
        _loading = false;
      });
      return;
    }

    // 2. Not in cache — fetch full activity from API.
    try {
      final activity =
          await context.read<ActivityApiService>().getById(refId);
      if (!mounted) return;
      // Convert Activity → ActivitySummary shape for display.
      setState(() {
        _summary = ActivitySummary(
          id: activity.id,
          activityType: activity.activityType,
          startTime: activity.startTime,
          endTime: activity.endTime,
          distanceKm: activity.distanceKm,
          avgPaceMinPerKm: activity.avgPaceMinPerKm,
          durationSeconds: activity.durationSeconds,
          previewPolyline: null, // full Activity has no previewPolyline
        );
        _routePoints = activity.route
            .map((p) => MapPoint(p.lat, p.lon))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return GestureDetector(
      onTap: widget.attachment.refId != null && widget.onTap != null
          ? () => widget.onTap!(widget.attachment.refId!)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: cardColor,
          child: _loading
              ? _buildSkeleton(scheme)
              : _failed || _summary == null
                  ? _buildFallback(scheme)
                  : _buildCard(scheme),
        ),
      ),
    );
  }

  Widget _buildCard(ColorScheme scheme) {
    final s = _summary!;
    return Column(
      children: [
        // Route preview — fills ~60% of the 300px slot height.
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              Positioned.fill(
                child: RoutePreview(
                  encodedPolyline: s.previewPolyline,
                  points: _routePoints,
                ),
              ),
              if (widget.showMapButton && widget.attachment.refId != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () =>
                        widget.onTap?.call(widget.attachment.refId!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined,
                              size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Open in full map',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Stats strip.
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_run,
                        size: 14, color: scheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      _typeLabel(s.activityType),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _shortDate(s.startTime),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Stat(
                      label: 'Distance',
                      value: '${s.distanceKm.toStringAsFixed(2)} km',
                      scheme: scheme,
                    ),
                    const SizedBox(width: 20),
                    if (s.durationSeconds != null)
                      _Stat(
                        label: 'Time',
                        value: s.formattedDuration,
                        scheme: scheme,
                      ),
                    const SizedBox(width: 20),
                    if (s.avgPaceMinPerKm != null)
                      _Stat(
                        label: 'Pace',
                        value: s.formattedPace,
                        scheme: scheme,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(ColorScheme scheme) {
    return Container(color: scheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()));
  }

  Widget _buildFallback(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run, size: 36, color: scheme.primary),
          const SizedBox(height: 8),
          Text('Activity',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: scheme.onSurface)),
        ],
      ),
    );
  }

  String _typeLabel(String raw) =>
      raw[0].toUpperCase() + raw.substring(1).toLowerCase().replaceAll('_', ' ');

  String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) { return ''; }
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;
  const _Stat({required this.label, required this.value, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface)),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int active;
  const _DotIndicator({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
