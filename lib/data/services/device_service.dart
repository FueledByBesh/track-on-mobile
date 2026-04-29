import '../api_client.dart';

/// Thin HTTP wrapper for `/api/devices/*` — register and unregister
/// FCM push tokens with the backend.
///
/// Register is idempotent on the server (upsert by token) so it's
/// safe to call repeatedly — e.g. every sign-in and on every
/// `FirebaseMessaging.onTokenRefresh` event. Unregister is also
/// idempotent (DELETE by token, no 404 on missing).
class DeviceApiService {
  final ApiClient _api;

  DeviceApiService(this._api);

  Future<void> register({
    required String fcmToken,
    required String platform,
  }) async {
    // Backend has `spring.jackson.property-naming-strategy: SNAKE_CASE`,
    // so the JSON key must be `fcm_token` even though the Java
    // record field is `fcmToken`.
    await _api.dio.post('/api/devices/register', data: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> unregister(String fcmToken) async {
    await _api.dio.delete('/api/devices/$fcmToken');
  }
}
