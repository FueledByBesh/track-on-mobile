class Activity {
  final String id;
  final String activityType;
  final String status;
  final String startTime;
  final String? endTime;
  final double distanceKm;
  final double? avgPaceMinPerKm;
  final int? durationSeconds;
  final List<LocationPointData> route;

  Activity({
    required this.id,
    required this.activityType,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    this.avgPaceMinPerKm,
    this.durationSeconds,
    this.route = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      activityType: json['activityType'] ?? 'RUNNING',
      status: json['status'] ?? 'IN_PROGRESS',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'],
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      avgPaceMinPerKm: json['avgPaceMinPerKm']?.toDouble(),
      durationSeconds: json['durationSeconds'],
      route: (json['route'] as List<dynamic>?)
              ?.map((e) => LocationPointData.fromJson(e))
              .toList() ??
          [],
    );
  }

  String get formattedDuration {
    if (durationSeconds == null) return '0:00';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final seconds = durationSeconds! % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (avgPaceMinPerKm == null) return '--';
    final minutes = avgPaceMinPerKm!.floor();
    final seconds = ((avgPaceMinPerKm! - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }
}

class ActivitySummary {
  final String id;
  final String activityType;
  final String status;
  final String startTime;
  final String? endTime;
  final double distanceKm;
  final double? avgPaceMinPerKm;
  final int? durationSeconds;

  ActivitySummary({
    required this.id,
    required this.activityType,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    this.avgPaceMinPerKm,
    this.durationSeconds,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      id: json['id'],
      activityType: json['activityType'] ?? 'RUNNING',
      status: json['status'] ?? 'COMPLETED',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'],
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      avgPaceMinPerKm: json['avgPaceMinPerKm']?.toDouble(),
      durationSeconds: json['durationSeconds'],
    );
  }
}

class LocationPointData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final String? recordedAt;

  LocationPointData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.recordedAt,
  });

  factory LocationPointData.fromJson(Map<String, dynamic> json) {
    return LocationPointData(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      altitude: json['altitude']?.toDouble(),
      recordedAt: json['recordedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
  };
}
