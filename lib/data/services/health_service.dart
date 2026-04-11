import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HealthService {
  static const _channel = MethodChannel('com.trackon/health');
  static bool _authorized = false;
  static bool _available = false;
  static bool _checkedAvailability = false;

  /// Check if Health Connect is available on the device.
  static Future<bool> isAvailable() async {
    if (_checkedAvailability) return _available;
    _checkedAvailability = true;

    try {
      _available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      if (!_available) {
        debugPrint('Health Connect not available on this device.');
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
      _authorized =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
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
      _authorized = await _channel.invokeMethod<bool>('hasPermission') ?? false;
      return _authorized;
    } catch (e) {
      return false;
    }
  }

  /// Read step intervals from Health Connect.
  /// Returns raw intervals with original timezone info from the native side.
  static Future<List<RawStepInterval>> getSteps({
    required DateTime since,
  }) async {
    if (!await isAvailable()) return [];

    if (!_authorized) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        final granted = await requestPermission();
        if (!granted) return [];
      }
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSteps', {
        'since': since.toUtc().toIso8601String(),
      });

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return RawStepInterval(
          startTime: map['startTime'] as String,
          endTime: map['endTime'] as String,
          startTimeLocal: map['startTimeLocal'] as String,
          endTimeLocal: map['endTimeLocal'] as String,
          date: map['date'] as String,
          stepsValue: map['stepsValue'] as int,
          source: map['source'] as String,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error reading health data: $e');
      return [];
    }
  }
}

class RawStepInterval {
  /// UTC timestamp
  final String startTime;

  /// UTC timestamp
  final String endTime;

  /// Local timestamp with original timezone offset
  final String startTimeLocal;

  /// Local timestamp with original timezone offset
  final String endTimeLocal;

  /// Date in user's local timezone (YYYY-MM-DD)
  final String date;
  final int stepsValue;
  final String source;

  RawStepInterval({
    required this.startTime,
    required this.endTime,
    required this.startTimeLocal,
    required this.endTimeLocal,
    required this.date,
    required this.stepsValue,
    required this.source,
  });
}
