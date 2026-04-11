import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  // Google OAuth configuration
  static const String _googleAuthUrl =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _googleClientId =
      '120620645123-siv1rdhmjvfqf30qest8cokvaj2794rl.apps.googleusercontent.com';
  static const String _redirectUri = '${ApiClient.baseUrl}/auth/callback';
  static const String _scopes = 'openid profile email';

  AuthProvider(this._api);

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  /// Check if we have valid tokens on app startup.
  /// The Dio interceptor auto-refreshes on 401, so a single test request is enough:
  /// - Access token valid → 200 → logged in
  /// - Access token expired → interceptor refreshes → retries → 200 → logged in
  /// - Refresh also fails → interceptor clears tokens → throws → catch → logged out
  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final hasTokens = await ApiClient.hasTokens();
    if (hasTokens) {
      try {
        await _api.dio.get('/api/steps/last-sync');
        _isLoggedIn = true;
      } catch (_) {
        // Both access and refresh tokens are invalid/expired
        await ApiClient.clearTokens();
        debugPrint("Tokens cleared");
        _isLoggedIn = false;
      }
    }

    _isLoading = false;
    notifyListeners();
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
        baseUrl: ApiClient.baseUrl,
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
