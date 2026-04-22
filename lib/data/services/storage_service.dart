import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_client.dart';

/// Mobile-side broker for direct-to-GCS uploads.
///
/// The flow is always two hops:
///   1. [requestUploadUrl] — ask the backend for a signed PUT URL +
///      object path + (for public kinds) a stable public URL.
///   2. [uploadBytes] — PUT the bytes straight to GCS with the exact
///      content-type declared in step 1.
///
/// For public kinds like avatars, the caller then stores the returned
/// [UploadPlan.publicUrl] on the user record via
/// `UserApiService.updateMe(avatarImageUrl: ...)`. Private kinds store
/// [UploadPlan.objectPath] instead and ask the server for a signed GET
/// on read.
class StorageApiService {
  final ApiClient _api;

  /// Separate Dio client for the raw PUT to GCS. We can't use the
  /// authenticated [_api.dio] here because that instance attaches a
  /// `Bearer` token on every request; sending it to GCS is both
  /// wasteful and interferes with the signed URL auth model.
  late final Dio _rawDio;

  StorageApiService(this._api) {
    _rawDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Ask the server to pick an object path and sign a PUT URL for the
  /// given [kind]. Returns everything the client needs to complete
  /// the upload + store the resulting reference.
  Future<UploadPlan> requestUploadUrl({
    required String kind,
    required String contentType,
  }) async {
    final res = await _api.dio.post('/api/storage/uploads', data: {
      'kind': kind,
      'content_type': contentType,
    });
    return UploadPlan.fromJson(res.data);
  }

  /// Upload [bytes] to [plan.putUrl] via HTTP PUT. The Content-Type
  /// header MUST match the one originally passed to
  /// [requestUploadUrl] or GCS will reject the signature.
  ///
  /// Throws on any non-2xx response. On success, the object is
  /// written to the bucket; the caller must still persist
  /// [UploadPlan.publicUrl] / [UploadPlan.objectPath] server-side.
  Future<void> uploadBytes({
    required UploadPlan plan,
    required Uint8List bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _rawDio.put(
      plan.putUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
      ),
      onSendProgress: onProgress,
    );
  }
}

/// Parsed {@code POST /api/storage/uploads} response.
class UploadPlan {
  /// Signed PUT URL — short TTL (15 min by default), single use.
  final String putUrl;

  /// Server-chosen object key in the bucket.
  final String objectPath;

  /// Stable direct URL for public-prefix uploads (avatars); null for
  /// private kinds where reads go through signed GETs.
  final String? publicUrl;

  /// Server-reported ISO-8601 expiry for [putUrl].
  final DateTime? expiresAt;

  const UploadPlan({
    required this.putUrl,
    required this.objectPath,
    required this.publicUrl,
    required this.expiresAt,
  });

  factory UploadPlan.fromJson(Map<String, dynamic> json) {
    return UploadPlan(
      putUrl: json['put_url'] as String,
      objectPath: json['object_path'] as String,
      publicUrl: json['public_url'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }
}
