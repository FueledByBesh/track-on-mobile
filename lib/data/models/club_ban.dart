/// A full ban record, as returned by the admin bans list / ban-lift
/// endpoints. [ClubBanInfo] on a [Club] is the viewer's-own-ban slice;
/// this is the audit row admins see.
class ClubBan {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String bannedByUserId;
  final String bannedByName;

  /// Null = permanent. Otherwise when the ban auto-lifts.
  final DateTime? bannedUntil;
  final String? reason;

  final DateTime createdAt;

  /// Null while the ban is still active (not manually lifted).
  final DateTime? unbannedAt;

  /// True iff the ban currently restricts the user. Derived on the
  /// server from `unbannedAt IS NULL AND (bannedUntil IS NULL OR
  /// bannedUntil > now)`.
  final bool active;

  const ClubBan({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.bannedByUserId,
    required this.bannedByName,
    required this.bannedUntil,
    required this.reason,
    required this.createdAt,
    required this.unbannedAt,
    required this.active,
  });

  factory ClubBan.fromJson(Map<String, dynamic> json) {
    return ClubBan(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      bannedByUserId: json['banned_by_user_id'] as String,
      bannedByName: json['banned_by_name'] ?? '',
      bannedUntil: json['banned_until'] != null
          ? DateTime.parse(json['banned_until'] as String)
          : null,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      unbannedAt: json['unbanned_at'] != null
          ? DateTime.parse(json['unbanned_at'] as String)
          : null,
      active: json['active'] ?? false,
    );
  }
}
