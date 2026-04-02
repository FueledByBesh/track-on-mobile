import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _baseUrl = 'http://10.0.2.2:8080'; // Android emulator -> localhost
  static const String _tokenKey = 'auth_session_cookie';

  late final Dio dio;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final cookie = prefs.getString(_tokenKey);
        if (cookie != null) {
          options.headers['Cookie'] = cookie;
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // Save session cookie from response
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, setCookie.first.split(';').first);
        }
        handler.next(response);
      },
    ));
  }

  static Future<void> saveSessionCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, cookie);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }
}
