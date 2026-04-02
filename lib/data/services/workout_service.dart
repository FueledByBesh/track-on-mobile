import '../api_client.dart';
import '../models/workout.dart';

class WorkoutApiService {
  final ApiClient _api;

  WorkoutApiService(this._api);

  Future<List<Workout>> getAll({String? type}) async {
    final response = await _api.dio.get('/api/workouts',
        queryParameters: type != null ? {'type': type} : null);
    return (response.data as List).map((e) => Workout.fromJson(e)).toList();
  }

  Future<Workout> getById(String id) async {
    final response = await _api.dio.get('/api/workouts/$id');
    return Workout.fromJson(response.data);
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
      'workoutId': workoutId,
      'plannedDate': plannedDate,
      if (customSets != null) 'customSets': customSets,
      if (customReps != null) 'customReps': customReps,
    });
    return PlannedWorkout.fromJson(response.data);
  }

  Future<PlannedWorkout> updateWorkout(String id, {int? customSets, int? customReps, bool? completed}) async {
    final response = await _api.dio.put('/api/planned-workouts/$id', data: {
      if (customSets != null) 'customSets': customSets,
      if (customReps != null) 'customReps': customReps,
      if (completed != null) 'completed': completed,
    });
    return PlannedWorkout.fromJson(response.data);
  }

  Future<void> deleteWorkout(String id) async {
    await _api.dio.delete('/api/planned-workouts/$id');
  }

  Future<List<PlannedWorkout>> addProgramToDay(String programId, String plannedDate) async {
    final response = await _api.dio.post('/api/planned-workouts/program', data: {
      'programId': programId,
      'plannedDate': plannedDate,
    });
    return (response.data as List).map((e) => PlannedWorkout.fromJson(e)).toList();
  }
}
