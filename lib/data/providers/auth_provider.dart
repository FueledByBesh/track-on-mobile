import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api_client.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  UserProfile? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  AuthProvider(this._api);

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final hasSession = await ApiClient.hasSession();
    if (hasSession) {
      try {
        final response = await _api.dio.get('/user/info');
        _user = UserProfile.fromJson(response.data);
        _isLoggedIn = true;
      } catch (_) {
        _isLoggedIn = false;
        await ApiClient.clearSession();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Use the Google OAuth flow through the backend
      // The backend uses session-based auth with OAuth2
      final auth = await account.authentication;
      if (auth.accessToken != null) {
        // Exchange with backend - send the access token
        final response = await _api.dio.get('/user/info');
        _user = UserProfile.fromJson(response.data);
        _isLoggedIn = true;
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      _isLoggedIn = false;
    }

    _isLoading = false;
    notifyListeners();
    return _isLoggedIn;
  }

  Future<void> signOut() async {
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
    await ApiClient.clearSession();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
