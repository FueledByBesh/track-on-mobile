class Post {
  final String id;
  final String authorName;
  final String authorEmail;
  final String? clubId;
  final String? clubName;
  final String content;
  final String? imageUrl;
  final int likes;
  final int dislikes;
  final int commentCount;
  final bool? userLiked;
  final String createdAt;

  Post({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    this.clubId,
    this.clubName,
    required this.content,
    this.imageUrl,
    required this.likes,
    required this.dislikes,
    required this.commentCount,
    this.userLiked,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      authorName: json['author_name'] ?? '',
      authorEmail: json['author_email'] ?? '',
      clubId: json['club_id'],
      clubName: json['club_name'],
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      userLiked: json['user_liked'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Comment {
  final String id;
  final String authorName;
  final String authorEmail;
  final String content;
  final String createdAt;

  Comment({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      authorName: json['author_name'] ?? '',
      authorEmail: json['author_email'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
