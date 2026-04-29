import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/workout.dart';
import '../../../data/providers/fitness_provider.dart';

/// Step-by-step session that walks the user through a list of
/// PlannedWorkouts: one workout at a time, tracks current set, runs a
/// 60-second rest timer between sets, and marks completion at the end.
///
/// Two start contexts:
///   1. Standalone planned_workouts (My Day "Start Training" button) —
///      each exercise is its own server row, marked complete per row.
///   2. Scheduled program (My Day program card or program detail) —
///      a single planned_program row is marked done at the end; per-
///      exercise progress is in-memory only.
class TrainingSessionPage extends StatefulWidget {
  final List<PlannedWorkout> workouts;

  /// When non-null, this session was started from a scheduled program
  /// card on My Day. Completing the last exercise auto-marks the whole
  /// planned_program as done via a single API call.
  final String? plannedProgramId;

  /// True when the workouts are standalone planned_workout rows (from
  /// the My Day timeline's individual workout cards). Each exercise has
  /// its own planned_workout ID and should be marked completed per-row.
  final bool isStandaloneWorkouts;

  const TrainingSessionPage({
    super.key,
    required this.workouts,
    this.plannedProgramId,
    this.isStandaloneWorkouts = false,
  });

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  int _currentIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;
  int _restSeconds = 60;

  List<PlannedWorkout> get _workouts =>
      widget.workouts.where((w) => !w.completed).toList();
  PlannedWorkout? get _currentWorkout =>
      _currentIndex < _workouts.length ? _workouts[_currentIndex] : null;
  bool get _isLastSet =>
      _currentWorkout != null && _currentSet >= _currentWorkout!.sets;
  bool get _isLastWorkout => _currentIndex >= _workouts.length - 1;

  void _finishSet() {
    if (_isLastSet) {
      _finishWorkout();
      return;
    }
    setState(() {
      _isResting = true;
      _restSeconds = 60;
    });
    _startRestTimer();
  }

  void _startRestTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isResting) return false;
      setState(() => _restSeconds--);
      if (_restSeconds <= 0) {
        setState(() {
          _isResting = false;
          _currentSet++;
        });
        return false;
      }
      return true;
    });
  }

  void _finishWorkout() {
    // Per-exercise server completion ONLY for standalone planned_workout
    // rows. Program exercises are tracked in memory — the whole program
    // gets one completion call when the session ends.
    if (widget.isStandaloneWorkouts && _currentWorkout != null) {
      context
          .read<FitnessProvider>()
          .toggleWorkoutCompleted(_currentWorkout!.id, true);
    }

    if (_isLastWorkout) {
      // If this is a program session, mark the planned_program as done.
      if (widget.plannedProgramId != null) {
        context.read<FitnessProvider>().toggleProgramCompleted(
              widget.plannedProgramId!,
              true,
            );
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training complete!')),
      );
    } else {
      setState(() {
        _currentIndex++;
        _currentSet = 1;
        _isResting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentWorkout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training')),
        body: const Center(child: Text('No workouts to do!')),
      );
    }
    final workout = _currentWorkout!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1}/${_workouts.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              workout.workoutName,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${workout.sets} sets x ${workout.reps} reps',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            if (_isResting)
              Column(
                children: [
                  Text(
                    'Rest',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_restSeconds',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _isResting = false;
                      _currentSet++;
                    }),
                    child: const Text('Skip Rest'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Text(
                    'Set $_currentSet of ${workout.sets}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${workout.reps} reps',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary),
                  ),
                ],
              ),
            const Spacer(),
            if (!_isResting)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _finishSet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isLastSet ? 'Finish Workout' : 'Finish Set',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (!_isLastSet) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _finishWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(56, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child:
                          const Icon(Icons.skip_next, color: Colors.white),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
