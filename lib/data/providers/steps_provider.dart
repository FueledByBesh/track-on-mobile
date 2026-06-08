import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_steps.dart';
import '../services/step_sync_service.dart';

class StepsProvider extends ChangeNotifier {
  final StepSyncService _syncService;

  static const String _cacheKey = 'steps_7day_cache';
  static const String _lastSyncKey = 'steps_last_sync';
  static const Duration _syncThrottle = Duration(minutes: 5);

  DailySteps _today = DailySteps.empty();
  List<DailySteps> _history = [];
  bool _isLoading = false;
  bool _cacheLoaded = false;
  bool _isSyncing = false;

  StepsProvider(this._syncService);

  DailySteps get today => _today;
  List<DailySteps> get history => _history;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  /// Called when Home page opens.
  /// 1. Load from cache immediately (fast, persistent)
  /// 2. If stale (>5 min since last sync) or empty, sync in background
  Future<void> loadSteps({required bool isOnline}) async {
    // Step 1: Load cache if not already in memory
    if (!_cacheLoaded) {
      await _loadFromCache();
    }

    // Step 2: Check if sync is needed
    if (_history.isEmpty && !_cacheLoaded) {
      // First time ever — no cache, show spinner on stats bar
      _isLoading = true;
      notifyListeners();
      await _syncAndCache(isOnline: isOnline);
      _isLoading = false;
      notifyListeners();
    } else if (await _isSyncStale()) {
      // Cache exists but stale — sync in background, no spinner
      _syncInBackground(isOnline: isOnline);
    }
  }

  /// Force refresh — called by user tapping refresh button.
  /// Skips throttle.
  Future<void> forceRefresh({required bool isOnline}) async {
    _isSyncing = true;
    notifyListeners();
    await _syncAndCache(isOnline: isOnline);
    _isSyncing = false;
    notifyListeners();
  }

  // ============ CACHE ============

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        _history = list.map((e) => DailySteps.fromJson(e)).toList();
        final todayStr = DateTime.now().toLocal().toIso8601String().split('T')[0];
        _today = _history.firstWhere(
          (d) => d.date == todayStr,
          orElse: () => DailySteps.empty(),
        );
      }
    } catch (e) {
      debugPrint('Error loading steps cache: $e');
    }
    _cacheLoaded = true;
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_history.map((d) => d.toJson()).toList());
      await prefs.setString(_cacheKey, json);
      await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      debugPrint('Error saving steps cache: $e');
    }
  }

  Future<bool> _isSyncStale() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    if (lastSyncStr == null) return true;
    final lastSync = DateTime.parse(lastSyncStr);
    return DateTime.now().toUtc().difference(lastSync) > _syncThrottle;
  }

  // ============ SYNC ============

  Future<void> _syncAndCache({required bool isOnline}) async {
    try {
      final displayData = await _syncService.syncAndGetDisplayData(isOnline: isOnline);
      _history = displayData;
      final todayStr = DateTime.now().toLocal().toIso8601String().split('T')[0];
      _today = displayData.firstWhere(
        (d) => d.date == todayStr,
        orElse: () => DailySteps.empty(),
      );
      await _saveToCache();
    } catch (e) {
      debugPrint('Error syncing steps: $e');
    }
  }

  void _syncInBackground({required bool isOnline}) {
    if (_isSyncing) return; // already syncing
    _isSyncing = true;
    notifyListeners();

    _syncAndCache(isOnline: isOnline).then((_) {
      _isSyncing = false;
      notifyListeners();
    });
  }
}
