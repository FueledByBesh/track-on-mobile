enum JoinRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
  expired;

  static JoinRequestStatus? parse(String? raw) => switch (raw?.toUpperCase()) {
        'PENDING' => JoinRequestStatus.pending,
        'APPROVED' => JoinRequestStatus.approved,
        'REJECTED' => JoinRequestStatus.rejected,
        'CANCELLED' => JoinRequestStatus.cancelled,
        'EXPIRED' => JoinRequestStatus.expired,
        _ => null,
      };
}

/// A pending or resolved join request to a private club. The admin
/// inbox surfaces these; users see them in an optional "my requests"
/// listing (not yet designed).
class JoinRequest {
  /// Null only for the synthetic response when `allowJoinWithoutRequest`
  /// is enabled — in that case the user was joined directly and no
  /// request row was persisted.
  final String? id;

  final String clubId;
  final String userId;
  final String userName;
  final String userEmail;
  final JoinRequestStatus status;
  final DateTime requestedAt;

  /// Null when the synthetic-approve short-circuit fires.
  final DateTime? expiresAt;

  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolvedByName;

  const JoinRequest({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    required this.resolvedAt,
    required this.resolvedByUserId,
    required this.resolvedByName,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] as String?,
      clubId: json['club_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      status: JoinRequestStatus.parse(json['status'] as String?) ??
          JoinRequestStatus.pending,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedByUserId: json['resolved_by_user_id'] as String?,
      resolvedByName: json['resolved_by_name'] as String?,
    );
  }
}
