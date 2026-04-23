import '../api_client.dart';
import '../models/activity.dart';

/// Thin HTTP surface for activities. In the local-first flow the backend is
/// a dumb sink: mobile uploads a finalized payload and reads the history.
/// No per-point streaming, no start/pause/resume round-trips.
class ActivityApiService {
  final ApiClient _api;

  ActivityApiService(this._api);

  /// Upload a completed session. Returns the server-assigned id on success.
  Future<String> uploadActivity(ActivityUploadPayload payload) async {
    final response = await _api.dio.post(
      '/api/activities',
      data: payload.toJson(),
    );
    final data = response.data as Map<String, dynamic>;
    return data['id'].toString();
  }

  Future<List<ActivitySummary>> getAll() async {
    final response = await _api.dio.get('/api/activities');
    final list = response.data as List;
    return list
        .map((e) => ActivitySummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Activity> getById(String id) async {
    final response = await _api.dio.get('/api/activities/$id');
    return Activity.fromJson(response.data as Map<String, dynamic>);
  }
}
