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
      createdByName: json['createdByName'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      isMember: json['isMember'] ?? false,
      createdAt: json['createdAt'] ?? '',
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
      userId: json['userId'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'MEMBER',
      joinedAt: json['joinedAt'] ?? '',
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
      clubId: json['clubId'],
      title: json['title'] ?? '',
      description: json['description'],
      targetType: json['targetType'] ?? 'STEPS',
      targetValue: (json['targetValue'] ?? 0).toDouble(),
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      subscriberCount: json['subscriberCount'] ?? 0,
      isSubscribed: json['isSubscribed'] ?? false,
      userProgress: json['userProgress']?.toDouble(),
    );
  }
}
