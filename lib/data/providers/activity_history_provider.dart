import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

/// Holds past activities. Independent of the live recording state.
/// Uses 5-min throttle pattern to avoid unnecessary refetches.
class ActivityHistoryProvider extends ChangeNotifier {
  final ActivityApiService _api;

  ActivityHistoryProvider(this._api);

  List<ActivitySummary> _history = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  DateTime? _lastFetch;

  static const _throttle = Duration(minutes: 5);

  List<ActivitySummary> get history => _history;
  bool get isLoading => _isLoading;

  /// Lazy load — fetches if cache is empty or stale.
  Future<void> loadHistory() async {
    if (_hasLoaded &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _throttle) {
      return;
    }
    await _fetch(showSpinner: !_hasLoaded);
  }

  /// Manual refresh — skips throttle.
  Future<void> forceRefresh() async {
    await _fetch(showSpinner: false);
  }

  /// Called by ActivityProvider after a run finishes — silent refresh.
  Future<void> refreshAfterStop() async {
    await _fetch(showSpinner: false);
  }

  Future<void> _fetch({required bool showSpinner}) async {
    if (showSpinner) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _history = await _api.getAll();
      _hasLoaded = true;
      _lastFetch = DateTime.now();
    } catch (e) {
      debugPrint('Error loading activity history: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}
