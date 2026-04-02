import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class FitnessProvider extends ChangeNotifier {
  final WorkoutApiService _workoutService;
  final ProgramApiService _programService;
  final PlannedWorkoutApiService _plannedService;

  List<Workout> _workoutLibrary = [];
  List<WorkoutProgram> _programs = [];
  List<PlannedWorkout> _plannedWorkouts = [];
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  bool _isLoading = false;

  FitnessProvider(this._workoutService, this._programService, this._plannedService);

  List<Workout> get workoutLibrary => _selectedCategory != null
      ? _workoutLibrary.where((w) => w.workoutType == _selectedCategory).toList()
      : _workoutLibrary;
  List<Workout> get allWorkouts => _workoutLibrary;
  List<WorkoutProgram> get programs => _programs;
  List<PlannedWorkout> get plannedWorkouts => _plannedWorkouts;
  DateTime get selectedDate => _selectedDate;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadPlannedWorkouts();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> loadWorkoutLibrary() async {
    try {
      _workoutLibrary = await _workoutService.getAll();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading workout library: $e');
    }
  }

  Future<void> loadPrograms() async {
    _isLoading = true;
    notifyListeners();
    try {
      _programs = await _programService.getAll();
    } catch (e) {
      debugPrint('Error loading programs: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPlannedWorkouts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      _plannedWorkouts = await _plannedService.getByDate(dateStr);
    } catch (e) {
      debugPrint('Error loading planned workouts: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addWorkoutToDay(String workoutId, {int? sets, int? reps}) async {
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      await _plannedService.addWorkout(
        workoutId: workoutId,
        plannedDate: dateStr,
        customSets: sets,
        customReps: reps,
      );
      await loadPlannedWorkouts();
    } catch (e) {
      debugPrint('Error adding workout to day: $e');
    }
  }

  Future<void> addProgramToDay(String programId) async {
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      await _plannedService.addProgramToDay(programId, dateStr);
      await loadPlannedWorkouts();
    } catch (e) {
      debugPrint('Error adding program to day: $e');
    }
  }

  Future<void> toggleWorkoutCompleted(String id, bool completed) async {
    try {
      await _plannedService.updateWorkout(id, completed: completed);
      await loadPlannedWorkouts();
    } catch (e) {
      debugPrint('Error toggling workout: $e');
    }
  }

  Future<void> deletePlannedWorkout(String id) async {
    try {
      await _plannedService.deleteWorkout(id);
      await loadPlannedWorkouts();
    } catch (e) {
      debugPrint('Error deleting planned workout: $e');
    }
  }

  Future<void> createProgram(String name, List<Map<String, dynamic>> items) async {
    try {
      await _programService.create(name, items);
      await loadPrograms();
    } catch (e) {
      debugPrint('Error creating program: $e');
    }
  }

  Future<void> deleteProgram(String id) async {
    try {
      await _programService.delete(id);
      await loadPrograms();
    } catch (e) {
      debugPrint('Error deleting program: $e');
    }
  }
}
