import '../api_client.dart';
import '../models/post.dart';

/// Personal-post CRUD. Mirrors [ClubPostApiService] without the club
/// membership/moderation gating. Comments and likes still go through
/// [PostApiService] since they're shared across both kinds.
class UserPostApiService {
  final ApiClient _api;

  UserPostApiService(this._api);

  Future<Post> create({
    required String content,
    String? imageUrl,
    PostAttachmentKind? attachmentKind,
    String? attachmentRefId,
  }) async {
    final res = await _api.dio.post('/api/posts/user', data: {
      'content': content,
      'image_url': ?imageUrl,
      'attachment_kind': ?attachmentKind?.wire,
      'attachment_ref_id': ?attachmentRefId,
    });
    return Post.fromJson(res.data);
  }

  /// Personal feed posts by a given user. Visibility rules for personal
  /// posts (public vs followers-only) will be layered on when the
  /// personal-post UX ships — for now the server returns everything.
  Future<List<Post>> getByAuthor(String authorId) async {
    final res = await _api.dio.get('/api/posts/user/$authorId');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }
}
