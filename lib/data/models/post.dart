/// Club vs. user post discriminator. Sent by the server in
/// [PostResponse.kind] and used as a path segment for comment/like
/// endpoints (`/api/posts/{kind}/{id}/...`).
enum PostKind {
  club,
  user;

  static PostKind parse(String? raw) => switch (raw?.toUpperCase()) {
        'CLUB' => PostKind.club,
        'USER' => PostKind.user,
        _ => PostKind.club,
      };

  String get wire => switch (this) {
        PostKind.club => 'club',
        PostKind.user => 'user',
      };
}

/// Kind of structured card attached to a post. NONE = plain text /
/// image only. Future values (activity share, challenge progress) are
/// decoded generically so older mobile builds don't crash when the
/// server returns a new value.
enum PostAttachmentKind {
  none,
  activity,
  challengeProgress,
  unknown;

  static PostAttachmentKind parse(String? raw) => switch (raw?.toUpperCase()) {
        'NONE' => PostAttachmentKind.none,
        'ACTIVITY' => PostAttachmentKind.activity,
        'CHALLENGE_PROGRESS' => PostAttachmentKind.challengeProgress,
        null => PostAttachmentKind.none,
        _ => PostAttachmentKind.unknown,
      };

  String get wire => switch (this) {
        PostAttachmentKind.none => 'NONE',
        PostAttachmentKind.activity => 'ACTIVITY',
        PostAttachmentKind.challengeProgress => 'CHALLENGE_PROGRESS',
        PostAttachmentKind.unknown => 'NONE',
      };
}

/// Unified post payload returned by feed, per-club, and per-author
/// endpoints. The [kind] field tells the client which branch it's
/// looking at; club-only fields are null when kind == USER.
class Post {
  final String id;
  final PostKind kind;

  final String authorName;
  final String authorEmail;

  /// Null when [kind] == [PostKind.user].
  final String? clubId;
  final String? clubName;

  final String content;
  final String? imageUrl;

  final PostAttachmentKind attachmentKind;
  final String? attachmentRefId;

  final int likes;
  final int dislikes;
  final int commentCount;

  /// True = viewer liked, false = disliked, null = no reaction.
  final bool? userLiked;

  final String createdAt;

  const Post({
    required this.id,
    required this.kind,
    required this.authorName,
    required this.authorEmail,
    this.clubId,
    this.clubName,
    required this.content,
    this.imageUrl,
    this.attachmentKind = PostAttachmentKind.none,
    this.attachmentRefId,
    required this.likes,
    required this.dislikes,
    required this.commentCount,
    this.userLiked,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      kind: PostKind.parse(json['kind'] as String?),
      authorName: json['author_name'] ?? '',
      authorEmail: json['author_email'] ?? '',
      clubId: json['club_id'] as String?,
      clubName: json['club_name'] as String?,
      content: json['content'] ?? '',
      imageUrl: json['image_url'] as String?,
      attachmentKind:
          PostAttachmentKind.parse(json['attachment_kind'] as String?),
      attachmentRefId: json['attachment_ref_id'] as String?,
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      userLiked: json['user_liked'] as bool?,
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

  const Comment({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      authorName: json['author_name'] ?? '',
      authorEmail: json['author_email'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
