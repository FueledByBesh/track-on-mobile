class Club {
  final String id;
  final String name;
  final String? description;
  final String createdByName;
  final int memberCount;
  final bool isMember;
  final String createdAt;

  Club({
    required this.id,
    required this.name,
    this.description,
    required this.createdByName,
    required this.memberCount,
    required this.isMember,
    required this.createdAt,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      createdByName: json['created_by_name'] ?? '',
      memberCount: json['member_count'] ?? 0,
      isMember: json['is_member'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
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
