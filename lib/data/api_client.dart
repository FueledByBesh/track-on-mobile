import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl =
      'http://10.227.91.236:8080'; // Android emulator -> host localhost
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const _storage = FlutterSecureStorage();

  late final Dio dio;

  // Separate Dio for refresh requests (avoids interceptor loop)
  late final Dio _refreshDio;

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
          final token = await getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Auto-refresh on 401
          if (error.response?.statusCode == 401) {
            try {
              final refreshed = await _tryRefresh();
              if (refreshed) {
                // Retry the original request with new token
                final token = await getAccessToken();
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $token';
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              }
            } catch (_) {
              // Refresh failed, clear tokens
              await clearTokens();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        await saveTokens(
          response.data['accessToken'],
          response.data['refreshToken'],
        );
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }
    return false;
  }

  // Token storage methods

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
