import 'package:flutter/material.dart';

import '../services/logger_service.dart';
import '../services/permission_service.dart';

/// UI-facing state holder for app permissions. Watches app lifecycle so
/// it can refresh when the user comes back from system settings (where
/// they may have flipped toggles we can't observe directly).
class PermissionProvider extends ChangeNotifier with WidgetsBindingObserver {
  final PermissionService _service;

  final Map<AppPermission, AppPermissionStatus> _statuses = {
    for (final p in AppPermission.values) p: AppPermissionStatus.unknown,
  };

  /// True while a refresh() or request() is in flight — lets the UI
  /// dim buttons to prevent double-taps.
  bool _isBusy = false;

  PermissionProvider(this._service) {
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============ STATE ============

  AppPermissionStatus statusOf(AppPermission p) =>
      _statuses[p] ?? AppPermissionStatus.unknown;

  bool isGranted(AppPermission p) =>
      statusOf(p) == AppPermissionStatus.granted;

  bool get isBusy => _isBusy;

  // ============ ACTIONS ============

  /// Re-read every permission's current status. Cheap, can be called
  /// liberally — each check hits the platform but returns synchronously
  /// enough that there's no visible latency.
  Future<void> refresh() async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    for (final p in AppPermission.values) {
      final status = await _service.check(p);
      _statuses[p] = status;
    }
    _isBusy = false;
    notifyListeners();
    Logger.d('PERM', 'refresh: $_statuses');
  }

  /// Prompt the user. If already granted, returns granted without
  /// prompting. If permanently denied, returns permanentlyDenied
  /// without prompting — the UI should escalate to openAppSettings().
  Future<AppPermissionStatus> request(AppPermission p) async {
    _isBusy = true;
    notifyListeners();
    final result = await _service.request(p);
    _statuses[p] = result;
    _isBusy = false;
    notifyListeners();
    Logger.i('PERM', 'request($p) → $result');
    return result;
  }

  /// Navigate to the app's settings page. Use for permanentlyDenied —
  /// the OS dialog won't reopen once the user has checked "don't ask".
  Future<bool> openAppSettings() => _service.openAppSettings();

  // ============ LIFECYCLE ============

  /// When the user comes back from any system UI (settings app, Health
  /// Connect), refresh so our cached state matches reality. Without
  /// this, a user could revoke location in settings and we'd still
  /// think they have it until the next restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }
}
