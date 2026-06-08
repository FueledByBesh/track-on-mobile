import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api_client.dart';
import '../services/logger_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  /// One-shot flag: true when the current session was ended by the
  /// interceptor (refresh rejected), false when the user intentionally
  /// signed out or never had a session. Consumed by AuthWrapper to decide
  /// whether to show a "session expired" SnackBar.
  bool _showExpiredMessage = false;

  AuthProvider(this._api);

  /// Fires whenever the user becomes logged-out (explicit sign-out or
  /// token-expiry). Wired in main.dart to clear the HTTP response cache
  /// so the next user can't see the previous session's data.
  Future<void> Function()? onSignedOut;

  /// Fires whenever the user transitions into a logged-in state (a
  /// completed sign-in flow, not app-launch-with-stored-tokens — that
  /// one relies on the token already being registered from the prior
  /// session). Wired in main.dart to register the FCM push token
  /// with the backend.
  Future<void> Function()? onSignedIn;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get showExpiredMessage => _showExpiredMessage;

  /// Called by the ApiClient interceptor when both access and refresh tokens
  /// have been rejected and secure storage has been cleared. Flips the UI
  /// into the logged-out state and queues a one-shot "session expired" toast
  /// for AuthWrapper to show.
  void handleAuthExpired() {
    final wasLoggedIn = _isLoggedIn;
    _isLoggedIn = false;
    if (wasLoggedIn) {
      _showExpiredMessage = true;
      // Fire-and-forget; the UI doesn't need to wait for the cache wipe.
      unawaited(_invokeSignedOutHook());
    }
    notifyListeners();
  }

  Future<void> _invokeSignedOutHook() async {
    try {
      await onSignedOut?.call();
    } catch (e) {
      debugPrint('onSignedOut hook threw: $e');
    }
  }

  Future<void> _invokeSignedInHook() async {
    try {
      await onSignedIn?.call();
    } catch (e) {
      debugPrint('onSignedIn hook threw: $e');
    }
  }

  /// AuthWrapper calls this after showing the expired-session toast so the
  /// same message doesn't fire twice on the next rebuild.
  void consumeExpiredMessage() {
    _showExpiredMessage = false;
  }

  /// Check if we have valid tokens on app startup.
  ///
  /// Stored tokens are the source of truth. If they exist, the user is
  /// optimistically logged in — even if the backend is unreachable, we
  /// don't force them through the login flow (offline mode must just work).
  ///
  /// The best-effort backend ping exists only to catch the narrow case
  /// where both tokens are genuinely expired. If that happens, the Dio
  /// interceptor clears the stored tokens on refresh failure; we re-read
  /// them afterward to observe what the interceptor decided. Network
  /// errors, timeouts, and 5xx leave tokens untouched → user stays in.
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    _isLoggedIn = await ApiClient.hasTokens();

    if (_isLoggedIn) {
      try {
        await _api.dio.get('/api/steps/last-sync');
      } catch (_) {
        // Interceptor is the only authority on token clearing — re-read
        // storage to find out what it decided.
        _isLoggedIn = await ApiClient.hasTokens();
      }
    }

    _isLoading = false;
    notifyListeners();

    // Existing session survived the launch check — register the
    // current device's push token. Idempotent on the backend, so
    // running it every launch is fine and covers the "user already
    // signed in when push feature shipped" case.
    if (_isLoggedIn) {
      unawaited(_invokeSignedInHook());
    }
  }

  /// Native Google Sign-In:
  ///   1. Authenticate via Play Services (in-app account picker)
  ///   2. POST the resulting ID token to /auth/google
  ///   3. Save the returned app access + refresh token pair
  ///
  /// Returns true on success. Returns false (and logs) on any failure —
  /// the caller flips UI state based on _isLoggedIn, which won't change
  /// unless step 3 completes.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      Logger.i('AUTH', 'Calling GoogleSignIn.authenticate()');
      final account = await GoogleSignIn.instance.authenticate();
      Logger.i('AUTH', 'authenticate() returned: email=${account.email}');

      final idToken = account.authentication.idToken;
      Logger.i('AUTH', 'idToken present=${idToken != null} length=${idToken?.length ?? 0}');

      if (idToken == null || idToken.isEmpty) {
        Logger.w('AUTH', 'No ID token returned — check serverClientId is a WEB client ID and SHA-1 is registered');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      Logger.i('AUTH', 'POST /auth/google');
      final response = await _api.dio.post(
        '/auth/google',
        data: {'id_token': idToken},
      );
      Logger.i('AUTH', 'Backend responded ${response.statusCode}');

      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['access_token'] != null) {
        await ApiClient.saveTokens(
          response.data['access_token'] as String,
          response.data['refresh_token'] as String,
        );
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        unawaited(_invokeSignedInHook());
        return true;
      }
      Logger.w('AUTH', 'Unexpected response shape: ${response.data}');
    } on GoogleSignInException catch (e) {
      Logger.w('AUTH', 'GoogleSignInException: code=${e.code} desc=${e.description}');
    } catch (e, st) {
      Logger.e('AUTH', 'Sign in error: $e', e, st);
    }

    _isLoggedIn = false;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    // Fire the signed-out hook FIRST so any authed cleanup calls
    // (e.g. PushMessagingService.stop() → DELETE /api/devices/...)
    // complete before we wipe the access token. After clearTokens
    // runs those requests would 401.
    await _invokeSignedOutHook();

    // Clear the cached Google account so the next signIn shows the
    // picker again (otherwise Play Services silently reuses the last
    // account). Best-effort — failures here shouldn't block logout.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleSignIn.signOut failed: $e');
    }

    // Best-effort backend cleanup: clear DB refresh token rows.
    // If we're offline or the backend is down, just clear local state —
    // the user tapped "sign out" and they expect to be logged out.
    try {
      await _api.dio.post('/auth/logout');
    } catch (e) {
      debugPrint('Logout endpoint failed, clearing local state anyway: $e');
    }
    await ApiClient.clearTokens();
    _isLoggedIn = false;
    notifyListeners();
  }
}
