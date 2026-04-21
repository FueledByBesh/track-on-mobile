import '../api_client.dart';
import '../models/follow.dart';
import '../models/user.dart';

/// Transport wrapper around the follow endpoints. The resulting
/// [FollowAction.status] drives mobile UI — null = deleted, PENDING =
/// awaiting approval, ACCEPTED = live follow.
class FollowApiService {
  final ApiClient _api;

  FollowApiService(this._api);

  // ============ WRITES ============

  Future<FollowAction> follow(String targetId) async {
    final res = await _api.dio.post('/api/follows/$targetId');
    return FollowAction.fromJson(res.data);
  }

  /// Unfollow or cancel a pending request. Both map to the same DELETE.
  Future<FollowAction> unfollow(String targetId) async {
    final res = await _api.dio.delete('/api/follows/$targetId');
    return FollowAction.fromJson(res.data);
  }

  Future<FollowAction> acceptRequest(String followerId) async {
    final res = await _api.dio
        .post('/api/follows/requests/$followerId/accept');
    return FollowAction.fromJson(res.data);
  }

  Future<FollowAction> rejectRequest(String followerId) async {
    final res = await _api.dio
        .post('/api/follows/requests/$followerId/reject');
    return FollowAction.fromJson(res.data);
  }

  // ============ READS ============

  /// Viewer's pending-follow inbox — the people waiting for them to
  /// accept. Drives the banner on the People tab.
  Future<List<UserPreview>> incomingRequests() async {
    final res = await _api.dio.get('/api/follows/requests/incoming');
    return (res.data as List)
        .map((e) => UserPreview.fromJson(e))
        .toList();
  }

  Future<List<UserPreview>> followersOf(String userId) async {
    final res = await _api.dio.get('/api/users/$userId/followers');
    return (res.data as List)
        .map((e) => UserPreview.fromJson(e))
        .toList();
  }

  Future<List<UserPreview>> followingOf(String userId) async {
    final res = await _api.dio.get('/api/users/$userId/following');
    return (res.data as List)
        .map((e) => UserPreview.fromJson(e))
        .toList();
  }
}
