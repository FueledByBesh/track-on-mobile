enum OwnershipTransferStatus {
  pending,
  accepted,
  declined,
  cancelled,
  expired;

  static OwnershipTransferStatus? parse(String? raw) =>
      switch (raw?.toUpperCase()) {
        'PENDING' => OwnershipTransferStatus.pending,
        'ACCEPTED' => OwnershipTransferStatus.accepted,
        'DECLINED' => OwnershipTransferStatus.declined,
        'CANCELLED' => OwnershipTransferStatus.cancelled,
        'EXPIRED' => OwnershipTransferStatus.expired,
        _ => null,
      };
}

/// A pending or resolved ownership handoff. Two sides consume this —
/// the initiating owner to track/cancel, the target to accept/decline.
class OwnershipTransfer {
  final String id;
  final String clubId;
  final String clubName;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final OwnershipTransferStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? resolvedAt;

  const OwnershipTransfer({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.resolvedAt,
  });

  factory OwnershipTransfer.fromJson(Map<String, dynamic> json) {
    return OwnershipTransfer(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      clubName: json['club_name'] ?? '',
      fromUserId: json['from_user_id'] as String,
      fromUserName: json['from_user_name'] ?? '',
      toUserId: json['to_user_id'] as String,
      toUserName: json['to_user_name'] ?? '',
      status: OwnershipTransferStatus.parse(json['status'] as String?) ??
          OwnershipTransferStatus.pending,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }
}
