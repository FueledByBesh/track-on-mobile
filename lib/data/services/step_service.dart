import '../api_client.dart';
import '../models/daily_steps.dart';

class StepApiService {
  final ApiClient _api;

  StepApiService(this._api);

  Future<void> syncSteps(
    List<StepInterval> intervals, {
    required String rangeStart,
    required String rangeEnd,
  }) async {
    await _api.dio.post(
      '/api/steps',
      data: {
        'range_start': rangeStart,
        'range_end': rangeEnd,
        'intervals': intervals.map((e) => e.toJson()).toList(),
      },
    );
  }

  Future<List<DailySteps>> getHistory(String from, String to) async {
    final response = await _api.dio.get(
      '/api/steps/history',
      queryParameters: {'from': from, 'to': to},
    );
    return (response.data as List).map((e) => DailySteps.fromJson(e)).toList();
  }

  Future<List<StepInterval>> getIntervals(String date) async {
    final response = await _api.dio.get(
      '/api/steps/intervals',
      queryParameters: {'date': date},
    );
    return (response.data as List)
        .map((e) => StepInterval.fromJson(e))
        .toList();
  }

  Future<DailySteps> updateGoal(int goal) async {
    final response = await _api.dio.put(
      '/api/steps/goal',
      data: {'goal': goal},
    );
    return DailySteps.fromJson(response.data);
  }
}
