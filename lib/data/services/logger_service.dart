import 'dart:async';
import 'package:flutter/foundation.dart';
import '../local/logger_database.dart';

/// Log severity. Single-letter codes match what's stored in the DB for
/// compactness; the UI maps them to pretty labels and colors.
enum LogLevel {
  debug('D'),
  info('I'),
  warn('W'),
  error('E');

  final String code;
  const LogLevel(this.code);

  static LogLevel fromCode(String c) {
    switch (c) {
      case 'D':
        return LogLevel.debug;
      case 'I':
        return LogLevel.info;
      case 'W':
        return LogLevel.warn;
      case 'E':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// One log line, either sitting in the memory buffer or read from the DB.
class LogEntry {
  final int? id;
  final int timestampMs;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry({
    this.id,
    required this.timestampMs,
    required this.level,
    required this.tag,
    required this.message,
  });

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(timestampMs);

  Map<String, Object?> toRow() => {
        'timestamp_ms': timestampMs,
        'level': level.code,
        'tag': tag,
        'message': message,
      };

  static LogEntry fromRow(Map<String, Object?> row) => LogEntry(
        id: row['id'] as int?,
        timestampMs: row['timestamp_ms'] as int,
        level: LogLevel.fromCode(row['level'] as String),
        tag: row['tag'] as String,
        message: row['message'] as String,
      );
}

/// Batched writer. Every `log(...)` call enqueues into a memory buffer
/// and schedules a debounced flush; the flush performs one transactional
/// insert of all buffered rows. At steady state with ~20 calls/sec this
/// becomes one SQLite write per flush interval instead of 20.
///
/// Also fans out to debugPrint so tethered-laptop sessions still work.
class LoggerService {
  static LoggerService? _instance;
  static LoggerService get instance =>
      _instance ??= LoggerService._();
  LoggerService._();

  final List<LogEntry> _buffer = [];
  Timer? _flushTimer;
  static const Duration _flushInterval = Duration(milliseconds: 500);

  void log(LogLevel level, String tag, String message) {
    final entry = LogEntry(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      level: level,
      tag: tag,
      message: message,
    );
    _buffer.add(entry);
    // Always echo to debugPrint too — free visibility when tethered.
    debugPrint('[${level.code}/$tag] $message');
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, _flush);
  }

  Future<void> _flush() async {
    _flushTimer = null;
    if (_buffer.isEmpty) return;
    final toWrite = List<LogEntry>.from(_buffer);
    _buffer.clear();
    try {
      await LoggerDatabase.insertBatch(toWrite.map((e) => e.toRow()).toList());
    } catch (e) {
      // Don't let a logger failure break the app. Just drop the batch
      // and echo the error to debugPrint.
      debugPrint('LoggerService flush failed: $e');
    }
  }

  /// Force a flush now. Useful before reading logs for display, so the
  /// UI never misses the last few entries that were still in the buffer.
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flush();
  }

  Future<List<LogEntry>> readAll({int limit = 2000}) async {
    await flushNow();
    final rows = await LoggerDatabase.getAll(limit: limit);
    return rows.map(LogEntry.fromRow).toList();
  }

  Future<void> clear() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    await LoggerDatabase.truncate();
  }
}

/// One-line ergonomic API. Call from anywhere:
///   Logger.d('GPS', 'pos acc=${p.accuracy}');
///   Logger.i('REC', 'Activity started id=$id');
///   Logger.w('AUTH', 'Refresh token rejected');
///   Logger.e('DB', 'Insert failed', e);
class Logger {
  Logger._();

  static void d(String tag, String message) =>
      LoggerService.instance.log(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      LoggerService.instance.log(LogLevel.info, tag, message);

  static void w(String tag, String message) =>
      LoggerService.instance.log(LogLevel.warn, tag, message);

  static void e(String tag, String message, [Object? err, StackTrace? st]) {
    final full = err != null ? '$message — $err' : message;
    LoggerService.instance.log(LogLevel.error, tag, full);
    if (st != null) {
      LoggerService.instance.log(LogLevel.error, tag, st.toString());
    }
  }
}
