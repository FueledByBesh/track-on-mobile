import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'device_service.dart';

/// Top-level background message handler. Must be annotated so Flutter
/// keeps it alive across isolate boundaries — `firebase_messaging`
/// spawns a fresh isolate for background pushes, and the handler
/// has to be a top-level or static function.
///
/// We deliberately don't touch the UI or local DBs from here — the
/// OS renders the notification itself via the `notification` field
/// the backend sets; this handler exists purely so `firebase_messaging`
/// treats the message as delivered.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // No-op. The user taps the OS notification → the app opens →
  // onMessageOpenedApp / getInitialMessage fires and we route.
}

/// Manages the FCM token lifecycle for a signed-in user. Wired by
/// AuthProvider: `start(userId)` after sign-in, `stop()` on
/// sign-out. Foreground / background / tap handlers are bound once
/// at boot via `bindHandlers`.
class PushMessagingService {
  final DeviceApiService _deviceApi;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  /// Fires when the user taps a push (foreground, background, or
  /// terminated entry). Carries the server-issued `deep_link` string
  /// from the `data` payload; consumers turn that into a route.
  final ValueNotifier<String?> onTapDeepLink = ValueNotifier<String?>(null);

  /// Fires when a push arrives while the app is foregrounded. The
  /// notifications page / home-header bell listen so the unread
  /// badge refreshes without waiting for a user action.
  final ValueNotifier<int> foregroundTick = ValueNotifier<int>(0);

  PushMessagingService(this._deviceApi);

  /// Call once at app boot (after `Firebase.initializeApp`). Sets up
  /// permission request, message stream listeners, and — if the app
  /// was launched by tapping a push from terminated state —
  /// processes the initial message.
  Future<void> bindHandlers() async {
    // Android 13+ needs the runtime permission to actually show
    // banners; iOS needs it for any notification at all. Returns
    // immediately on Android < 13.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Terminated → tapped push → cold-start launch: process that
    // one payload once as soon as we can.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _emitDeepLink(initial);
    }

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      // Arrived while app is open. The OS doesn't show a banner in
      // this state — we just nudge listeners to refresh (e.g. the
      // unread badge).
      foregroundTick.value = foregroundTick.value + 1;
    });

    _openedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_emitDeepLink);
  }

  /// Register the current device's token with the backend and watch
  /// for token rotation. Called on every successful sign-in.
  Future<void> start() async {
    final platform = _platformString();
    if (platform == null) return; // Unsupported platform — skip silently.

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _deviceApi.register(fcmToken: token, platform: platform);
      }
    } catch (e) {
      debugPrint('Initial FCM register failed: $e');
    }

    // Re-register whenever FCM rotates the token (OS-triggered — not
    // user-visible). We don't need to unregister the old one; the
    // server treats the token as the PK and will have it marked dead
    // on next fanout.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        try {
          await _deviceApi.register(fcmToken: token, platform: platform);
        } catch (e) {
          debugPrint('Token-refresh register failed: $e');
        }
      },
    );
  }

  /// Unregister the current token with the backend on sign-out so
  /// the next user of the same device doesn't receive the previous
  /// user's pushes. Best-effort — failure is logged.
  Future<void> stop() async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _deviceApi.unregister(token);
      }
      // Also drop the local token so the next sign-in gets a fresh
      // one — prevents cross-account bleed on shared devices.
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }

  /// Tear-down for tests / hot restarts. Not called in normal use.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    onTapDeepLink.dispose();
    foregroundTick.dispose();
  }

  void _emitDeepLink(RemoteMessage message) {
    final link = message.data['deep_link'];
    if (link is String && link.isNotEmpty) {
      onTapDeepLink.value = link;
    }
  }

  static String? _platformString() {
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return null;
  }
}
