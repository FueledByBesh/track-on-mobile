class Friendship {
  final String friendshipId;
  final String friendId;
  final String friendName;
  final String friendEmail;
  final String status;
  final String direction;
  final String createdAt;

  Friendship({
    required this.friendshipId,
    required this.friendId,
    required this.friendName,
    required this.friendEmail,
    required this.status,
    required this.direction,
    required this.createdAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      friendshipId: json['friendship_id'],
      friendId: json['friend_id'],
      friendName: json['friend_name'] ?? '',
      friendEmail: json['friend_email'] ?? '',
      status: json['status'] ?? '',
      direction: json['direction'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class FriendSteps {
  final String friendId;
  final String friendName;
  final String friendEmail;
  final String date;
  final int stepCount;
  final int goal;
  final double progressPercent;
  final double distanceKm;

  FriendSteps({
    required this.friendId,
    required this.friendName,
    required this.friendEmail,
    required this.date,
    required this.stepCount,
    required this.goal,
    required this.progressPercent,
    required this.distanceKm,
  });

  factory FriendSteps.fromJson(Map<String, dynamic> json) {
    return FriendSteps(
      friendId: json['friend_id'],
      friendName: json['friend_name'] ?? '',
      friendEmail: json['friend_email'] ?? '',
      date: json['date'] ?? '',
      stepCount: json['step_count'] ?? 0,
      goal: json['goal'] ?? 10000,
      progressPercent: (json['progress_percent'] ?? 0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
    );
  }
}
