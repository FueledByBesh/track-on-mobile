import 'package:flutter/material.dart';
import '../models/daily_steps.dart';
import '../services/step_service.dart';
import '../services/step_sync_service.dart';

class StepsProvider extends ChangeNotifier {
  final StepApiService _apiService;
  final StepSyncService _syncService;

  DailySteps _today = DailySteps.empty();
  List<DailySteps> _history = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  StepsProvider(this._apiService, this._syncService);

  DailySteps get today => _today;
  List<DailySteps> get history => _history;
  bool get isLoading => _isLoading;

  /// Main entry: sync with Health Connect + backend and refresh display.
  Future<void> loadSteps({required bool isOnline}) async {
    if (!_hasLoaded) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final displayData = await _syncService.syncAndGetDisplayData(isOnline: isOnline);
      _history = displayData;
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      _today = displayData.firstWhere(
        (d) => d.date == todayStr,
        orElse: () => DailySteps.empty(),
      );
      _hasLoaded = true;
    } catch (e) {
      debugPrint('Error loading steps: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateGoal(int goal) async {
    try {
      _today = await _apiService.updateGoal(goal);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating goal: $e');
    }
  }
}
