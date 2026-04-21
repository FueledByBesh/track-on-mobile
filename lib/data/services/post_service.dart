import '../api_client.dart';
import '../models/post.dart';

/// Cross-kind post operations — the mixed feed + comments + likes.
/// Mirrors the backend `PostService` which handles anything that
/// spans both `ClubPost` and `UserPost` via the dual-FK tables.
class PostApiService {
  final ApiClient _api;

  PostApiService(this._api);

  /// Mixed timeline: club posts from the viewer's clubs + user posts
  /// from friends and self, interleaved by createdAt DESC.
  Future<List<Post>> getFeed() async {
    final res = await _api.dio.get('/api/posts/feed');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  // ============ COMMENTS ============

  Future<Comment> addComment(PostKind kind, String postId, String content) async {
    final res = await _api.dio.post(
      '/api/posts/${kind.wire}/$postId/comments',
      data: {'content': content},
    );
    return Comment.fromJson(res.data);
  }

  Future<List<Comment>> getComments(PostKind kind, String postId) async {
    final res =
        await _api.dio.get('/api/posts/${kind.wire}/$postId/comments');
    return (res.data as List).map((e) => Comment.fromJson(e)).toList();
  }

  // ============ LIKES ============

  /// Toggle the viewer's reaction. isLike=true = like, false = dislike.
  /// Calling with the same value as the current reaction clears it.
  Future<Post> toggleLike(PostKind kind, String postId, bool isLike) async {
    final res = await _api.dio.post(
      '/api/posts/${kind.wire}/$postId/like',
      data: {'is_like': isLike},
    );
    return Post.fromJson(res.data);
  }
}
