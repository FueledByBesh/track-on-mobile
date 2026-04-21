/// Full user profile as returned by the backend profile endpoints
/// (`/api/users/me`, `/api/users/{id}`, `/api/users/by-handle/{handle}`).
///
/// Used both for "who am I" (auth session) and "someone else's profile."
/// Fields like [email] are null for non-self views so we don't leak
/// contact info. Viewer-relative flags ([isSelf], [isFollowing],
/// [hasPendingFollowRequest]) drive the action buttons on the profile
/// page.
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

  // ----- counts -----
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int clubsCount;

  // ----- viewer-relative -----
  final bool isSelf;
  final bool isFollowing;
  final bool hasPendingFollowRequest;

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
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.clubsCount = 0,
    this.isSelf = false,
    this.isFollowing = false,
    this.hasPendingFollowRequest = false,
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
      postsCount: json['posts_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      clubsCount: json['clubs_count'] ?? 0,
      isSelf: json['is_self'] ?? false,
      isFollowing: json['is_following'] ?? false,
      hasPendingFollowRequest: json['has_pending_follow_request'] ?? false,
      isProfilePublic: json['is_profile_public'] ?? true,
      role: json['role'] ?? 'USER',
    );
  }

  UserProfile copyWith({
    String? bio,
    String? location,
    String? avatarImageUrl,
    bool? isFollowing,
    bool? hasPendingFollowRequest,
    int? followersCount,
    int? followingCount,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      handle: handle,
      email: email,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
      postsCount: postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      clubsCount: clubsCount,
      isSelf: isSelf,
      isFollowing: isFollowing ?? this.isFollowing,
      hasPendingFollowRequest:
          hasPendingFollowRequest ?? this.hasPendingFollowRequest,
      isProfilePublic: isProfilePublic,
      role: role,
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
