import '../api_client.dart';
import '../models/club.dart';

class ClubApiService {
  final ApiClient _api;

  ClubApiService(this._api);

  Future<Club> create(String name, String? description) async {
    final response = await _api.dio.post('/api/clubs', data: {
      'name': name,
      'description': description,
    });
    return Club.fromJson(response.data);
  }

  Future<List<Club>> search(String query) async {
    final response = await _api.dio.get('/api/clubs/search', queryParameters: {'query': query});
    return (response.data as List).map((e) => Club.fromJson(e)).toList();
  }

  Future<List<Club>> getMyClubs() async {
    final response = await _api.dio.get('/api/clubs/my');
    return (response.data as List).map((e) => Club.fromJson(e)).toList();
  }

  Future<Club> getById(String id) async {
    final response = await _api.dio.get('/api/clubs/$id');
    return Club.fromJson(response.data);
  }

  Future<Club> join(String clubId) async {
    final response = await _api.dio.post('/api/clubs/$clubId/join');
    return Club.fromJson(response.data);
  }

  Future<void> leave(String clubId) async {
    await _api.dio.post('/api/clubs/$clubId/leave');
  }

  Future<List<ClubMember>> getMembers(String clubId) async {
    final response = await _api.dio.get('/api/clubs/$clubId/members');
    return (response.data as List).map((e) => ClubMember.fromJson(e)).toList();
  }

  Future<List<Challenge>> getActiveChallenges(String clubId) async {
    final response = await _api.dio.get('/api/clubs/$clubId/challenges');
    return (response.data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<Challenge> subscribeChallenge(String challengeId) async {
    final response = await _api.dio.post('/api/clubs/challenges/$challengeId/subscribe');
    return Challenge.fromJson(response.data);
  }

  Future<void> unsubscribeChallenge(String challengeId) async {
    await _api.dio.post('/api/clubs/challenges/$challengeId/unsubscribe');
  }
}
