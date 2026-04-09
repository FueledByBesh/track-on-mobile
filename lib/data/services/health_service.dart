import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

class HealthService {
  static final Health _health = Health();
  static bool _authorized = false;
  static bool _available = false;
  static bool _checkedAvailability = false;

  /// Check if Health Connect (Android) or HealthKit (iOS) is available.
  static Future<bool> isAvailable() async {
    if (_checkedAvailability) return _available;
    _checkedAvailability = true;

    try {
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        _available = status == HealthConnectSdkStatus.sdkAvailable;
        if (!_available) {
          debugPrint('Health Connect not available. Status: $status');
          debugPrint('Health Connect may need to be installed from Play Store.');
        }
      } else {
        // HealthKit is always available on iOS
        _available = true;
      }
    } catch (e) {
      debugPrint('Error checking health availability: $e');
      _available = false;
    }

    return _available;
  }

  /// Request permission to read step data.
  static Future<bool> requestPermission() async {
    if (!await isAvailable()) return false;

    try {
      _authorized = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
      return _authorized;
    } catch (e) {
      debugPrint('Health permission error: $e');
      return false;
    }
  }

  static bool get isAuthorized => _authorized;

  /// Check if permissions are already granted (without prompting).
  static Future<bool> hasPermissions() async {
    if (!await isAvailable()) return false;
    try {
      final result = await _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
      _authorized = result ?? false;
      return _authorized;
    } catch (e) {
      return false;
    }
  }

  /// Read step intervals from Health Connect/HealthKit.
  static Future<List<RawStepInterval>> getSteps({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!await isAvailable()) return [];

    if (!_authorized) {
      // Check if already granted before prompting
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        final granted = await requestPermission();
        if (!granted) return [];
      }
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
