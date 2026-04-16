import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_library_service.dart';
import '../services/workout_service.dart';

class FitnessProvider extends ChangeNotifier {
  final WorkoutLibraryService _libraryService;
  final ProgramApiService _programService;
  final PlannedWorkoutApiService _plannedService;

  List<Workout> _workoutLibrary = [];
  List<WorkoutProgram> _programs = [];
  List<DayItem> _dayItems = [];
  DateTime _selectedDate = DateTime.now();
  WorkoutCategory? _selectedCategory;
  Set<int> _selectedMuscleGroupIds = {};
  bool _isLoading = false;
  bool _isLibraryRefreshing = false;
  bool _hasLoadedPlanned = false;
  bool _hasLoadedPrograms = false;
  bool _hasLoadedLibrary = false;

  FitnessProvider(
    this._libraryService,
    this._programService,
    this._plannedService,
  );

  /// Filtered library view — category chip + optional muscle filter
  /// chips intersect to produce the visible set.
  List<Workout> get workoutLibrary {
    Iterable<Workout> result = _workoutLibrary;
    if (_selectedCategory != null) {
      result =
          result.where((w) => w.category.value == _selectedCategory!.value);
    }
    if (_selectedMuscleGroupIds.isNotEmpty) {
      result = result.where(
        (w) => w.muscles.any(
          (m) => _selectedMuscleGroupIds.contains(m.muscleGroupId),
        ),
      );
    }
    return result.toList();
  }

  List<Workout> get allWorkouts => _workoutLibrary;

  /// Distinct muscles present across the loaded library, sorted by name.
  /// Used for the muscle filter chip row.
  List<WorkoutMuscle> get availableMuscleFilters {
    final seen = <int, WorkoutMuscle>{};
    for (final w in _workoutLibrary) {
      for (final m in w.muscles) {
        seen.putIfAbsent(m.muscleGroupId, () => m);
      }
    }
    final list = seen.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<WorkoutProgram> get programs => _programs;
  List<DayItem> get dayItems => _dayItems;
  DateTime get selectedDate => _selectedDate;
  WorkoutCategory? get selectedCategory => _selectedCategory;
  Set<int> get selectedMuscleGroupIds => _selectedMuscleGroupIds;
  bool get isLoading => _isLoading;
  bool get isLibraryRefreshing => _isLibraryRefreshing;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadDayItems();
  }

  void setCategory(WorkoutCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleMuscleFilter(int muscleGroupId) {
    if (_selectedMuscleGroupIds.contains(muscleGroupId)) {
      _selectedMuscleGroupIds.remove(muscleGroupId);
    } else {
      _selectedMuscleGroupIds.add(muscleGroupId);
    }
    notifyListeners();
  }

  void clearMuscleFilters() {
    if (_selectedMuscleGroupIds.isEmpty) return;
    _selectedMuscleGroupIds = {};
    notifyListeners();
  }

  /// First-pass load: shows spinner only if we have no cached data yet.
  /// Subsequent calls do a cheap status probe; the UI isn't blocked.
  Future<void> loadWorkoutLibrary() async {
    if (!_hasLoadedLibrary) {
      _isLoading = true;
      notifyListeners();
    } else {
      _isLibraryRefreshing = true;
      notifyListeners();
    }
    try {
      _workoutLibrary = await _libraryService.ensureFresh();
      _hasLoadedLibrary = true;
    } catch (e) {
      debugPrint('Error loading workout library: $e');
    }
    _isLoading = false;
    _isLibraryRefreshing = false;
    notifyListeners();
  }

  /// Explicit force refresh — triggered by pull-to-refresh. Always hits
  /// the network and replaces the cache.
  Future<void> forceRefreshLibrary() async {
    _isLibraryRefreshing = true;
    notifyListeners();
    try {
      _workoutLibrary = await _libraryService.forceRefresh();
    } catch (e) {
      debugPrint('Force refresh failed: $e');
    }
    _isLibraryRefreshing = false;
    notifyListeners();
  }

  Future<void> loadPrograms() async {
    if (!_hasLoadedPrograms) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _programs = await _programService.getAll();
      _hasLoadedPrograms = true;
    } catch (e) {
      debugPrint('Error loading programs: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Load the merged My Day timeline (workouts + programs) for the
  /// currently selected date.
  Future<void> loadDayItems() async {
    if (!_hasLoadedPlanned) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      _dayItems = await _plannedService.getDayItems(dateStr);
      _hasLoadedPlanned = true;
    } catch (e) {
      debugPrint('Error loading day items: $e');
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
      await loadDayItems();
    } catch (e) {
      debugPrint('Error adding workout to day: $e');
    }
  }

  /// Add a program as a single card to a day (not exploded into workouts).
  Future<void> addProgramToDay(String programId, {DateTime? date}) async {
    try {
      final target = date ?? _selectedDate;
      final dateStr = target.toIso8601String().split('T')[0];
      await _plannedService.addProgramToDaySingle(programId, dateStr);
      await loadDayItems();
    } catch (e) {
      debugPrint('Error adding program to day: $e');
      rethrow;
    }
  }

  Future<void> toggleWorkoutCompleted(String id, bool completed) async {
    try {
      await _plannedService.updateWorkout(id, completed: completed);
      await loadDayItems();
    } catch (e) {
      debugPrint('Error toggling workout: $e');
    }
  }

  Future<void> toggleProgramCompleted(String id, bool completed) async {
    try {
      await _plannedService.markProgramCompleted(id, completed);
      await loadDayItems();
    } catch (e) {
      debugPrint('Error toggling program: $e');
    }
  }

  Future<void> deletePlannedWorkout(String id) async {
    try {
      await _plannedService.deleteWorkout(id);
      await loadDayItems();
    } catch (e) {
      debugPrint('Error deleting planned workout: $e');
    }
  }

  Future<void> deletePlannedProgram(String id) async {
    try {
      await _plannedService.removePlannedProgram(id);
      await loadDayItems();
    } catch (e) {
      debugPrint('Error deleting planned program: $e');
    }
  }

  /// Update program metadata (name, description, active, schedule, items).
  Future<void> updateProgram(
    String id, {
    required String name,
    String? description,
    bool? active,
    List<int>? schedule,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      await _programService.update(id, name, items ?? []);
      // The existing update replaces items. For schedule/description/active
      // we need the extended DTO — but the current mobile ProgramApiService
      // still sends the old shape. We'll extend it to send the full body.
      await loadPrograms();
    } catch (e) {
      debugPrint('Error updating program: $e');
      rethrow;
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

  /// Checks local program state — "is this workout already in this
  /// program?" Pure function over the cached programs list, no network.
  bool isWorkoutInProgram(String programId, String workoutId) {
    final program = _programs.firstWhere(
      (p) => p.id == programId,
      orElse: () => WorkoutProgram(id: '', name: '', items: []),
    );
    return program.items.any((item) => item.workoutId == workoutId);
  }

  /// Per-row toggle action for the "Add to Program" sheet. Surfaces
  /// errors to the caller so the UI can keep the row in its previous
  /// state on failure (e.g. 409 duplicate, network error).
  Future<void> addWorkoutToProgram(String programId, String workoutId) async {
    final updated =
        await _programService.addWorkoutToProgram(programId, workoutId);
    _replaceProgramInCache(updated);
    notifyListeners();
  }

  Future<void> removeWorkoutFromProgram(
      String programId, String workoutId) async {
    final updated =
        await _programService.removeWorkoutFromProgram(programId, workoutId);
    _replaceProgramInCache(updated);
    notifyListeners();
  }

  /// Batch-add one workout to many days. Used by the "Add to day" sheet.
  Future<void> addWorkoutToDays(
      String workoutId, List<DateTime> dates) async {
    if (dates.isEmpty) return;
    final dateStrings =
        dates.map((d) => d.toIso8601String().split('T')[0]).toList();
    await _plannedService.batchAddWorkout(
      workoutId: workoutId,
      dates: dateStrings,
    );
    // Refresh whichever date is currently selected in MyDayTab
    await loadDayItems();
  }

  void _replaceProgramInCache(WorkoutProgram updated) {
    final index = _programs.indexWhere((p) => p.id == updated.id);
    if (index >= 0) {
      _programs[index] = updated;
    } else {
      _programs.add(updated);
    }
  }

  /// Create a new program with a starting workout in one shot.
  /// Used by the "Create new program" flow in the Add-to-Program sheet.
  Future<WorkoutProgram> createProgramWithWorkout(
      String name, String workoutId) async {
    final program = await _programService.create(name, [
      {'workout_id': workoutId},
    ]);
    _programs.add(program);
    notifyListeners();
    return program;
  }
}
