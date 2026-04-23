/// Training modality — mirrors the backend `WorkoutCategory` enum.
/// Kept as a value+label wrapper (not an enum) so unknown categories
/// from the server don't crash the client; UI only renders known
/// values from [WorkoutCategory.all].
class WorkoutCategory {
  final String value;
  final String label;
  const WorkoutCategory(this.value, this.label);

  static const strength = WorkoutCategory('STRENGTH', 'Strength');
  static const crossfit = WorkoutCategory('CROSSFIT', 'CrossFit');
  static const cardio = WorkoutCategory('CARDIO', 'Cardio');
  static const yoga = WorkoutCategory('YOGA', 'Yoga');
  static const mobility = WorkoutCategory('MOBILITY', 'Mobility');

  static const all = [strength, crossfit, cardio, yoga, mobility];

  static WorkoutCategory fromValue(String value) {
    return all.firstWhere(
      (c) => c.value == value,
      orElse: () => WorkoutCategory(value, value),
    );
  }
}

/// Denormalized muscle target — server sends the muscle group name
/// alongside its id so we don't need a separate reference fetch.
class WorkoutMuscle {
  final int muscleGroupId;
  final String name;
  final int percentage;

  const WorkoutMuscle({
    required this.muscleGroupId,
    required this.name,
    required this.percentage,
  });

  factory WorkoutMuscle.fromJson(Map<String, dynamic> json) {
    return WorkoutMuscle(
      muscleGroupId: (json['muscle_group_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'muscle_group_id': muscleGroupId,
        'name': name,
        'percentage': percentage,
      };
}

class Workout {
  final String id;
  final String name;
  final WorkoutCategory category;
  final int recommendedSets;
  final int recommendedReps;
  final int? approxDurationMinutes;
  final int? restTimeSeconds;
  final String? tutorialVideoUrl;
  final List<WorkoutMuscle> muscles;

  const Workout({
    required this.id,
    required this.name,
    required this.category,
    required this.recommendedSets,
    required this.recommendedReps,
    this.approxDurationMinutes,
    this.restTimeSeconds,
    this.tutorialVideoUrl,
    this.muscles = const [],
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      category: WorkoutCategory.fromValue(json['category'] as String? ?? 'STRENGTH'),
      recommendedSets: (json['recommended_sets'] as num?)?.toInt() ?? 3,
      recommendedReps: (json['recommended_reps'] as num?)?.toInt() ?? 10,
      approxDurationMinutes: (json['approx_duration_minutes'] as num?)?.toInt(),
      restTimeSeconds: (json['rest_time_seconds'] as num?)?.toInt(),
      tutorialVideoUrl: json['tutorial_video_url'] as String?,
      muscles: (json['muscles'] as List<dynamic>?)
              ?.map((e) => WorkoutMuscle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Cheap probe for the workout library cache. Mobile stores this
/// locally and compares against the backend's current value to decide
/// whether to refetch the full list.
class WorkoutLibraryStatus {
  final int count;
  final DateTime lastEditAt;

  const WorkoutLibraryStatus({
    required this.count,
    required this.lastEditAt,
  });

  factory WorkoutLibraryStatus.fromJson(Map<String, dynamic> json) {
    return WorkoutLibraryStatus(
      count: (json['count'] as num).toInt(),
      lastEditAt: DateTime.parse(json['last_edit_at'] as String),
    );
  }
}

class WorkoutProgram {
  final String id;
  final String name;
  final String? description;
  final bool active;
  final List<int> schedule; // 1=Mon..7=Sun
  final List<ProgramWorkoutItem> items;

  WorkoutProgram({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
    this.schedule = const [],
    required this.items,
  });

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) {
    return WorkoutProgram(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ProgramWorkoutItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Discriminated union for the My Day timeline. Each item is either
/// a standalone workout or a program card.
sealed class DayItem {
  int get sortOrder;
  bool get completed;
  String get id;
}

class DayWorkout extends DayItem {
  @override
  final String id;
  @override
  final int sortOrder;
  @override
  final bool completed;
  final String workoutId;
  final String workoutName;
  final WorkoutCategory category;
  final String? tutorialVideoUrl;
  final int sets;
  final int reps;

  DayWorkout({
    required this.id,
    required this.sortOrder,
    required this.completed,
    required this.workoutId,
    required this.workoutName,
    required this.category,
    this.tutorialVideoUrl,
    required this.sets,
    required this.reps,
  });
}

class DayProgram extends DayItem {
  @override
  final String id;
  @override
  final int sortOrder;
  @override
  final bool completed;
  final String programId;
  final String programName;
  final String? programDescription;
  final int workoutCount;

  DayProgram({
    required this.id,
    required this.sortOrder,
    required this.completed,
    required this.programId,
    required this.programName,
    this.programDescription,
    required this.workoutCount,
  });
}

DayItem dayItemFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  if (type == 'program') {
    return DayProgram(
      id: json['id'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      programId: json['program_id'] as String,
      programName: json['program_name'] as String? ?? '',
      programDescription: json['program_description'] as String?,
      workoutCount: (json['workout_count'] as num?)?.toInt() ?? 0,
    );
  }
  return DayWorkout(
    id: json['id'] as String,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    completed: json['completed'] as bool? ?? false,
    workoutId: json['workout_id'] as String,
    workoutName: json['workout_name'] as String? ?? '',
    category: WorkoutCategory.fromValue(json['category'] as String? ?? 'STRENGTH'),
    tutorialVideoUrl: json['tutorial_video_url'] as String?,
    sets: (json['sets'] as num?)?.toInt() ?? 3,
    reps: (json['reps'] as num?)?.toInt() ?? 10,
  );
}

class ProgramWorkoutItem {
  final String id;
  final String workoutId;
  final String workoutName;
  final WorkoutCategory category;
  final int sets;
  final int reps;
  final int sortOrder;

  ProgramWorkoutItem({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.category,
    required this.sets,
    required this.reps,
    required this.sortOrder,
  });

  factory ProgramWorkoutItem.fromJson(Map<String, dynamic> json) {
    return ProgramWorkoutItem(
      id: json['id'],
      workoutId: json['workout_id'],
      workoutName: json['workout_name'] ?? '',
      category: WorkoutCategory.fromValue(json['category'] ?? 'STRENGTH'),
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? 10,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class PlannedWorkout {
  final String id;
  final String workoutId;
  final String workoutName;
  final WorkoutCategory category;
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
    required this.category,
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
      workoutId: json['workout_id'],
      workoutName: json['workout_name'] ?? '',
      category: WorkoutCategory.fromValue(json['category'] ?? 'STRENGTH'),
      tutorialVideoUrl: json['tutorial_video_url'],
      plannedDate: json['planned_date'] ?? '',
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? 10,
      completed: json['completed'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
