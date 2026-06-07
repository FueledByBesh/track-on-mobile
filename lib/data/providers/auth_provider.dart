import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  /// One-shot flag: true when the current session was ended by the
  /// interceptor (refresh rejected), false when the user intentionally
  /// signed out or never had a session. Consumed by AuthWrapper to decide
  /// whether to show a "session expired" SnackBar.
  bool _showExpiredMessage = false;

  // Google OAuth configuration
  static const String _googleAuthUrl =
      'https://accounts.google.com/o/oauth2/v2/auth';
  final String _googleClientId = '${dotenv.env['OAUTH_CLIENT_ID']}';
  final String _redirectUri = '${dotenv.env['API_BASE_URL']}/auth/callback';
  static const String _scopes = 'openid profile email';

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

  /// Start the Google OAuth flow:
  /// 1. Generate random state
  /// 2. Open Google consent in browser (redirect_uri → backend)
  /// 3. Poll backend for tokens using state
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Generate cryptographically random state
      final state = _generateState();

      // 2. Construct Google OAuth URL
      final authUrl = Uri.parse(_googleAuthUrl).replace(
        queryParameters: {
          'client_id': _googleClientId,
          'redirect_uri': _redirectUri,
          'scope': _scopes,
          'response_type': 'code',
          'state': state,
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );

      // 3. Open in external browser
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 4. Poll backend for tokens (every 1.5 seconds, max 5 minutes)
      final tokens = await _pollForTokens(state);
      if (tokens != null) {
        await ApiClient.saveTokens(
          tokens['access_token']!,
          tokens['refresh_token']!,
        );
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        unawaited(_invokeSignedInHook());
        return true;
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
    }

    _isLoggedIn = false;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Poll GET /auth/token?state=STATE every 1.5 seconds.
  /// Returns null if timeout (5 minutes).
  Future<Map<String, String>?> _pollForTokens(String state) async {
    // Use a separate Dio to avoid auth interceptor (these are unauthenticated requests)
    final pollDio = Dio(
      BaseOptions(
        baseUrl: _api.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    const maxAttempts = 200; // 200 * 1.5s = 5 minutes
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final response = await pollDio.get(
          '/auth/token',
          queryParameters: {'state': state},
        );
        if (response.statusCode == 200 &&
            response.data['access_token'] != null) {
          return {
            'access_token': response.data['access_token'] as String,
            'refresh_token': response.data['refresh_token'] as String,
          };
        }
        // 202 = still pending, continue polling
      } catch (_) {
        // Network error or other, continue polling
      }
    }
    return null; // Timeout
  }

  Future<void> signOut() async {
    // Fire the signed-out hook FIRST so any authed cleanup calls
    // (e.g. PushMessagingService.stop() → DELETE /api/devices/...)
    // complete before we wipe the access token. After clearTokens
    // runs those requests would 401.
    await _invokeSignedOutHook();

    // Best-effort backend cleanup: revoke Google tokens + clear DB rows.
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

  String _generateState() {
    // Cryptographically secure random state (UUID v4-like)
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
