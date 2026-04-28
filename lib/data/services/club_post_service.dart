import '../api_client.dart';
import '../models/post.dart';

class ClubPostApiService {
  final ApiClient _api;

  ClubPostApiService(this._api);

  Future<Post> create({
    required String clubId,
    required String content,
    List<PostAttachmentRequest> attachments = const [],
  }) async {
    final res = await _api.dio.post('/api/posts/club', data: {
      'club_id': clubId,
      'content': content,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    });
    return Post.fromJson(res.data);
  }

  Future<List<Post>> getByClub(String clubId) async {
    final res = await _api.dio.get('/api/posts/club/$clubId');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<List<Post>> getByAuthor(String authorId) async {
    final res = await _api.dio.get('/api/posts/club-author/$authorId');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<void> delete(String postId) async {
    await _api.dio.delete('/api/posts/club/$postId');
  }
}
