import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Pure, stateful filter that decides whether a raw GPS fix should contribute
/// to the recorded track. Stateful because several rules depend on the
/// previously accepted point (min-distance, max-speed).
///
/// Not tied to the recorder — unit-testable in isolation.
class LocationFilter {
  /// Drop fixes with accuracy worse than this (meters). 20m is a reasonable
  /// urban-running threshold; tunnels / indoor fixes are typically 50m+.
  final double maxAccuracyMeters;

  /// Require the new accepted point to be at least this far from the previous.
  /// Filters GPS jitter when standing still.
  final double minDistanceMeters;

  /// Cap the implied speed between consecutive accepted points. Units: m/s.
  /// Running ≈ 5, cycling ≈ 20. A single bad fix teleporting the user 200m is
  /// the classic failure this prevents.
  final double maxSpeedMetersPerSec;

  /// Reject fixes whose OS timestamp is older than this (cached / stale).
  final int maxStalenessMs;

  /// Number of fixes to silently drop at warmup start. GPS often hands out a
  /// cached last-known position on cold start, which may be far from reality.
  final int warmupSkipCount;

  int _warmupRemaining;
  Position? _lastAccepted;

  LocationFilter({
    this.maxAccuracyMeters = 20,
    this.minDistanceMeters = 3,
    this.maxSpeedMetersPerSec = 10,
    this.maxStalenessMs = 5000,
    this.warmupSkipCount = 2,
  }) : _warmupRemaining = 2;

  /// Re-arm warmup. Called on initial start AND on resume — because the user
  /// may have walked 50m while paused, the first post-resume fix should not
  /// connect back to the pre-pause point.
  void beginWarmup() {
    _warmupRemaining = warmupSkipCount;
    _lastAccepted = null;
  }

  /// Evaluate a raw fix. The returned [FilterOutcome] tells the caller what
  /// to do: add the point to the route and update distance, or drop it.
  FilterOutcome evaluate(Position p) {
    // Freshness — OS sometimes delivers a cached fix from minutes ago.
    final ageMs = DateTime.now().millisecondsSinceEpoch -
        p.timestamp.millisecondsSinceEpoch;
    if (ageMs > maxStalenessMs) {
      return const FilterOutcome.rejected(FilterRejectReason.stale);
    }

    // Accuracy gate.
    if (p.accuracy > maxAccuracyMeters) {
      return const FilterOutcome.rejected(FilterRejectReason.poorAccuracy);
    }

    // Warmup: drop first N fresh fixes entirely (not even used to seed
    // _lastAccepted, so the first *counted* point is a real reading).
    if (_warmupRemaining > 0) {
      _warmupRemaining--;
      return const FilterOutcome.warmup();
    }

    if (_lastAccepted != null) {
      final prev = _lastAccepted!;
      final distM = _haversineMeters(
        prev.latitude,
        prev.longitude,
        p.latitude,
        p.longitude,
      );

      // Jitter filter.
      if (distM < minDistanceMeters) {
        return const FilterOutcome.rejected(FilterRejectReason.tooClose);
      }

      // Speed sanity.
      final dtMs =
          p.timestamp.millisecondsSinceEpoch - prev.timestamp.millisecondsSinceEpoch;
      if (dtMs > 0) {
        final impliedSpeed = distM / (dtMs / 1000.0);
        if (impliedSpeed > maxSpeedMetersPerSec) {
          return const FilterOutcome.rejected(FilterRejectReason.speedSpike);
        }
      }

      _lastAccepted = p;
      return FilterOutcome.accepted(distM / 1000.0);
    }

    // First post-warmup point. Seeds state, contributes zero distance.
    _lastAccepted = p;
    return const FilterOutcome.accepted(0);
  }

  /// Haversine great-circle distance in meters.
  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}

enum FilterRejectReason { stale, poorAccuracy, tooClose, speedSpike }

enum FilterStatus { accepted, warmup, rejected }

class FilterOutcome {
  final FilterStatus status;
  final double addedKm;
  final FilterRejectReason? reason;

  const FilterOutcome._(this.status, this.addedKm, this.reason);

  const FilterOutcome.accepted(double addedKm)
      : this._(FilterStatus.accepted, addedKm, null);

  const FilterOutcome.warmup() : this._(FilterStatus.warmup, 0, null);

  const FilterOutcome.rejected(FilterRejectReason reason)
      : this._(FilterStatus.rejected, 0, reason);

  bool get isAccepted => status == FilterStatus.accepted;
}
