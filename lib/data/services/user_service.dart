import '../api_client.dart';
import '../models/user.dart';
import '../models/user_activity_stats.dart';
import '../models/user_settings.dart';
import 'cache_store.dart';
import 'cached_http.dart';

/// Transport wrapper around `/api/users/*` — profile CRUD, stats,
/// and settings. Follow operations live on [FollowApiService].
///
/// Profile reads go through [CachedHttp] with an `If-None-Match`
/// conditional GET so repeat reads return 304 on the wire. Stats
/// reads use the same cached path — the payload hash changes whenever
/// a count flips so the cache invalidates naturally, and if offline
/// the last-known counts are still rendered.
class UserApiService {
  final ApiClient _api;
  final CachedHttp _cached;
  final CacheStore _store;

  UserApiService(this._api, this._cached, this._store);

  // ============ CACHE KEYS ============

  static const String _selfProfileKey = 'user:me';
  static const String _selfStatsKey = 'user-stats:me';

  static String _profileKey(String id) => 'user:$id';
  static String _statsKey(String id) => 'user-stats:$id';
  static String _handleKey(String handle) => 'user:handle:$handle';
  static String _handleStatsKey(String handle) => 'user-stats:handle:$handle';

  // ============ PROFILE CORE ============

  Future<UserProfile> getMe() async {
    final res = await _cached.getObject<UserProfile>(
      cacheKey: _selfProfileKey,
      path: '/api/users/me',
      fromJson: UserProfile.fromJson,
    );
    return res.value;
  }

  Future<UserProfile> getById(String id) async {
    final res = await _cached.getObject<UserProfile>(
      cacheKey: _profileKey(id),
      path: '/api/users/$id',
      fromJson: UserProfile.fromJson,
    );
    return res.value;
  }

  Future<UserProfile> getByHandle(String handle) async {
    final normalized =
        handle.startsWith('@') ? handle.substring(1) : handle;
    final res = await _cached.getObject<UserProfile>(
      cacheKey: _handleKey(normalized),
      path: '/api/users/by-handle/$normalized',
      fromJson: UserProfile.fromJson,
    );
    return res.value;
  }

  // ============ STATS ============

  Future<UserStats> getMyStats() async {
    final res = await _cached.getObject<UserStats>(
      cacheKey: _selfStatsKey,
      path: '/api/users/me/stats',
      fromJson: UserStats.fromJson,
    );
    return res.value;
  }

  Future<UserStats> getStatsById(String id) async {
    final res = await _cached.getObject<UserStats>(
      cacheKey: _statsKey(id),
      path: '/api/users/$id/stats',
      fromJson: UserStats.fromJson,
    );
    return res.value;
  }

  Future<UserStats> getStatsByHandle(String handle) async {
    final normalized =
        handle.startsWith('@') ? handle.substring(1) : handle;
    final res = await _cached.getObject<UserStats>(
      cacheKey: _handleStatsKey(normalized),
      path: '/api/users/by-handle/$normalized/stats',
      fromJson: UserStats.fromJson,
    );
    return res.value;
  }

  // ============ ACTIVITY STATS (profile tab) ============

  /// Aggregate activity summary for the profile's Activity tab.
  /// Not cached — it's a derived view that the user expects to be
  /// current, and server-side it's just three cheap SUM queries.
  Future<UserActivityStats> getMyActivityStats({int days = 30}) async {
    final res = await _api.dio.get(
      '/api/users/me/activity-stats',
      queryParameters: {'days': days},
    );
    return UserActivityStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserActivityStats> getActivityStatsById(
    String userId, {
    int days = 30,
  }) async {
    final res = await _api.dio.get(
      '/api/users/$userId/activity-stats',
      queryParameters: {'days': days},
    );
    return UserActivityStats.fromJson(res.data as Map<String, dynamic>);
  }

  // ============ UPDATE (self) ============

  /// Patch-style update. Pass only the fields the user touched.
  /// Invalidates both the `user:me` and `user:{id}` cache entries,
  /// plus any `user:handle:*` rows (old or new handle) so subsequent
  /// reads re-fetch the fresh row.
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
    final profile = UserProfile.fromJson(res.data);
    await _invalidateProfileCache(profile.id);
    return profile;
  }

  Future<void> _invalidateProfileCache(String userId) async {
    await _store.remove(_selfProfileKey);
    await _store.remove(_profileKey(userId));
    await _store.removeByPrefix('user:handle:');
  }

  /// Clear the current user's avatar — both the stored column on the
  /// server and the bucket object. Idempotent. Also invalidates the
  /// profile cache so the next read returns the nulled state.
  Future<UserProfile> removeAvatar() async {
    final res = await _api.dio.delete('/api/users/me/avatar');
    final profile = UserProfile.fromJson(res.data);
    await _invalidateProfileCache(profile.id);
    return profile;
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
    final settings = UserSettings.fromJson(res.data);
    // `is_profile_public` is rendered on the profile core payload, but
    // the server's profile ETag is driven by `users.updated_at` only —
    // flipping a settings row doesn't bump it, so a subsequent
    // `If-None-Match` would return 304 with the stale privacy flag.
    // Drop the cached profile rows so the next read refetches.
    await _store.remove(_selfProfileKey);
    await _store.removeByPrefix('user:handle:');
    return settings;
  }
}
