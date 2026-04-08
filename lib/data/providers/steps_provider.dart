import 'package:flutter/material.dart';
import '../models/daily_steps.dart';
import '../services/step_service.dart';

class StepsProvider extends ChangeNotifier {
  final StepApiService _service;
  DailySteps _today = DailySteps.empty();
  List<DailySteps> _history = [];
  List<StepInterval> _intervals = [];
  bool _isLoading = false;
  bool _hasLoadedToday = false;

  StepsProvider(this._service);

  DailySteps get today => _today;
  List<DailySteps> get history => _history;
  List<StepInterval> get intervals => _intervals;
  bool get isLoading => _isLoading;

  Future<void> loadToday() async {
    if (!_hasLoadedToday) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _today = await _service.getToday();
      _hasLoadedToday = true;
    } catch (e) {
      debugPrint('Error loading today steps: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHistory(String from, String to) async {
    try {
      _history = await _service.getHistory(from, to);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading step history: $e');
    }
  }

  Future<void> loadIntervals(String date) async {
    try {
      _intervals = await _service.getIntervals(date);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading step intervals: $e');
    }
  }

  Future<void> syncSteps(List<StepInterval> intervals) async {
    try {
      await _service.syncSteps(intervals);
      await loadToday();
    } catch (e) {
      debugPrint('Error syncing steps: $e');
    }
  }

  Future<void> updateGoal(int goal) async {
    try {
      _today = await _service.updateGoal(goal);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating goal: $e');
    }
  }
}
