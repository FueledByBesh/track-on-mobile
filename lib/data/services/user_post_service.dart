import '../api_client.dart';
import '../models/post.dart';

class UserPostApiService {
  final ApiClient _api;

  UserPostApiService(this._api);

  Future<Post> create({
    required String content,
    List<PostAttachmentRequest> attachments = const [],
  }) async {
    final res = await _api.dio.post('/api/posts/user', data: {
      'content': content,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    });
    return Post.fromJson(res.data);
  }

  Future<List<Post>> getByAuthor(String authorId) async {
    final res = await _api.dio.get('/api/posts/user/$authorId');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<void> delete(String postId) async {
    await _api.dio.delete('/api/posts/user/$postId');
  }
}
