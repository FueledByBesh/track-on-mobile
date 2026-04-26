/// Mirror of the backend `UserActivityStatsResponse`. Drives the
/// Activity tab on the profile page.
class UserActivityStats {
  final String userId;
  final int windowDays;
  final ActivityTotals totals;
  final List<ActivityWeekBucket> weekly;
  final List<ActivityTypeShare> types;

  const UserActivityStats({
    required this.userId,
    required this.windowDays,
    required this.totals,
    required this.weekly,
    required this.types,
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
    );
  }

  /// True when the user has zero activity in the window. Drives the
  /// empty-state UI on the Activity tab.
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
