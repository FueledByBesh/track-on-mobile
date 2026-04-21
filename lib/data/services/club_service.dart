import '../api_client.dart';
import '../models/club.dart';
import '../models/club_ban.dart';
import '../models/club_notification_prefs.dart';
import '../models/club_settings.dart';
import '../models/join_request.dart';
import '../models/ownership_transfer.dart';

/// Transport-layer wrapper around `/api/clubs/*`. Returns typed models;
/// no state, no caching — that lives in `GroupsProvider` and the pages
/// that need it. Write operations return the updated `Club` / response
/// where the backend does, so callers can merge without a refetch.
class ClubApiService {
  final ApiClient _api;

  ClubApiService(this._api);

  // ============ CRUD ============

  Future<Club> create({
    required String name,
    String? handle,
    String? description,
    String? location,
    List<String>? sportTypes,
    String? avatarImageUrl,
    bool? isPublic,
  }) async {
    final res = await _api.dio.post('/api/clubs', data: {
      'name': name,
      'handle': ?handle,
      'description': ?description,
      'location': ?location,
      'sport_types': ?sportTypes,
      'avatar_image_url': ?avatarImageUrl,
      'is_public': ?isPublic,
    });
    return Club.fromJson(res.data);
  }

  Future<Club> getById(String id) async {
    final res = await _api.dio.get('/api/clubs/$id');
    return Club.fromJson(res.data);
  }

  Future<Club> getByHandle(String handle) async {
    // Strip a leading @ for convenience — the UI displays it with the
    // symbol but the server wants the bare handle.
    final normalized =
        handle.startsWith('@') ? handle.substring(1) : handle;
    final res = await _api.dio.get('/api/clubs/by-handle/$normalized');
    return Club.fromJson(res.data);
  }

  /// Patch-style update. Pass only the fields the user touched.
  Future<Club> update(
    String id, {
    String? name,
    String? handle,
    String? description,
    String? location,
    List<String>? sportTypes,
    String? avatarImageUrl,
    bool? isPublic,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (handle != null) body['handle'] = handle;
    if (description != null) body['description'] = description;
    if (location != null) body['location'] = location;
    if (sportTypes != null) body['sport_types'] = sportTypes;
    if (avatarImageUrl != null) body['avatar_image_url'] = avatarImageUrl;
    if (isPublic != null) body['is_public'] = isPublic;
    final res = await _api.dio.patch('/api/clubs/$id', data: body);
    return Club.fromJson(res.data);
  }

  Future<void> delete(String id) async {
    await _api.dio.delete('/api/clubs/$id');
  }

  // ============ DISCOVERY ============

  /// Grouped "my clubs" — owned / admin / member sections for the tab.
  Future<MyClubs> getMine() async {
    final res = await _api.dio.get('/api/clubs/mine');
    return MyClubs.fromJson(res.data);
  }

  /// Substring search across name + handle. Empty query returns [].
  Future<List<Club>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final res = await _api.dio.get('/api/clubs/search',
        queryParameters: {'q': query});
    return (res.data as List).map((e) => Club.fromJson(e)).toList();
  }

  // ============ MEMBERSHIP ============

  /// Direct join (public clubs only). For private clubs use
  /// [requestJoin] — this endpoint returns 400 if called on a private club.
  Future<Club> joinPublic(String clubId) async {
    final res = await _api.dio.post('/api/clubs/$clubId/join');
    return Club.fromJson(res.data);
  }

  Future<void> leave(String clubId) async {
    await _api.dio.post('/api/clubs/$clubId/leave');
  }

  Future<List<ClubMember>> getMembers(String clubId) async {
    final res = await _api.dio.get('/api/clubs/$clubId/members');
    return (res.data as List).map((e) => ClubMember.fromJson(e)).toList();
  }

  // ============ ROLE MANAGEMENT (owner-only) ============

  Future<ClubMember> promote(String clubId, String userId) async {
    final res = await _api.dio
        .post('/api/clubs/$clubId/members/$userId/promote');
    return ClubMember.fromJson(res.data);
  }

  Future<ClubMember> demote(String clubId, String userId) async {
    final res = await _api.dio
        .post('/api/clubs/$clubId/members/$userId/demote');
    return ClubMember.fromJson(res.data);
  }

  /// Kick (not ban — they can rejoin unless also banned). Permissioned
  /// by `ClubSettings.whoCanRemoveMembers`.
  Future<void> removeMember(String clubId, String userId) async {
    await _api.dio.delete('/api/clubs/$clubId/members/$userId');
  }

  // ============ JOIN REQUESTS (private clubs) ============

  /// Submit a pending request. If the club has
  /// `allowJoinWithoutRequest`, the server creates the membership
  /// directly and returns a synthetic APPROVED response.
  Future<JoinRequest> requestJoin(String clubId) async {
    final res = await _api.dio.post('/api/clubs/$clubId/join-requests');
    return JoinRequest.fromJson(res.data);
  }

  /// Withdraw the viewer's own pending request.
  Future<void> cancelMyJoinRequest(String clubId) async {
    await _api.dio.delete('/api/clubs/$clubId/join-requests/mine');
  }

  Future<List<JoinRequest>> listPendingJoinRequests(String clubId) async {
    final res = await _api.dio.get('/api/clubs/$clubId/join-requests');
    return (res.data as List).map((e) => JoinRequest.fromJson(e)).toList();
  }

  Future<JoinRequest> approveJoinRequest(String clubId, String reqId) async {
    final res = await _api.dio
        .post('/api/clubs/$clubId/join-requests/$reqId/approve');
    return JoinRequest.fromJson(res.data);
  }

  Future<JoinRequest> rejectJoinRequest(String clubId, String reqId) async {
    final res = await _api.dio
        .post('/api/clubs/$clubId/join-requests/$reqId/reject');
    return JoinRequest.fromJson(res.data);
  }

  // ============ BANS ============

  Future<ClubBan> ban(
    String clubId, {
    required String userId,
    DateTime? bannedUntil,
    String? reason,
  }) async {
    final res = await _api.dio.post('/api/clubs/$clubId/bans', data: {
      'user_id': userId,
      'banned_until': ?bannedUntil?.toIso8601String(),
      'reason': ?reason,
    });
    return ClubBan.fromJson(res.data);
  }

  Future<List<ClubBan>> listBans(String clubId) async {
    final res = await _api.dio.get('/api/clubs/$clubId/bans');
    return (res.data as List).map((e) => ClubBan.fromJson(e)).toList();
  }

  Future<ClubBan> liftBan(String clubId, String banId) async {
    final res = await _api.dio.post('/api/clubs/$clubId/bans/$banId/lift');
    return ClubBan.fromJson(res.data);
  }

  // ============ OWNERSHIP TRANSFER ============

  Future<OwnershipTransfer> initiateTransfer(
      String clubId, String toUserId) async {
    final res = await _api.dio.post(
      '/api/clubs/$clubId/ownership-transfers',
      data: {'to_user_id': toUserId},
    );
    return OwnershipTransfer.fromJson(res.data);
  }

  Future<OwnershipTransfer> cancelTransfer(String clubId) async {
    final res = await _api.dio
        .delete('/api/clubs/$clubId/ownership-transfers/current');
    return OwnershipTransfer.fromJson(res.data);
  }

  Future<OwnershipTransfer> acceptTransfer(String clubId) async {
    final res = await _api.dio
        .post('/api/clubs/$clubId/ownership-transfers/current/accept');
    return OwnershipTransfer.fromJson(res.data);
  }

  Future<OwnershipTransfer> declineTransfer(String clubId) async {
    final res = await _api.dio
        .post('/api/clubs/$clubId/ownership-transfers/current/decline');
    return OwnershipTransfer.fromJson(res.data);
  }

  /// User's inbox — pending transfers addressed to them.
  Future<List<OwnershipTransfer>> incomingTransfers() async {
    final res =
        await _api.dio.get('/api/clubs/ownership-transfers/incoming');
    return (res.data as List)
        .map((e) => OwnershipTransfer.fromJson(e))
        .toList();
  }

  // ============ SETTINGS ============

  Future<ClubSettings> getSettings(String clubId) async {
    final res = await _api.dio.get('/api/clubs/$clubId/settings');
    return ClubSettings.fromJson(res.data);
  }

  /// Pre-built patch body from [ClubSettings.patch]. Anything you pass
  /// that isn't null gets written; everything else is untouched.
  Future<ClubSettings> updateSettings(
      String clubId, Map<String, dynamic> patch) async {
    final res =
        await _api.dio.put('/api/clubs/$clubId/settings', data: patch);
    return ClubSettings.fromJson(res.data);
  }

  // ============ NOTIFICATION PREFS ============

  Future<ClubNotificationPrefs> getNotificationPrefs(String clubId) async {
    final res = await _api.dio.get('/api/clubs/$clubId/notifications/prefs');
    return ClubNotificationPrefs.fromJson(res.data);
  }

  Future<ClubNotificationPrefs> updateNotificationPrefs(
      String clubId, Map<String, dynamic> patch) async {
    final res = await _api.dio
        .put('/api/clubs/$clubId/notifications/prefs', data: patch);
    return ClubNotificationPrefs.fromJson(res.data);
  }

  // ============ CHALLENGES (existing — unchanged) ============

  Future<List<Challenge>> getActiveChallenges(String clubId) async {
    final res = await _api.dio.get('/api/clubs/$clubId/challenges');
    return (res.data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<Challenge> subscribeChallenge(String challengeId) async {
    final res = await _api.dio
        .post('/api/clubs/challenges/$challengeId/subscribe');
    return Challenge.fromJson(res.data);
  }

  Future<void> unsubscribeChallenge(String challengeId) async {
    await _api.dio.post('/api/clubs/challenges/$challengeId/unsubscribe');
  }
}
