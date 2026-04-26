import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import 'health_service.dart';
import 'logger_service.dart';

/// App-level permission identifiers. Abstract names so we can map to the
/// right platform concept later — on iOS, `fitness` will resolve to
/// HealthKit instead of Health Connect with no enum change.
enum AppPermission {
  location,
  fitness,
  notifications,
}

/// Unified status across all permission types. The underlying platform
/// APIs each have their own enum; we normalize to this one so callers
/// never have to branch on which permission they're looking at.
enum AppPermissionStatus {
  /// User has allowed access.
  granted,

  /// User has denied once but the OS dialog can still be shown again.
  denied,

  /// User has either picked "Don't ask again" (Android) or denied twice
  /// on iOS — calling `request()` will be a no-op. The only way forward
  /// is to send them to the system settings page via `openAppSettings()`.
  permanentlyDenied,

  /// Parental controls / MDM / device policy block access.
  restricted,

  /// The permission concept doesn't exist on this device — e.g. Health
  /// Connect isn't installed on older Android versions. Distinct from
  /// "denied" because the user can't grant it without installing something.
  unavailable,

  /// We haven't checked yet, or an error occurred mid-check.
  unknown,
}

/// Thin, stateless wrapper around the platform permission APIs. Knows
/// nothing about Provider or the UI — just reads and requests.
///
/// Granting is inherently asynchronous and user-modal; this service never
/// claims it can force a grant. `request()` shows the OS dialog and
/// returns the resulting status. For `permanentlyDenied`, callers must
/// escalate by asking the user to open app settings themselves.
class PermissionService {
  /// Read current status without prompting.
  Future<AppPermissionStatus> check(AppPermission permission) async {
    try {
      switch (permission) {
        case AppPermission.location:
          return _mapGeolocatorStatus(await Geolocator.checkPermission());
        case AppPermission.fitness:
          return _checkFitness();
        case AppPermission.notifications:
          return _checkNotifications();
      }
    } catch (e) {
      Logger.w('PERM', 'check($permission) failed: $e');
      return AppPermissionStatus.unknown;
    }
  }

  /// Show the platform's permission prompt. May be a no-op if the user
  /// already picked "Don't ask again". Returns the state AFTER the prompt.
  Future<AppPermissionStatus> request(AppPermission permission) async {
    try {
      switch (permission) {
        case AppPermission.location:
          return _requestLocation();
        case AppPermission.fitness:
          return _requestFitness();
        case AppPermission.notifications:
          return _requestNotifications();
      }
    } catch (e) {
      Logger.e('PERM', 'request($permission) failed', e);
      return AppPermissionStatus.unknown;
    }
  }

  /// Open the app's settings page so the user can change permissions
  /// that are currently `permanentlyDenied`. Returns true if the OS
  /// actually navigated there (e.g. false on web or unsupported).
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      Logger.w('PERM', 'openAppSettings failed: $e');
      return false;
    }
  }

  // ============ LOCATION ============

  AppPermissionStatus _mapGeolocatorStatus(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return AppPermissionStatus.granted;
      case LocationPermission.denied:
        return AppPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return AppPermissionStatus.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        return AppPermissionStatus.unknown;
    }
  }

  Future<AppPermissionStatus> _requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      // Location services turned off system-wide. We report unknown —
      // caller UI should surface a "turn on location services" message
      // separately since this isn't a per-app permission issue.
      Logger.w('PERM', 'location services disabled system-wide');
      return AppPermissionStatus.unknown;
    }
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.deniedForever) {
      return AppPermissionStatus.permanentlyDenied;
    }
    final requested = await Geolocator.requestPermission();
    return _mapGeolocatorStatus(requested);
  }

  // ============ FITNESS (Health Connect on Android) ============

  Future<AppPermissionStatus> _checkFitness() async {
    if (!await HealthService.isAvailable()) {
      return AppPermissionStatus.unavailable;
    }
    final has = await HealthService.hasPermissions();
    return has ? AppPermissionStatus.granted : AppPermissionStatus.denied;
  }

  Future<AppPermissionStatus> _requestFitness() async {
    if (!await HealthService.isAvailable()) {
      return AppPermissionStatus.unavailable;
    }
    final granted = await HealthService.requestPermission();
    return granted ? AppPermissionStatus.granted : AppPermissionStatus.denied;
  }

  // ============ NOTIFICATIONS (FCM) ============

  /// FirebaseMessaging's AuthorizationStatus has four states:
  /// `authorized`, `denied`, `provisional`, `notDetermined`. We map
  /// those onto our normalized enum. The only nuance: when the user
  /// has already declined once the API returns `denied` with no
  /// distinction from "can re-prompt" vs "needs settings". We treat
  /// any post-check `denied` as permanentlyDenied so the UI shows
  /// "Open Settings" instead of another Allow button that would
  /// silently no-op on Android 13+ after the second decline.
  Future<AppPermissionStatus> _checkNotifications() async {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return AppPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return AppPermissionStatus.permanentlyDenied;
      case AuthorizationStatus.notDetermined:
        return AppPermissionStatus.denied;
    }
  }

  Future<AppPermissionStatus> _requestNotifications() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return AppPermissionStatus.granted;
      case AuthorizationStatus.denied:
        // OS didn't reprompt (user already denied) or user denied now.
        // Either way next action is "Open Settings."
        return AppPermissionStatus.permanentlyDenied;
      case AuthorizationStatus.notDetermined:
        return AppPermissionStatus.denied;
    }
  }
}
