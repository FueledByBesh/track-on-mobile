import 'dart:convert';

import '../local/cache_database.dart';

/// Typed view over [CacheDatabase]. Services go through this instead
/// of touching rows directly so the encoding/decoding of the payload
/// column lives in one place.
class CacheStore {
  /// Read a cached entry. Returns `null` if we've never fetched this key.
  Future<CachedEntry?> read(String key) async {
    final row = await CacheDatabase.get(key);
    if (row == null) return null;
    return CachedEntry(
      key: row['key'] as String,
      payloadJson: row['payload'] as String,
      etag: row['etag'] as String?,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        row['fetched_at'] as int,
      ),
    );
  }

  /// Store a fresh payload + ETag. Overwrites any prior row with the
  /// same key.
  Future<void> write({
    required String key,
    required Object payload,
    String? etag,
  }) async {
    await CacheDatabase.put(
      key: key,
      payload: payload is String ? payload : jsonEncode(payload),
      etag: etag,
      fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Bump the freshness timestamp on an already-cached entry — used
  /// after a 304 response confirms the payload is still current.
  Future<void> touch(String key) async {
    await CacheDatabase.touchFetchedAt(
      key,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> remove(String key) => CacheDatabase.remove(key);

  Future<int> removeByPrefix(String prefix) =>
      CacheDatabase.removeByPrefix(prefix);

  /// Wipe the entire cache. Call on sign-out so the next user doesn't
  /// inherit the previous session's data.
  Future<void> clear() => CacheDatabase.clear();
}

/// Parsed cache row. Callers typically pass `payloadJson` through a
/// `fromJson` factory rather than working with the raw string.
class CachedEntry {
  final String key;
  final String payloadJson;
  final String? etag;
  final DateTime fetchedAt;

  const CachedEntry({
    required this.key,
    required this.payloadJson,
    required this.etag,
    required this.fetchedAt,
  });

  /// Decoded payload as a `Map<String, dynamic>` — the common shape
  /// for single-object endpoints (profile, stats, settings).
  Map<String, dynamic> decodeMap() =>
      jsonDecode(payloadJson) as Map<String, dynamic>;

  /// Decoded payload as a `List` — for endpoints that return arrays.
  List<dynamic> decodeList() => jsonDecode(payloadJson) as List<dynamic>;
}
