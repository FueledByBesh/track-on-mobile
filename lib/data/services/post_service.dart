import '../api_client.dart';
import '../models/post.dart';

class PostApiService {
  final ApiClient _api;

  PostApiService(this._api);

  Future<Post> create({required String content, String? imageUrl, String? clubId}) async {
    final response = await _api.dio.post('/api/posts', data: {
      'content': content,
      'image_url': imageUrl,
      'club_id': clubId,
    });
    return Post.fromJson(response.data);
  }

  Future<List<Post>> getFeed() async {
    final response = await _api.dio.get('/api/posts/feed');
    return (response.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<List<Post>> getByClub(String clubId) async {
    final response = await _api.dio.get('/api/posts/club/$clubId');
    return (response.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<List<Post>> getByUser(String userId) async {
    final response = await _api.dio.get('/api/posts/user/$userId');
    return (response.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Comment> addComment(String postId, String content) async {
    final response = await _api.dio.post('/api/posts/$postId/comments', data: {
      'content': content,
    });
    return Comment.fromJson(response.data);
  }

  Future<List<Comment>> getComments(String postId) async {
    final response = await _api.dio.get('/api/posts/$postId/comments');
    return (response.data as List).map((e) => Comment.fromJson(e)).toList();
  }

  Future<Post> toggleLike(String postId, bool isLike) async {
    final response = await _api.dio.post('/api/posts/$postId/like', data: {
      'is_like': isLike,
    });
    return Post.fromJson(response.data);
  }
}
