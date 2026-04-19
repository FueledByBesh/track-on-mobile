class Club {
  final String id;
  final String name;

  /// Unique human-readable handle, e.g. "@morning-runners". Lets users
  /// find and link to the club without knowing its UUID. Globally unique,
  /// validated server-side — always lowercase, alphanumeric + hyphens.
  final String handle;

  final String? description;
  final String createdByName;
  final int memberCount;
  final bool isMember;
  final String createdAt;

  /// Which sports the club is about, e.g. ["Running", "Trail"]. Surfaced
  /// in the About section and used for discovery/recommendations.
  final List<String> sportTypes;

  /// Free-form human location, e.g. "New York, NY" or "Online".
  final String? location;

  /// User's role in this club: 'OWNER', 'ADMIN', 'MEMBER', or null if not a member.
  final String? userRole;

  /// Public clubs: anyone can join and see all content without requesting.
  /// Private clubs: user must send a join request; non-members are gated
  /// out of content unless the owner opens up specific sections via the
  /// `nonMembersCanView*` flags below.
  final bool isPublic;

  /// Set when the current user has a pending join request to a private club.
  /// Used to swap the "Request to Join" button for "Requested" (disabled).
  final bool hasPendingRequest;

  /// Per-section visibility overrides for private clubs. Ignored when
  /// [isPublic] is true (public clubs always show everything).
  final bool nonMembersCanViewPosts;
  final bool nonMembersCanViewChallenges;
  final bool nonMembersCanViewMembers;

  Club({
    required this.id,
    required this.name,
    required this.handle,
    this.description,
    required this.createdByName,
    required this.memberCount,
    required this.isMember,
    required this.createdAt,
    this.sportTypes = const [],
    this.location,
    this.userRole,
    this.isPublic = true,
    this.hasPendingRequest = false,
    this.nonMembersCanViewPosts = false,
    this.nonMembersCanViewChallenges = false,
    this.nonMembersCanViewMembers = false,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      description: json['description'],
      createdByName: json['created_by_name'] ?? '',
      memberCount: json['member_count'] ?? 0,
      isMember: json['is_member'] ?? false,
      createdAt: json['created_at'] ?? '',
      sportTypes: (json['sport_types'] as List?)?.cast<String>() ?? const [],
      location: json['location'],
      userRole: json['user_role'],
      isPublic: json['is_public'] ?? true,
      hasPendingRequest: json['has_pending_request'] ?? false,
      nonMembersCanViewPosts: json['non_members_can_view_posts'] ?? false,
      nonMembersCanViewChallenges:
          json['non_members_can_view_challenges'] ?? false,
      nonMembersCanViewMembers:
          json['non_members_can_view_members'] ?? false,
    );
  }

  /// Whether the current user can see posts in this club.
  bool get canViewPosts => isMember || isPublic || nonMembersCanViewPosts;

  /// Whether the current user can see challenges in this club.
  bool get canViewChallenges =>
      isMember || isPublic || nonMembersCanViewChallenges;

  /// Whether the current user can see the members list.
  bool get canViewMembers =>
      isMember || isPublic || nonMembersCanViewMembers;
}

class ClubMember {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String joinedAt;

  ClubMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    return ClubMember(
      userId: json['user_id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'MEMBER',
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

  Challenge({
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
      id: json['id'],
      clubId: json['club_id'],
      title: json['title'] ?? '',
      description: json['description'],
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
