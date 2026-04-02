class Workout {
  final String id;
  final String name;
  final String workoutType;
  final int recommendedSets;
  final int recommendedReps;
  final String? tutorialVideoUrl;

  Workout({
    required this.id,
    required this.name,
    required this.workoutType,
    required this.recommendedSets,
    required this.recommendedReps,
    this.tutorialVideoUrl,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      name: json['name'] ?? '',
      workoutType: json['workoutType'] ?? '',
      recommendedSets: json['recommendedSets'] ?? 3,
      recommendedReps: json['recommendedReps'] ?? 10,
      tutorialVideoUrl: json['tutorialVideoUrl'],
    );
  }
}

class WorkoutProgram {
  final String id;
  final String name;
  final List<ProgramWorkoutItem> items;

  WorkoutProgram({
    required this.id,
    required this.name,
    required this.items,
  });

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) {
    return WorkoutProgram(
      id: json['id'],
      name: json['name'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ProgramWorkoutItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ProgramWorkoutItem {
  final String id;
  final String workoutId;
  final String workoutName;
  final String workoutType;
  final int sets;
  final int reps;
  final int sortOrder;

  ProgramWorkoutItem({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.workoutType,
    required this.sets,
    required this.reps,
    required this.sortOrder,
  });

  factory ProgramWorkoutItem.fromJson(Map<String, dynamic> json) {
    return ProgramWorkoutItem(
      id: json['id'],
      workoutId: json['workoutId'],
      workoutName: json['workoutName'] ?? '',
      workoutType: json['workoutType'] ?? '',
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? 10,
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class PlannedWorkout {
  final String id;
  final String workoutId;
  final String workoutName;
  final String workoutType;
  final String? tutorialVideoUrl;
  final String plannedDate;
  final int sets;
  final int reps;
  final bool completed;
  final int sortOrder;

  PlannedWorkout({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.workoutType,
    this.tutorialVideoUrl,
    required this.plannedDate,
    required this.sets,
    required this.reps,
    required this.completed,
    required this.sortOrder,
  });

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) {
    return PlannedWorkout(
      id: json['id'],
      workoutId: json['workoutId'],
      workoutName: json['workoutName'] ?? '',
      workoutType: json['workoutType'] ?? '',
      tutorialVideoUrl: json['tutorialVideoUrl'],
      plannedDate: json['plannedDate'] ?? '',
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? 10,
      completed: json['completed'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}
