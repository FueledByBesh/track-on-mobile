import '../api_client.dart';
import '../models/friendship.dart';
import '../models/user.dart';

class FriendshipApiService {
  final ApiClient _api;

  FriendshipApiService(this._api);

  Future<List<Friendship>> getFriends() async {
    final response = await _api.dio.get('/api/friends');
    return (response.data as List).map((e) => Friendship.fromJson(e)).toList();
  }

  Future<Friendship> sendRequest(String email) async {
    final response = await _api.dio.post('/api/friends/request', data: {'email': email});
    return Friendship.fromJson(response.data);
  }

  Future<Friendship> acceptRequest(String friendshipId) async {
    final response = await _api.dio.post('/api/friends/$friendshipId/accept');
    return Friendship.fromJson(response.data);
  }

  Future<Friendship> rejectRequest(String friendshipId) async {
    final response = await _api.dio.post('/api/friends/$friendshipId/reject');
    return Friendship.fromJson(response.data);
  }

  Future<void> removeFriend(String friendshipId) async {
    await _api.dio.delete('/api/friends/$friendshipId');
  }

  Future<List<Friendship>> getIncomingRequests() async {
    final response = await _api.dio.get('/api/friends/requests/incoming');
    return (response.data as List).map((e) => Friendship.fromJson(e)).toList();
  }

  Future<List<Friendship>> getOutgoingRequests() async {
    final response = await _api.dio.get('/api/friends/requests/outgoing');
    return (response.data as List).map((e) => Friendship.fromJson(e)).toList();
  }

  Future<List<FriendSteps>> getFriendsStepsToday() async {
    final response = await _api.dio.get('/api/friends/steps/today');
    return (response.data as List).map((e) => FriendSteps.fromJson(e)).toList();
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final response = await _api.dio.get('/api/users/search', queryParameters: {'query': query});
    return (response.data as List).map((e) => UserSearchResult.fromJson(e)).toList();
  }
}
