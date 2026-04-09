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
      stepCount: json['stepCount'] ?? 0,
      goal: json['goal'] ?? 10000,
      progressPercent: (json['progressPercent'] ?? 0).toDouble(),
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      caloriesBurned: (json['caloriesBurned'] ?? 0).toDouble(),
      lastUpdated: json['lastUpdated'],
    );
  }

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
  final String start;
  final String end;
  final int stepsValue;
  final String date;
  final String? source;

  StepInterval({
    this.id,
    required this.start,
    required this.end,
    required this.stepsValue,
    required this.date,
    this.source,
  });

  factory StepInterval.fromJson(Map<String, dynamic> json) {
    return StepInterval(
      id: json['id'],
      start: json['start'] ?? '',
      end: json['end'] ?? '',
      stepsValue: json['stepsValue'] ?? 0,
      date: json['date'] ?? '',
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'stepsValue': stepsValue,
    'date': date,
    if (source != null) 'source': source,
  };
}
