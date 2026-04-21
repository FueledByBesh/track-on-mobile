/// Filter for who-posted events. Mirrors the backend `PostsFromPref`.
enum PostsFromPref {
  /// Every member's post notifies.
  all,

  /// Only OWNER / ADMIN posts notify.
  staffOnly,

  /// No post notifications at all (mentions still respect the mentions flag).
  none;

  static PostsFromPref parse(String? raw) => switch (raw?.toUpperCase()) {
        'ALL' => PostsFromPref.all,
        'STAFF_ONLY' => PostsFromPref.staffOnly,
        'NONE' => PostsFromPref.none,
        _ => PostsFromPref.all,
      };

  String toWire() => switch (this) {
        PostsFromPref.all => 'ALL',
        PostsFromPref.staffOnly => 'STAFF_ONLY',
        PostsFromPref.none => 'NONE',
      };
}

/// Per-user, per-club notification preferences. Rendered on the mobile
/// notification-settings page. Defaults (matching the backend entity)
/// apply when no row exists yet; the first GET lazily inserts one.
class ClubNotificationPrefs {
  final bool allowNotifications;
  final bool allowPush;
  final PostsFromPref postsFrom;
  final bool mentions;
  final bool challengeStarted;
  final bool challengeEndingSoon;
  final bool challengeResults;

  /// Only meaningful for OWNER / ADMIN members, but stored regardless
  /// so the preference survives a demote→promote cycle.
  final bool joinRequests;
  final bool postApprovalRequests;

  const ClubNotificationPrefs({
    this.allowNotifications = false,
    this.allowPush = false,
    this.postsFrom = PostsFromPref.all,
    this.mentions = true,
    this.challengeStarted = true,
    this.challengeEndingSoon = true,
    this.challengeResults = true,
    this.joinRequests = true,
    this.postApprovalRequests = true,
  });

  factory ClubNotificationPrefs.fromJson(Map<String, dynamic> json) {
    return ClubNotificationPrefs(
      allowNotifications: json['allow_notifications'] ?? false,
      allowPush: json['allow_push'] ?? false,
      postsFrom: PostsFromPref.parse(json['posts_from'] as String?),
      mentions: json['mentions'] ?? true,
      challengeStarted: json['challenge_started'] ?? true,
      challengeEndingSoon: json['challenge_ending_soon'] ?? true,
      challengeResults: json['challenge_results'] ?? true,
      joinRequests: json['join_requests'] ?? true,
      postApprovalRequests: json['post_approval_requests'] ?? true,
    );
  }

  /// Patch body — null means "don't touch".
  static Map<String, dynamic> patch({
    bool? allowNotifications,
    bool? allowPush,
    PostsFromPref? postsFrom,
    bool? mentions,
    bool? challengeStarted,
    bool? challengeEndingSoon,
    bool? challengeResults,
    bool? joinRequests,
    bool? postApprovalRequests,
  }) {
    final out = <String, dynamic>{};
    if (allowNotifications != null) out['allow_notifications'] = allowNotifications;
    if (allowPush != null) out['allow_push'] = allowPush;
    if (postsFrom != null) out['posts_from'] = postsFrom.toWire();
    if (mentions != null) out['mentions'] = mentions;
    if (challengeStarted != null) out['challenge_started'] = challengeStarted;
    if (challengeEndingSoon != null) out['challenge_ending_soon'] = challengeEndingSoon;
    if (challengeResults != null) out['challenge_results'] = challengeResults;
    if (joinRequests != null) out['join_requests'] = joinRequests;
    if (postApprovalRequests != null) {
      out['post_approval_requests'] = postApprovalRequests;
    }
    return out;
  }
}
