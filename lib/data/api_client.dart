import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'providers/connectivity_provider.dart';

class ApiClient {
  static const String baseUrl = 'http://track-on.duckdns.org:8080';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const _storage = FlutterSecureStorage();

  late final Dio dio;
  late final Dio _refreshDio;

  Completer<bool>? _refreshCompleter;

  // Set after providers are created in main.dart
  ConnectivityProvider? connectivityProvider;

  /// Called by the interceptor when it has definitively given up on the stored
  /// tokens (refresh rejected by backend, tokens cleared from secure storage).
  /// AuthProvider wires this so the UI can react immediately instead of
  /// limping along with a silent-dead session.
  VoidCallback? onAuthExpired;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _refreshDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Short-circuit if offline — don't waste battery on doomed requests
          if (connectivityProvider != null && !connectivityProvider!.isOnline) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Offline — request blocked',
              ),
            );
          }

          final token = await getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Detect connection errors and report to ConnectivityProvider
          if (_isConnectionError(error)) {
            connectivityProvider?.reportConnectionError();
            return handler.next(error);
          }

          // Auto-refresh on 401
          if (error.response?.statusCode != 401) {
            return handler.next(error);
          }

          try {
            final refreshed = await tryRefresh();
            if (!refreshed) {
              await clearTokens();
              onAuthExpired?.call();
              return handler.next(error);
            }

            final token = await getAccessToken();
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            final response = await _refreshDio.fetch(opts);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            // The retry itself returned another 401 — the refresh token must
            // have been bogus after all, even though tryRefresh() said it
            // worked. Real auth failure: clear + logout.
            if (retryError.response?.statusCode == 401) {
              await clearTokens();
              onAuthExpired?.call();
              return handler.next(retryError);
            }
            // Any other status from the retry (400 validation, 500 backend
            // bug, connection drop, etc.) is NOT an auth problem. Let it
            // bubble up to the caller as a normal error — do not blow away
            // the user's session for it.
            return handler.next(retryError);
          } catch (_) {
            // Non-Dio exception during the retry path (JSON parse, etc.).
            // Also not an auth failure — just forward the original error.
            return handler.next(error);
          }
        },
      ),
    );
  }

  bool _isConnectionError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  Future<bool> tryRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await saveTokens(
          response.data['access_token'],
          response.data['refresh_token'],
        );
        _refreshCompleter!.complete(true);
        return true;
      }

      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  static Future<bool> hasTokens() async {
    final token = await _storage.read(key: _accessTokenKey);
    return token != null;
  }
}
