import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../api_client.dart';

enum OfflineReason {
  none,
  noConnection,
  serverUnreachable,
}

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _healthPollTimer;

  bool _isOnline = true;
  bool _hasNetwork = true;
  OfflineReason _offlineReason = OfflineReason.none;
  bool _isChecking = false;

  // Separate Dio for health checks (no auth interceptor)
  final Dio _healthDio = Dio(BaseOptions(
    baseUrl: ApiClient.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  bool get isOnline => _isOnline;
  bool get hasNetwork => _hasNetwork;
  OfflineReason get offlineReason => _offlineReason;
  bool get isChecking => _isChecking;

  String get offlineMessage {
    switch (_offlineReason) {
      case OfflineReason.noConnection:
        return 'Connection lost. You are now in offline mode.';
      case OfflineReason.serverUnreachable:
        return 'Server unreachable. You are now in offline mode.';
      case OfflineReason.none:
        return '';
    }
  }

  void start() {
    // Listen to connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    // Check initial state
    _connectivity.checkConnectivity().then(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hadNetwork = _hasNetwork;
    _hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (!_hasNetwork) {
      // Device lost all network interfaces
      _setOffline(OfflineReason.noConnection);
      _stopHealthPolling();
    } else if (!hadNetwork && _hasNetwork) {
      // Network came back — check server immediately, then start polling
      checkHealth();
      _startHealthPolling();
    } else if (!_isOnline && _hasNetwork) {
      // Was offline due to server, network still exists — start polling
      _startHealthPolling();
    }
  }

  /// Called when a Dio API request fails with a connection error.
  void reportConnectionError() {
    if (_isOnline) {
      _setOffline(_hasNetwork ? OfflineReason.serverUnreachable : OfflineReason.noConnection);
      if (_hasNetwork) {
        _startHealthPolling();
      }
    }
  }

  /// Manual health check (user tapped banner or pull-to-refresh).
  /// Returns true if back online.
  Future<bool> checkHealth() async {
    _isChecking = true;
    notifyListeners();

    try {
      final response = await _healthDio.get('/health');
      if (response.statusCode == 200) {
        _setOnline();
        _stopHealthPolling();
        _isChecking = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Server unreachable — update reason if we have network but server is down
      if (_hasNetwork) {
        _setOffline(OfflineReason.serverUnreachable);
      }
    }

    _isChecking = false;
    notifyListeners();
    return false;
  }

  void _startHealthPolling() {
    _stopHealthPolling();
    _healthPollTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkHealth();
    });
  }

  void _stopHealthPolling() {
    _healthPollTimer?.cancel();
    _healthPollTimer = null;
  }

  void _setOffline(OfflineReason reason) {
    if (_isOnline || _offlineReason != reason) {
      _isOnline = false;
      _offlineReason = reason;
      notifyListeners();
    }
  }

  void _setOnline() {
    if (!_isOnline) {
      _isOnline = true;
      _offlineReason = OfflineReason.none;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _stopHealthPolling();
    super.dispose();
  }
}
