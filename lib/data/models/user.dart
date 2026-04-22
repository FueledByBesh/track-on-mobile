/// Static profile fields as returned by `/api/users/me`,
/// `/api/users/{id}`, `/api/users/by-handle/{handle}`. Changes only
/// when the user themselves edits their row — so it's cacheable with
/// a long TTL and backed by an ETag from `users.updated_at`.
///
/// Counts and viewer-relative follow flags are NOT here — see
/// [UserStats], which is served by the companion stats endpoints and
/// refetched aggressively.
class UserProfile {
  final String id;
  final String firstName;
  final String lastName;

  /// Handle stored without the leading "@" — UI prefixes it for display.
  final String handle;

  /// Null unless the viewer is looking at their own profile.
  final String? email;

  final String? bio;
  final String? location;
  final String? avatarImageUrl;

  /// True iff this is the viewer's own profile.
  final bool isSelf;

  /// Profile owner's privacy toggle. When false + not following + not
  /// self, the content tabs should render a lock state.
  final bool isProfilePublic;

  /// Role from the auth session. "USER" / "ADMIN". The backend profile
  /// endpoints don't return this; it's populated from the `/user/info`
  /// auth endpoint and kept local.
  final String role;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.handle,
    this.email,
    this.bio,
    this.location,
    this.avatarImageUrl,
    this.isSelf = false,
    this.isProfilePublic = true,
    this.role = 'USER',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      // Fall back to OAuth-style keys so the auth bootstrap (which
      // hits /user/info and gets Google-shaped payloads) still parses.
      firstName: json['first_name'] ??
          json['given_name'] ??
          json['name'] ??
          '',
      lastName: json['last_name'] ?? json['family_name'] ?? '',
      handle: json['handle'] ?? '',
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      avatarImageUrl:
          json['avatar_image_url'] as String? ?? json['picture'] as String?,
      isSelf: json['is_self'] ?? false,
      isProfilePublic: json['is_profile_public'] ?? true,
      role: json['role'] ?? 'USER',
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? handle,
    String? bio,
    String? location,
    String? avatarImageUrl,
    bool? isProfilePublic,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      handle: handle ?? this.handle,
      email: email,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
      isSelf: isSelf,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      role: role,
    );
  }
}

/// Live counts + viewer-relative follow flags. Served by the companion
/// `/api/users/*/stats` endpoints. Small payload, refetched often;
/// cached with stale-while-revalidate semantics so the profile page
/// shows the previous values instantly on reopen while the network
/// updates them in the background.
class UserStats {
  final String userId;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int clubsCount;
  final bool isFollowing;
  final bool hasPendingFollowRequest;

  const UserStats({
    required this.userId,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.clubsCount = 0,
    this.isFollowing = false,
    this.hasPendingFollowRequest = false,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['user_id'] ?? '',
      postsCount: json['posts_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      clubsCount: json['clubs_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      hasPendingFollowRequest: json['has_pending_follow_request'] ?? false,
    );
  }

  UserStats copyWith({
    int? postsCount,
    int? followersCount,
    int? followingCount,
    int? clubsCount,
    bool? isFollowing,
    bool? hasPendingFollowRequest,
  }) {
    return UserStats(
      userId: userId,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      clubsCount: clubsCount ?? this.clubsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      hasPendingFollowRequest:
          hasPendingFollowRequest ?? this.hasPendingFollowRequest,
    );
  }
}

/// Lightweight row item for follower/following lists, search results,
/// suggestions. Mirrors the backend `UserPreview` DTO.
class UserPreview {
  final String id;
  final String firstName;
  final String lastName;
  final String handle;
  final String? avatarImageUrl;
  final bool isFollowing;
  final bool hasPendingFollowRequest;

  const UserPreview({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.handle,
    this.avatarImageUrl,
    this.isFollowing = false,
    this.hasPendingFollowRequest = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserPreview.fromJson(Map<String, dynamic> json) {
    return UserPreview(
      id: json['id'] as String,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      handle: json['handle'] ?? '',
      avatarImageUrl: json['avatar_image_url'] as String?,
      isFollowing: json['is_following'] ?? false,
      hasPendingFollowRequest: json['has_pending_follow_request'] ?? false,
    );
  }
}

/// Legacy search result shape — the `/api/users/search` endpoint still
/// returns this narrower payload. Kept for compatibility with the
/// existing search UI; over time it'll be folded into [UserPreview].
class UserSearchResult {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  const UserSearchResult({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
