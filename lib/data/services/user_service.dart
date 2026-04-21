import '../api_client.dart';
import '../models/user.dart';
import '../models/user_settings.dart';

/// Transport wrapper around `/api/users/*` — profile CRUD + user
/// settings. Follow operations live on [FollowApiService].
class UserApiService {
  final ApiClient _api;

  UserApiService(this._api);

  // ============ PROFILE ============

  Future<UserProfile> getMe() async {
    final res = await _api.dio.get('/api/users/me');
    return UserProfile.fromJson(res.data);
  }

  Future<UserProfile> getById(String id) async {
    final res = await _api.dio.get('/api/users/$id');
    return UserProfile.fromJson(res.data);
  }

  Future<UserProfile> getByHandle(String handle) async {
    final normalized =
        handle.startsWith('@') ? handle.substring(1) : handle;
    final res = await _api.dio.get('/api/users/by-handle/$normalized');
    return UserProfile.fromJson(res.data);
  }

  /// Patch-style update. Pass only the fields the user touched.
  Future<UserProfile> updateMe({
    String? firstName,
    String? lastName,
    String? handle,
    String? bio,
    String? location,
    String? avatarImageUrl,
  }) async {
    final res = await _api.dio.patch('/api/users/me', data: {
      'first_name': ?firstName,
      'last_name': ?lastName,
      'handle': ?handle,
      'bio': ?bio,
      'location': ?location,
      'avatar_image_url': ?avatarImageUrl,
    });
    return UserProfile.fromJson(res.data);
  }

  // ============ SEARCH ============

  Future<List<UserSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final res = await _api.dio.get('/api/users/search',
        queryParameters: {'query': query});
    return (res.data as List)
        .map((e) => UserSearchResult.fromJson(e))
        .toList();
  }

  // ============ SETTINGS (self) ============

  Future<UserSettings> getMySettings() async {
    final res = await _api.dio.get('/api/users/me/settings');
    return UserSettings.fromJson(res.data);
  }

  Future<UserSettings> updateMySettings(Map<String, dynamic> patch) async {
    final res = await _api.dio.patch('/api/users/me/settings', data: patch);
    return UserSettings.fromJson(res.data);
  }
}
