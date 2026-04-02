import '../api_client.dart';
import '../models/activity.dart';

class ActivityApiService {
  final ApiClient _api;

  ActivityApiService(this._api);

  Future<Activity> startActivity(String type) async {
    final response = await _api.dio.post('/api/activities', data: {'type': type});
    return Activity.fromJson(response.data);
  }

  Future<Activity> addLocation(String activityId, LocationPointData point) async {
    final response = await _api.dio.post(
      '/api/activities/$activityId/location',
      data: point.toJson(),
    );
    return Activity.fromJson(response.data);
  }

  Future<Activity> addLocations(String activityId, List<LocationPointData> points) async {
    final response = await _api.dio.post(
      '/api/activities/$activityId/locations',
      data: points.map((p) => p.toJson()).toList(),
    );
    return Activity.fromJson(response.data);
  }

  Future<Activity> pauseActivity(String activityId) async {
    final response = await _api.dio.post('/api/activities/$activityId/pause');
    return Activity.fromJson(response.data);
  }

  Future<Activity> resumeActivity(String activityId) async {
    final response = await _api.dio.post('/api/activities/$activityId/resume');
    return Activity.fromJson(response.data);
  }

  Future<Activity> stopActivity(String activityId) async {
    final response = await _api.dio.post('/api/activities/$activityId/stop');
    return Activity.fromJson(response.data);
  }

  Future<List<ActivitySummary>> getAll() async {
    final response = await _api.dio.get('/api/activities');
    return (response.data as List).map((e) => ActivitySummary.fromJson(e)).toList();
  }

  Future<Activity> getById(String id) async {
    final response = await _api.dio.get('/api/activities/$id');
    return Activity.fromJson(response.data);
  }
}
