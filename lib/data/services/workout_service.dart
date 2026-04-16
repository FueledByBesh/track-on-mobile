import '../api_client.dart';
import '../models/workout.dart';

class WorkoutApiService {
  final ApiClient _api;

  WorkoutApiService(this._api);

  Future<List<Workout>> getAll({String? category}) async {
    final response = await _api.dio.get(
      '/api/workouts',
      queryParameters: category != null ? {'category': category} : null,
    );
    return (response.data as List).map((e) => Workout.fromJson(e)).toList();
  }

  Future<Workout> getById(String id) async {
    final response = await _api.dio.get('/api/workouts/$id');
    return Workout.fromJson(response.data);
  }

  /// Cheap probe — used by the library cache to decide if a refetch
  /// is needed. Returns count + last edit timestamp.
  Future<WorkoutLibraryStatus> getStatus() async {
    final response = await _api.dio.get('/api/workouts/status');
    return WorkoutLibraryStatus.fromJson(response.data as Map<String, dynamic>);
  }
}

class ProgramApiService {
  final ApiClient _api;

  ProgramApiService(this._api);

  Future<List<WorkoutProgram>> getAll() async {
    final response = await _api.dio.get('/api/programs');
    return (response.data as List).map((e) => WorkoutProgram.fromJson(e)).toList();
  }

  Future<WorkoutProgram> getById(String id) async {
    final response = await _api.dio.get('/api/programs/$id');
    return WorkoutProgram.fromJson(response.data);
  }

  Future<WorkoutProgram> create(String name, List<Map<String, dynamic>> items) async {
    final response = await _api.dio.post('/api/programs', data: {
      'name': name,
      'items': items,
    });
    return WorkoutProgram.fromJson(response.data);
  }

  Future<WorkoutProgram> update(String id, String name, List<Map<String, dynamic>> items) async {
    final response = await _api.dio.put('/api/programs/$id', data: {
      'name': name,
      'items': items,
    });
    return WorkoutProgram.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _api.dio.delete('/api/programs/$id');
  }

  /// Per-row toggle endpoint — atomic add of a single workout to a
  /// single program. Returns the updated program so the caller can
  /// re-render in one round trip. 409 if already in program.
  Future<WorkoutProgram> addWorkoutToProgram(
    String programId,
    String workoutId, {
    int? customSets,
    int? customReps,
  }) async {
    final response = await _api.dio.post(
      '/api/programs/$programId/workouts',
      data: {
        'workout_id': workoutId,
        if (customSets != null) 'custom_sets': customSets,
        if (customReps != null) 'custom_reps': customReps,
      },
    );
    return WorkoutProgram.fromJson(response.data);
  }

  /// Per-row toggle endpoint — remove a single workout from a program.
  /// Returns the updated program.
  Future<WorkoutProgram> removeWorkoutFromProgram(
    String programId,
    String workoutId,
  ) async {
    final response = await _api.dio.delete(
      '/api/programs/$programId/workouts/$workoutId',
    );
    return WorkoutProgram.fromJson(response.data);
  }
}

class PlannedWorkoutApiService {
  final ApiClient _api;

  PlannedWorkoutApiService(this._api);

  Future<List<PlannedWorkout>> getByDate(String date) async {
    final response = await _api.dio.get('/api/planned-workouts', queryParameters: {'date': date});
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e)).toList();
  }

  Future<List<PlannedWorkout>> getByWeek(String from, String to) async {
    final response = await _api.dio.get('/api/planned-workouts/week', queryParameters: {
      'from': from,
      'to': to,
    });
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e)).toList();
  }

  Future<PlannedWorkout> addWorkout({
    required String workoutId,
    required String plannedDate,
    int? customSets,
    int? customReps,
  }) async {
    final response = await _api.dio.post('/api/planned-workouts', data: {
      'workout_id': workoutId,
      'planned_date': plannedDate,
      if (customSets != null) 'custom_sets': customSets,
      if (customReps != null) 'custom_reps': customReps,
    });
    return PlannedWorkout.fromJson(response.data);
  }

  Future<PlannedWorkout> updateWorkout(String id, {int? customSets, int? customReps, bool? completed}) async {
    final response = await _api.dio.put('/api/planned-workouts/$id', data: {
      if (customSets != null) 'custom_sets': customSets,
      if (customReps != null) 'custom_reps': customReps,
      if (completed != null) 'completed': completed,
    });
    return PlannedWorkout.fromJson(response.data);
  }

  Future<void> deleteWorkout(String id) async {
    await _api.dio.delete('/api/planned-workouts/$id');
  }

  Future<List<PlannedWorkout>> addProgramToDay(String programId, String plannedDate) async {
    final response = await _api.dio.post('/api/planned-workouts/program', data: {
      'program_id': programId,
      'planned_date': plannedDate,
    });
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e)).toList();
  }

  /// Batch-add one workout to many days in a single transaction.
  /// Used by the "Add to day" calendar sheet.
  Future<List<PlannedWorkout>> batchAddWorkout({
    required String workoutId,
    required List<String> dates,
    int? customSets,
    int? customReps,
  }) async {
    final response = await _api.dio.post(
      '/api/planned-workouts/batch',
      data: {
        'workout_id': workoutId,
        'dates': dates,
        if (customSets != null) 'custom_sets': customSets,
        if (customReps != null) 'custom_reps': customReps,
      },
    );
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e)).toList();
  }
}
