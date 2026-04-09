import 'package:flutter/material.dart';
import 'package:health/health.dart';

class HealthService {
  static final Health _health = Health();
  static bool _authorized = false;

  /// Request permission to read step data.
  static Future<bool> requestPermission() async {
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    try {
      _authorized = await _health.requestAuthorization(types, permissions: permissions);
      return _authorized;
    } catch (e) {
      debugPrint('Health permission error: $e');
      return false;
    }
  }

  static bool get isAuthorized => _authorized;

  /// Check if Health Connect / HealthKit is available.
  static Future<bool> isAvailable() async {
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      // iOS doesn't have getHealthConnectSdkStatus, but HealthKit is always available
      return true;
    }
  }

  /// Read step intervals from Health Connect/HealthKit.
  /// Returns raw intervals with start, end, value, source.
  static Future<List<RawStepInterval>> getSteps({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_authorized) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    try {
      final dataPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: from,
        endTime: to,
      );

      return dataPoints.map((dp) {
        final steps = dp.value is NumericHealthValue
            ? (dp.value as NumericHealthValue).numericValue.toInt()
            : 0;
        return RawStepInterval(
          startTime: dp.dateFrom,
          endTime: dp.dateTo,
          stepsValue: steps,
          source: dp.sourceName,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error reading health data: $e');
      return [];
    }
  }
}

class RawStepInterval {
  final DateTime startTime;
  final DateTime endTime;
  final int stepsValue;
  final String source;

  RawStepInterval({
    required this.startTime,
    required this.endTime,
    required this.stepsValue,
    required this.source,
  });

  String get date => startTime.toIso8601String().split('T')[0];
}
