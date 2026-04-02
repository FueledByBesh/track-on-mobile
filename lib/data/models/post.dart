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
      authorName: json['authorName'] ?? '',
      authorEmail: json['authorEmail'] ?? '',
      clubId: json['clubId'],
      clubName: json['clubName'],
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      userLiked: json['userLiked'],
      createdAt: json['createdAt'] ?? '',
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
      authorName: json['authorName'] ?? '',
      authorEmail: json['authorEmail'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
