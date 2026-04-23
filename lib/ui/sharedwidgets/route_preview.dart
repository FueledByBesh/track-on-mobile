import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:trackon_mobile/data/models/map_point.dart';
import 'package:trackon_mobile/data/util/polyline_decoder.dart';

/// Theme-adaptive static preview of a route. Decodes a Google-polyline
/// string, projects it onto the widget's bounds with an
/// equirectangular projection (aspect-correct at the route's
/// latitude), and strokes it in the current theme's primary color on
/// a tinted background.
///
/// Use anywhere a tiny silhouette of an activity's route helps the
/// user recognize it: history cards, feed post thumbnails, analytics
/// grids. Not interactive — tap the surrounding card to open the
/// full map-backed detail page.
class RoutePreview extends StatelessWidget {
  /// Encoded polyline (e.g. `ActivitySummary.previewPolyline`). Null
  /// or empty renders an icon placeholder — that's the pre-backfill
  /// state for legacy activities.
  final String? encodedPolyline;

  /// Corner radius applied via [ClipRRect] when the widget is placed
  /// inside a container that has its own border radius the polyline
  /// shouldn't bleed past. Defaults to 0 (no clip).
  final BorderRadius borderRadius;

  /// Optional override; defaults to `ColorScheme.primary`.
  final Color? strokeColor;

  const RoutePreview({
    super.key,
    required this.encodedPolyline,
    this.borderRadius = BorderRadius.zero,
    this.strokeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final encoded = encodedPolyline;
    if (encoded == null || encoded.isEmpty) {
      return _Placeholder(scheme: scheme, borderRadius: borderRadius);
    }
    final points = PolylineDecoder.decode(encoded);
    if (points.length < 2) {
      return _Placeholder(scheme: scheme, borderRadius: borderRadius);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(gradient: _backgroundGradient(scheme)),
        child: CustomPaint(
          painter: _RoutePainter(
            points: points,
            color: strokeColor ?? scheme.primary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  static LinearGradient _backgroundGradient(ColorScheme scheme) {
    return LinearGradient(
      colors: [
        scheme.primary.withAlpha(30),
        scheme.primary.withAlpha(12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

// ============ PAINTER ============

class _RoutePainter extends CustomPainter {
  final List<MapPoint> points;
  final Color color;

  _RoutePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;

    // Bounds of the route in lat/lon.
    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLon = points.first.lon;
    double maxLon = points.first.lon;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }

    // Equirectangular projection correction so a 1° box doesn't look
    // stretched near the equator vs at high latitudes. Convert the
    // lon-span to its "effective" meters using cos(refLat).
    final refLat = (minLat + maxLat) / 2;
    final cosLat = math.cos(refLat * math.pi / 180);
    final lonSpan = (maxLon - minLon).abs() * cosLat;
    final latSpan = (maxLat - minLat).abs();

    // Inset a little so the stroke isn't clipped on the edges.
    const inset = 10.0;
    final innerWidth = (size.width - inset * 2).clamp(1.0, size.width);
    final innerHeight = (size.height - inset * 2).clamp(1.0, size.height);

    // Uniform scale so the aspect ratio of the route is preserved.
    final scaleX = lonSpan > 0 ? innerWidth / lonSpan : innerWidth;
    final scaleY = latSpan > 0 ? innerHeight / latSpan : innerHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Center the route within the inset box.
    final renderedW = lonSpan * scale;
    final renderedH = latSpan * scale;
    final offsetX = inset + (innerWidth - renderedW) / 2;
    final offsetY = inset + (innerHeight - renderedH) / 2;

    double projectX(double lon) =>
        offsetX + (lon - minLon) * cosLat * scale;
    double projectY(double lat) =>
        // Flip Y: higher latitude = up on screen.
        offsetY + (maxLat - lat) * scale;

    final path = Path()
      ..moveTo(projectX(points.first.lon), projectY(points.first.lat));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(projectX(points[i].lon), projectY(points[i].lat));
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);

    // Start/end markers — subtle directional hint.
    final startPaint = Paint()
      ..color = color.withAlpha(180)
      ..style = PaintingStyle.fill;
    final endPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(projectX(points.first.lon), projectY(points.first.lat)),
      3,
      startPaint,
    );
    canvas.drawCircle(
      Offset(projectX(points.last.lon), projectY(points.last.lat)),
      3.5,
      endPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.points != points || old.color != color;
}

// ============ PLACEHOLDER ============

/// Shown when there's no polyline yet (legacy rows pre-backfill, or
/// degenerate activities with fewer than 2 points).
class _Placeholder extends StatelessWidget {
  final ColorScheme scheme;
  final BorderRadius borderRadius;

  const _Placeholder({required this.scheme, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          gradient: RoutePreview._backgroundGradient(scheme),
        ),
        child: Center(
          child: Icon(
            Icons.route,
            size: 40,
            color: scheme.primary.withAlpha(140),
          ),
        ),
      ),
    );
  }
}
