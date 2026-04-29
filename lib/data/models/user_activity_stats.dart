/// Mirror of the backend `UserActivityStatsResponse`. Drives the
/// Activity tab on the profile page.
class UserActivityStats {
  final String userId;
  final int windowDays;
  final ActivityTotals totals;
  final List<ActivityWeekBucket> weekly;
  final List<ActivityTypeShare> types;
  final List<ActivityRecordsByType> records;
  final List<ActivityHeatmapDay> heatmap;

  const UserActivityStats({
    required this.userId,
    required this.windowDays,
    required this.totals,
    required this.weekly,
    required this.types,
    required this.records,
    required this.heatmap,
  });

  factory UserActivityStats.fromJson(Map<String, dynamic> json) {
    return UserActivityStats(
      userId: json['user_id'] as String? ?? '',
      windowDays: json['window_days'] as int? ?? 30,
      totals: ActivityTotals.fromJson(
          json['totals'] as Map<String, dynamic>? ?? const {}),
      weekly: (json['weekly'] as List<dynamic>? ?? const [])
          .map((e) =>
              ActivityWeekBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      types: (json['types'] as List<dynamic>? ?? const [])
          .map((e) =>
              ActivityTypeShare.fromJson(e as Map<String, dynamic>))
          .toList(),
      records: (json['records'] as List<dynamic>? ?? const [])
          .map((e) =>
              ActivityRecordsByType.fromJson(e as Map<String, dynamic>))
          .toList(),
      heatmap: (json['heatmap'] as List<dynamic>? ?? const [])
          .map((e) =>
              ActivityHeatmapDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty =>
      totals.sessions == 0 && weekly.isEmpty && types.isEmpty;
}

class ActivityTotals {
  final double distanceKm;
  final int durationSeconds;
  final int sessions;
  final double longestKm;

  const ActivityTotals({
    required this.distanceKm,
    required this.durationSeconds,
    required this.sessions,
    required this.longestKm,
  });

  factory ActivityTotals.fromJson(Map<String, dynamic> json) {
    return ActivityTotals(
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      longestKm: (json['longest_km'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ActivityWeekBucket {
  /// ISO-8601 date (yyyy-MM-dd) of the Monday that starts the week.
  final String weekStart;
  final double runningKm;
  final double bikingKm;
  final double walkingKm;

  const ActivityWeekBucket({
    required this.weekStart,
    required this.runningKm,
    required this.bikingKm,
    required this.walkingKm,
  });

  double get totalKm => runningKm + bikingKm + walkingKm;

  factory ActivityWeekBucket.fromJson(Map<String, dynamic> json) {
    return ActivityWeekBucket(
      weekStart: json['week_start'] as String? ?? '',
      runningKm: (json['running_km'] as num?)?.toDouble() ?? 0,
      bikingKm: (json['biking_km'] as num?)?.toDouble() ?? 0,
      walkingKm: (json['walking_km'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ActivityTypeShare {
  final String activityType;
  final double distanceKm;

  const ActivityTypeShare({
    required this.activityType,
    required this.distanceKm,
  });

  factory ActivityTypeShare.fromJson(Map<String, dynamic> json) {
    return ActivityTypeShare(
      activityType: json['activity_type'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Per-activity-type personal bests within the window. The list comes
/// back sorted by the user's total distance for that type (most-active
/// type first), so the UI's chip selector can default to their main
/// sport. Types with zero activity in the window are absent.
class ActivityRecordsByType {
  final String activityType;
  final double longestKm;
  final int longestDurationSeconds;
  final double fastestPaceMinPerKm;
  /// Number of activities of this type in the window.
  final int sessions;

  const ActivityRecordsByType({
    required this.activityType,
    required this.longestKm,
    required this.longestDurationSeconds,
    required this.fastestPaceMinPerKm,
    required this.sessions,
  });

  factory ActivityRecordsByType.fromJson(Map<String, dynamic> json) {
    return ActivityRecordsByType(
      activityType: json['activity_type'] as String? ?? '',
      longestKm: (json['longest_km'] as num?)?.toDouble() ?? 0,
      longestDurationSeconds:
          (json['longest_duration_seconds'] as num?)?.toInt() ?? 0,
      fastestPaceMinPerKm:
          (json['fastest_pace_min_per_km'] as num?)?.toDouble() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty =>
      longestKm == 0 &&
      longestDurationSeconds == 0 &&
      fastestPaceMinPerKm == 0 &&
      sessions == 0;
}

/// One day with at least one activity. Sparse — days with no activity
/// are absent. Mobile fills missing days with zeros when rendering.
class ActivityHeatmapDay {
  /// ISO-8601 yyyy-MM-dd in the user's local timezone (server-stored).
  final String day;
  final double distanceKm;
  final int durationSeconds;
  final int sessions;

  const ActivityHeatmapDay({
    required this.day,
    required this.distanceKm,
    required this.durationSeconds,
    required this.sessions,
  });

  factory ActivityHeatmapDay.fromJson(Map<String, dynamic> json) {
    return ActivityHeatmapDay(
      day: json['day'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}
