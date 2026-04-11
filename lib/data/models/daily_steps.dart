class DailySteps {
  final String? id;
  final String date;
  final int stepCount;
  final int goal;
  final double progressPercent;
  final double distanceKm;
  final double caloriesBurned;
  final String? lastUpdated;

  DailySteps({
    this.id,
    required this.date,
    required this.stepCount,
    required this.goal,
    required this.progressPercent,
    required this.distanceKm,
    required this.caloriesBurned,
    this.lastUpdated,
  });

  factory DailySteps.fromJson(Map<String, dynamic> json) {
    return DailySteps(
      id: json['id'],
      date: json['date'] ?? '',
      stepCount: json['step_count'] ?? 0,
      goal: json['goal'] ?? 10000,
      progressPercent: (json['progress_percent'] ?? 0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      caloriesBurned: (json['calories_burned'] ?? 0).toDouble(),
      lastUpdated: json['last_updated'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'date': date,
    'step_count': stepCount,
    'goal': goal,
    'progress_percent': progressPercent,
    'distance_km': distanceKm,
    'calories_burned': caloriesBurned,
    if (lastUpdated != null) 'last_updated': lastUpdated,
  };

  factory DailySteps.empty() {
    return DailySteps(
      date: DateTime.now().toIso8601String().split('T')[0],
      stepCount: 0,
      goal: 10000,
      progressPercent: 0,
      distanceKm: 0,
      caloriesBurned: 0,
    );
  }
}

class StepInterval {
  final String? id;
  final String startUtc;
  final String endUtc;
  final String startLocal;
  final String endLocal;
  final int stepsValue;
  final String date;
  final String? source;

  StepInterval({
    this.id,
    required this.startUtc,
    required this.startLocal,
    required this.endUtc,
    required this.endLocal,
    required this.stepsValue,
    required this.date,
    this.source,
  });

  factory StepInterval.fromJson(Map<String, dynamic> json) {
    return StepInterval(
      id: json['id'],
      startUtc: json['start_utc'] ?? '',
      startLocal: json['start_local'] ?? '',
      endUtc: json['end_utc'] ?? '',
      endLocal: json['end_local'] ?? '',
      stepsValue: json['steps_value'] ?? 0,
      date: json['date'] ?? '',
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() => {
    'start_utc': startUtc,
    'end_utc': endUtc,
    'start_local': startLocal,
    'end_local': endLocal,
    'steps_value': stepsValue,
    if (source != null) 'source': source,
  };
}
