import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'models/daily_steps.dart';
import 'services/step_service.dart';

class StepTracker {
  final StepApiService _stepService;
  final Pedometer _pedometer = Pedometer();
  StreamSubscription<int>? _stepSubscription;
  Timer? _syncTimer;

  int _lastSyncedSteps = 0;
  int _currentSteps = 0;
  DateTime _intervalStart = DateTime.now();

  StepTracker(this._stepService);

  void start() {
    _intervalStart = DateTime.now();
    _lastSyncedSteps = 0;
    _currentSteps = 0;

    _stepSubscription = _pedometer.stepCountStream().listen(
      (int steps) {
        _currentSteps = steps;
      },
      onError: (error) {
        debugPrint('Step counter error: $error');
      },
    );

    // Sync every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _syncSteps();
    });
  }

  void stop() {
    _syncSteps(); // Final sync
    _stepSubscription?.cancel();
    _syncTimer?.cancel();
  }

  Future<void> _syncSteps() async {
    final stepsInInterval = _currentSteps - _lastSyncedSteps;
    if (stepsInInterval <= 0) return;

    final now = DateTime.now();
    final interval = StepInterval(
      start: _intervalStart.toUtc().toIso8601String(),
      end: now.toUtc().toIso8601String(),
      stepsValue: stepsInInterval,
      date: now.toIso8601String().split('T')[0],
    );

    try {
      await _stepService.syncSteps([interval]);
      _lastSyncedSteps = _currentSteps;
      _intervalStart = now;
    } catch (e) {
      debugPrint('Error syncing steps: $e');
    }
  }
}
