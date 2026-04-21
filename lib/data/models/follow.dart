enum FollowStatus {
  pending,
  accepted;

  static FollowStatus? parse(String? raw) => switch (raw?.toUpperCase()) {
        'PENDING' => FollowStatus.pending,
        'ACCEPTED' => FollowStatus.accepted,
        _ => null,
      };
}

/// Result of a follow / unfollow / accept / reject action. When
/// [status] is null the edge was deleted (unfollow, cancel, reject).
class FollowAction {
  final FollowStatus? status;

  const FollowAction(this.status);

  factory FollowAction.fromJson(Map<String, dynamic> json) =>
      FollowAction(FollowStatus.parse(json['status'] as String?));

  bool get isDeleted => status == null;
  bool get isPending => status == FollowStatus.pending;
  bool get isAccepted => status == FollowStatus.accepted;
}
