import '../api_client.dart';
import '../models/notification.dart';

class NotificationApiService {
  final ApiClient _api;

  NotificationApiService(this._api);

  Future<List<AppNotification>> getAll() async {
    final response = await _api.dio.get('/api/notifications');
    return (response.data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  /// Incremental delta fetch — returns rows created at or after
  /// [sinceIso]. Pair with the local cache to avoid redownloading the
  /// entire list on every page open.
  Future<List<AppNotification>> getSince(String sinceIso) async {
    final response = await _api.dio.get(
      '/api/notifications',
      queryParameters: {'since': sinceIso},
    );
    return (response.data as List)
        .map((e) => AppNotification.fromJson(e))
        .toList();
  }

  Future<List<AppNotification>> getUnread() async {
    final response = await _api.dio.get('/api/notifications/unread');
    return (response.data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _api.dio.get('/api/notifications/unread/count');
    return response.data['count'] ?? 0;
  }

  Future<AppNotification> markAsRead(String id) async {
    final response = await _api.dio.put('/api/notifications/$id/read');
    return AppNotification.fromJson(response.data);
  }

  Future<void> markAllAsRead() async {
    await _api.dio.put('/api/notifications/read-all');
  }

  Future<void> delete(String id) async {
    await _api.dio.delete('/api/notifications/$id');
  }
}
