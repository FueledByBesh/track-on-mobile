import 'package:dio/dio.dart';

import 'cache_store.dart';

/// Generic conditional-GET + cache-fallback helper used by every
/// service that wants to cache a backend resource.
///
/// Flow:
///   1. Look up a prior entry in [CacheStore] by [cacheKey].
///   2. Fire `GET [path]` with `If-None-Match: <etag>` if one is stored.
///   3. On `200`: replace the cache row with the new payload + ETag
///      header, return the parsed response as fresh.
///   4. On `304`: touch the cached row's `fetched_at` and return the
///      cached payload (decoded through [fromJson]).
///   5. On connection error (offline / timeout): fall back to the
///      cached payload if one exists; otherwise rethrow.
class CachedHttp {
  final Dio dio;
  final CacheStore store;

  CachedHttp({required this.dio, required this.store});

  /// Single-object version. [fromJson] is applied to whichever payload
  /// ends up winning (fresh body or cached body).
  Future<CachedResult<T>> getObject<T>({
    required String cacheKey,
    required String path,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _get<T>(
      cacheKey: cacheKey,
      path: path,
      queryParameters: queryParameters,
      decode: (body) => fromJson(body as Map<String, dynamic>),
      decodeCached: (e) => fromJson(e.decodeMap()),
    );
  }

  /// List version — for endpoints like `/follows/pending` or paged
  /// feeds. The full list is stored as one cache row.
  Future<CachedResult<List<T>>> getList<T>({
    required String cacheKey,
    required String path,
    required T Function(Map<String, dynamic>) itemFromJson,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _get<List<T>>(
      cacheKey: cacheKey,
      path: path,
      queryParameters: queryParameters,
      decode: (body) => (body as List)
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      decodeCached: (e) => e
          .decodeList()
          .map((x) => itemFromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<CachedResult<T>> _get<T>({
    required String cacheKey,
    required String path,
    required Map<String, dynamic>? queryParameters,
    required T Function(Object body) decode,
    required T Function(CachedEntry e) decodeCached,
  }) async {
    final cached = await store.read(cacheKey);

    try {
      final res = await dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: cached?.etag != null
              ? {'If-None-Match': cached!.etag!}
              : null,
          // Treat 304 as a success so Dio doesn't throw.
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );

      if (res.statusCode == 304 && cached != null) {
        await store.touch(cacheKey);
        return CachedResult(
          value: decodeCached(cached),
          source: CacheSource.notModified,
          fetchedAt: DateTime.now(),
        );
      }

      final etag = _headerValue(res.headers, 'etag');
      await store.write(
        key: cacheKey,
        payload: res.data,
        etag: etag,
      );
      return CachedResult(
        value: decode(res.data as Object),
        source: CacheSource.network,
        fetchedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      if (cached != null && _isConnectionError(e)) {
        return CachedResult(
          value: decodeCached(cached),
          source: CacheSource.offlineCache,
          fetchedAt: cached.fetchedAt,
        );
      }
      rethrow;
    }
  }

  bool _isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }

  String? _headerValue(Headers headers, String name) {
    final list = headers.map[name.toLowerCase()] ??
        headers.map[name] ??
        const <String>[];
    return list.isEmpty ? null : list.first;
  }
}

/// How a cache lookup was satisfied. Useful for debug overlays and
/// "last refreshed N minutes ago" UI.
enum CacheSource {
  /// 200 from the server — cache replaced with the fresh payload.
  network,

  /// 304 from the server — cached payload confirmed still current.
  notModified,

  /// No network; payload served from the last fetch.
  offlineCache,
}

class CachedResult<T> {
  final T value;
  final CacheSource source;
  final DateTime fetchedAt;

  const CachedResult({
    required this.value,
    required this.source,
    required this.fetchedAt,
  });

  bool get isStale => source == CacheSource.offlineCache;
}
