import '../api_client.dart';
import '../models/post.dart';

/// Club-post CRUD. Comments, likes, and the mixed feed live on
/// [PostApiService] since they span both kinds.
class ClubPostApiService {
  final ApiClient _api;

  ClubPostApiService(this._api);

  /// Post into a club the viewer is a member of. Attachments are
  /// optional — when [attachmentKind] is null or NONE, [attachmentRefId]
  /// must also be null. The backend enforces this via a CHECK; we
  /// avoid sending it when empty to keep the payload tidy.
  Future<Post> create({
    required String clubId,
    required String content,
    String? imageUrl,
    PostAttachmentKind? attachmentKind,
    String? attachmentRefId,
  }) async {
    final res = await _api.dio.post('/api/posts/club', data: {
      'club_id': clubId,
      'content': content,
      'image_url': ?imageUrl,
      'attachment_kind': ?attachmentKind?.wire,
      'attachment_ref_id': ?attachmentRefId,
    });
    return Post.fromJson(res.data);
  }

  /// APPROVED club posts for a given club. Backend gates visibility
  /// via `ClubAccessEvaluator.requireViewPosts` — callers not allowed
  /// to see posts get a 403.
  Future<List<Post>> getByClub(String clubId) async {
    final res = await _api.dio.get('/api/posts/club/$clubId');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  /// APPROVED club posts authored by a given user, across all clubs the
  /// viewer has access to see. Posts in private clubs the viewer can't
  /// see are filtered out server-side.
  Future<List<Post>> getByAuthor(String authorId) async {
    final res = await _api.dio.get('/api/posts/club-author/$authorId');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }
}
