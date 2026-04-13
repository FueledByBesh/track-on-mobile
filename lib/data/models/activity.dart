/// Server-side activity summary — returned by the history list endpoint.
class ActivitySummary {
  final String id;
  final String activityType;
  final String startTime; // ISO-8601
  final String? endTime;
  final double distanceKm;
  final double? avgPaceMinPerKm;
  final int? durationSeconds;

  ActivitySummary({
    required this.id,
    required this.activityType,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    this.avgPaceMinPerKm,
    this.durationSeconds,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      id: json['id'].toString(),
      activityType: json['activity_type'] ?? 'RUNNING',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'],
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
      durationSeconds: json['duration_seconds'],
    );
  }

  String get formattedDuration {
    final s = durationSeconds ?? 0;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (avgPaceMinPerKm == null || avgPaceMinPerKm == 0) return '--';
    final m = avgPaceMinPerKm!.floor();
    final sec = ((avgPaceMinPerKm! - m) * 60).round();
    return "$m'${sec.toString().padLeft(2, '0')}\"";
  }
}

/// Full activity — returned by detail endpoint, with decoded route.
class Activity {
  final String id;
  final String activityType;
  final String startTime;
  final String? endTime;
  final double distanceKm;
  final double? avgPaceMinPerKm;
  final int? durationSeconds;
  final List<RoutePoint> route;

  Activity({
    required this.id,
    required this.activityType,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    this.avgPaceMinPerKm,
    this.durationSeconds,
    this.route = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'].toString(),
      activityType: json['activity_type'] ?? 'RUNNING',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'],
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
      durationSeconds: json['duration_seconds'],
      route: (json['route'] as List<dynamic>?)
              ?.map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Summary values the recorder hands back when a session is completed locally.
class CompletedSessionResult {
  final String localId;
  final double distanceKm;
  final int durationSeconds;
  final double? avgPaceMinPerKm;

  const CompletedSessionResult({
    required this.localId,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgPaceMinPerKm,
  });

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (avgPaceMinPerKm == null || avgPaceMinPerKm == 0) return '--';
    final m = avgPaceMinPerKm!.floor();
    final sec = ((avgPaceMinPerKm! - m) * 60).round();
    return "$m'${sec.toString().padLeft(2, '0')}\"";
  }
}

/// A single point on a recorded route.
class RoutePoint {
  final double lat;
  final double lon;
  final int timestampMs; // epoch millis UTC
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final int segmentIndex; // increments after each pause to mark discontinuity

  const RoutePoint({
    required this.lat,
    required this.lon,
    required this.timestampMs,
    this.altitude,
    this.accuracy,
    this.speed,
    this.segmentIndex = 0,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      lat: (json['lat'] ?? json['latitude'] ?? 0).toDouble(),
      lon: (json['lon'] ?? json['longitude'] ?? 0).toDouble(),
      timestampMs: json['timestamp_ms'] ?? 0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      segmentIndex: json['segment_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'timestamp_ms': timestampMs,
        if (altitude != null) 'altitude': altitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
        'segment_index': segmentIndex,
      };
}

/// Finalized payload uploaded to the backend after a run ends.
///
/// Carries both UTC instants (for absolute ordering) and local wall-clock
/// strings (for date-bucketing in the user's timezone). Pauses and route
/// points stay UTC-only — they're never bucketed by local date.
class ActivityUploadPayload {
  final String clientId; // mobile-generated UUID, idempotency key
  final String activityType;
  final int startedAtMs;
  final String startedAtLocal; // ISO-8601 without offset, e.g. 2026-04-13T07:30:00.000
  final int endedAtMs;
  final String endedAtLocal;
  final double distanceKm; // client-computed; server may recompute
  final int durationSeconds; // wall-clock derived, excluding pauses
  final int pausedMs;
  final List<RoutePoint> route;
  final List<PauseInterval> pauses;

  const ActivityUploadPayload({
    required this.clientId,
    required this.activityType,
    required this.startedAtMs,
    required this.startedAtLocal,
    required this.endedAtMs,
    required this.endedAtLocal,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pausedMs,
    required this.route,
    required this.pauses,
  });

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'activity_type': activityType,
        'started_at_ms': startedAtMs,
        'started_at_local': startedAtLocal,
        'ended_at_ms': endedAtMs,
        'ended_at_local': endedAtLocal,
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'paused_ms': pausedMs,
        'route': route.map((p) => p.toJson()).toList(),
        'pauses': pauses.map((p) => p.toJson()).toList(),
      };
}

class PauseInterval {
  final int startMs;
  final int endMs;

  const PauseInterval({required this.startMs, required this.endMs});

  Map<String, dynamic> toJson() => {
        'start_ms': startMs,
        'end_ms': endMs,
      };
}
