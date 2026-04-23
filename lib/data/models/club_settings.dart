import 'club.dart';

/// All behavior toggles for a club — permissions, visibility overrides,
/// moderation. Owner-only for writes, admin-readable for context.
class ClubSettings {
  // ----- non-member visibility overrides -----
  final bool nonMembersCanViewPosts;
  final bool nonMembersCanViewChallenges;
  final bool nonMembersCanViewMembers;

  // ----- role-gated actions -----
  final ClubRole whoCanPost;
  final ClubRole whoCanCreateChallenges;
  final ClubRole whoCanInvite;
  final ClubRole whoCanRemoveMembers;
  final ClubRole whoCanApproveJoinRequests;
  final ClubRole whoCanBan;

  // ----- moderation / intake -----
  final bool requirePostApproval;

  /// For private clubs whose owner doesn't actually screen applicants.
  /// When true, members join directly with no request row created.
  final bool allowJoinWithoutRequest;
  final int joinRequestTtlDays;

  const ClubSettings({
    this.nonMembersCanViewPosts = false,
    this.nonMembersCanViewChallenges = false,
    this.nonMembersCanViewMembers = false,
    this.whoCanPost = ClubRole.member,
    this.whoCanCreateChallenges = ClubRole.admin,
    this.whoCanInvite = ClubRole.member,
    this.whoCanRemoveMembers = ClubRole.admin,
    this.whoCanApproveJoinRequests = ClubRole.admin,
    this.whoCanBan = ClubRole.owner,
    this.requirePostApproval = false,
    this.allowJoinWithoutRequest = false,
    this.joinRequestTtlDays = 30,
  });

  factory ClubSettings.fromJson(Map<String, dynamic> json) {
    ClubRole parseRole(String key, ClubRole fallback) {
      final raw = (json[key] as String?)?.toUpperCase();
      return switch (raw) {
        'OWNER' => ClubRole.owner,
        'ADMIN' => ClubRole.admin,
        'MEMBER' => ClubRole.member,
        _ => fallback,
      };
    }

    return ClubSettings(
      nonMembersCanViewPosts: json['non_members_can_view_posts'] ?? false,
      nonMembersCanViewChallenges:
          json['non_members_can_view_challenges'] ?? false,
      nonMembersCanViewMembers:
          json['non_members_can_view_members'] ?? false,
      whoCanPost: parseRole('who_can_post', ClubRole.member),
      whoCanCreateChallenges:
          parseRole('who_can_create_challenges', ClubRole.admin),
      whoCanInvite: parseRole('who_can_invite', ClubRole.member),
      whoCanRemoveMembers:
          parseRole('who_can_remove_members', ClubRole.admin),
      whoCanApproveJoinRequests:
          parseRole('who_can_approve_join_requests', ClubRole.admin),
      whoCanBan: parseRole('who_can_ban', ClubRole.owner),
      requirePostApproval: json['require_post_approval'] ?? false,
      allowJoinWithoutRequest: json['allow_join_without_request'] ?? false,
      joinRequestTtlDays: json['join_request_ttl_days'] ?? 30,
    );
  }

  /// Patch-style body. Send only the fields the user changed — null
  /// means "don't touch" on the server side.
  static Map<String, dynamic> patch({
    bool? nonMembersCanViewPosts,
    bool? nonMembersCanViewChallenges,
    bool? nonMembersCanViewMembers,
    ClubRole? whoCanPost,
    ClubRole? whoCanCreateChallenges,
    ClubRole? whoCanInvite,
    ClubRole? whoCanRemoveMembers,
    ClubRole? whoCanApproveJoinRequests,
    ClubRole? whoCanBan,
    bool? requirePostApproval,
    bool? allowJoinWithoutRequest,
    int? joinRequestTtlDays,
  }) {
    final out = <String, dynamic>{};
    if (nonMembersCanViewPosts != null) {
      out['non_members_can_view_posts'] = nonMembersCanViewPosts;
    }
    if (nonMembersCanViewChallenges != null) {
      out['non_members_can_view_challenges'] = nonMembersCanViewChallenges;
    }
    if (nonMembersCanViewMembers != null) {
      out['non_members_can_view_members'] = nonMembersCanViewMembers;
    }
    if (whoCanPost != null) out['who_can_post'] = roleToWire(whoCanPost);
    if (whoCanCreateChallenges != null) {
      out['who_can_create_challenges'] = roleToWire(whoCanCreateChallenges);
    }
    if (whoCanInvite != null) out['who_can_invite'] = roleToWire(whoCanInvite);
    if (whoCanRemoveMembers != null) {
      out['who_can_remove_members'] = roleToWire(whoCanRemoveMembers);
    }
    if (whoCanApproveJoinRequests != null) {
      out['who_can_approve_join_requests'] =
          roleToWire(whoCanApproveJoinRequests);
    }
    if (whoCanBan != null) out['who_can_ban'] = roleToWire(whoCanBan);
    if (requirePostApproval != null) {
      out['require_post_approval'] = requirePostApproval;
    }
    if (allowJoinWithoutRequest != null) {
      out['allow_join_without_request'] = allowJoinWithoutRequest;
    }
    if (joinRequestTtlDays != null) {
      out['join_request_ttl_days'] = joinRequestTtlDays;
    }
    return out;
  }
}
