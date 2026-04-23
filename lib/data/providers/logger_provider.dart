import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// Thin provider around LoggerService. Not reactive to new log writes
/// (would burn battery re-rendering the list every 500ms) — the user
/// pull-to-refreshes or taps the refresh button.
class LoggerProvider extends ChangeNotifier {
  List<LogEntry> _entries = [];
  bool _isLoading = false;

  List<LogEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    _entries = await LoggerService.instance.readAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clear() async {
    await LoggerService.instance.clear();
    _entries = [];
    notifyListeners();
  }
}
