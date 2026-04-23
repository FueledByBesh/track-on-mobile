/// A user's standing in a club. Mirrors the backend [ClubRole] enum.
enum ClubRole { owner, admin, member }

ClubRole? _parseRole(dynamic raw) {
  if (raw == null) return null;
  return switch ((raw as String).toUpperCase()) {
    'OWNER' => ClubRole.owner,
    'ADMIN' => ClubRole.admin,
    'MEMBER' => ClubRole.member,
    _ => null,
  };
}

String roleToWire(ClubRole role) => switch (role) {
      ClubRole.owner => 'OWNER',
      ClubRole.admin => 'ADMIN',
      ClubRole.member => 'MEMBER',
    };

/// Ban context for the current viewer. Null on [Club] when not banned.
class ClubBanInfo {
  /// Null = permanent ban.
  final DateTime? bannedUntil;
  final String? reason;

  const ClubBanInfo({this.bannedUntil, this.reason});

  factory ClubBanInfo.fromJson(Map<String, dynamic> json) => ClubBanInfo(
        bannedUntil: json['banned_until'] != null
            ? DateTime.parse(json['banned_until'] as String)
            : null,
        reason: json['reason'] as String?,
      );
}

/// A club, with every viewer-relative flag the detail page needs.
class Club {
  final String id;
  final String name;

  /// Handle stored without the leading "@" — the UI prefixes it for display.
  final String handle;

  final String? description;
  final String? location;
  final List<String> sportTypes;
  final String? avatarImageUrl;

  final String createdByName;
  final int memberCount;
  final String createdAt;

  final bool isPublic;

  // ----- viewer-relative -----
  final bool isMember;
  final ClubRole? userRole;
  final bool hasPendingRequest;

  /// Non-null iff the viewer is currently banned from this club.
  final ClubBanInfo? banInfo;

  // ----- visibility overrides for private clubs (guest preview) -----
  final bool nonMembersCanViewPosts;
  final bool nonMembersCanViewChallenges;
  final bool nonMembersCanViewMembers;

  const Club({
    required this.id,
    required this.name,
    required this.handle,
    this.description,
    this.location,
    this.sportTypes = const [],
    this.avatarImageUrl,
    required this.createdByName,
    required this.memberCount,
    required this.createdAt,
    this.isPublic = true,
    this.isMember = false,
    this.userRole,
    this.hasPendingRequest = false,
    this.banInfo,
    this.nonMembersCanViewPosts = false,
    this.nonMembersCanViewChallenges = false,
    this.nonMembersCanViewMembers = false,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as String,
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      sportTypes: (json['sport_types'] as List?)?.cast<String>() ?? const [],
      avatarImageUrl: json['avatar_image_url'] as String?,
      createdByName: json['created_by_name'] ?? '',
      memberCount: json['member_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      isPublic: json['is_public'] ?? true,
      isMember: json['is_member'] ?? false,
      userRole: _parseRole(json['user_role']),
      hasPendingRequest: json['has_pending_request'] ?? false,
      banInfo: json['ban_info'] != null
          ? ClubBanInfo.fromJson(json['ban_info'] as Map<String, dynamic>)
          : null,
      nonMembersCanViewPosts: json['non_members_can_view_posts'] ?? false,
      nonMembersCanViewChallenges:
          json['non_members_can_view_challenges'] ?? false,
      nonMembersCanViewMembers:
          json['non_members_can_view_members'] ?? false,
    );
  }

  // ----- derived helpers (match backend ClubAccessEvaluator) -----

  /// True iff the viewer can read posts. Members always can; non-members
  /// can if the club is public or the owner opened up the preview.
  bool get canViewPosts =>
      isMember || isPublic || nonMembersCanViewPosts;

  bool get canViewChallenges =>
      isMember || isPublic || nonMembersCanViewChallenges;

  bool get canViewMembers =>
      isMember || isPublic || nonMembersCanViewMembers;

  bool get isBanned => banInfo != null;
}

/// Grouped response for the "Clubs" tab. Recommendations come from a
/// separate call so they can evolve independently.
class MyClubs {
  final List<Club> owned;
  final List<Club> admin;
  final List<Club> member;

  const MyClubs({
    required this.owned,
    required this.admin,
    required this.member,
  });

  factory MyClubs.fromJson(Map<String, dynamic> json) {
    List<Club> parse(String key) {
      final list = json[key] as List? ?? const [];
      return list
          .map((e) => Club.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return MyClubs(
      owned: parse('owned'),
      admin: parse('admin'),
      member: parse('member'),
    );
  }

  bool get isEmpty =>
      owned.isEmpty && admin.isEmpty && member.isEmpty;
}

class ClubMember {
  final String userId;
  final String name;
  final String email;
  final ClubRole role;
  final String joinedAt;

  const ClubMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    return ClubMember(
      userId: json['user_id'] as String,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role']) ?? ClubRole.member,
      joinedAt: json['joined_at'] ?? '',
    );
  }
}

class Challenge {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final String targetType;
  final double targetValue;
  final String startDate;
  final String endDate;
  final int subscriberCount;
  final bool isSubscribed;
  final double? userProgress;

  const Challenge({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.targetType,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    required this.subscriberCount,
    required this.isSubscribed,
    this.userProgress,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      title: json['title'] ?? '',
      description: json['description'] as String?,
      targetType: json['target_type'] ?? 'STEPS',
      targetValue: (json['target_value'] ?? 0).toDouble(),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      subscriberCount: json['subscriber_count'] ?? 0,
      isSubscribed: json['is_subscribed'] ?? false,
      userProgress: json['user_progress']?.toDouble(),
    );
  }
}
