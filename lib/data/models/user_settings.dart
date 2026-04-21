/// User-scoped settings: step goal + privacy toggles. Mirrors the
/// backend `UserSettingsResponse`. Edited from the settings page.
class UserSettings {
  final int defaultStepGoal;
  final bool isProfilePublic;

  /// When true, follow attempts on this user land as PENDING and wait
  /// for the user's accept. Coupled with [isProfilePublic] on first
  /// flip (private → approval on), but independently tunable after.
  final bool requireFollowApproval;

  const UserSettings({
    this.defaultStepGoal = 10000,
    this.isProfilePublic = true,
    this.requireFollowApproval = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      defaultStepGoal: json['default_step_goal'] ?? 10000,
      isProfilePublic: json['is_profile_public'] ?? true,
      requireFollowApproval: json['require_follow_approval'] ?? false,
    );
  }

  /// Patch body — null means "don't touch."
  static Map<String, dynamic> patch({
    int? defaultStepGoal,
    bool? isProfilePublic,
    bool? requireFollowApproval,
  }) {
    return {
      'default_step_goal': ?defaultStepGoal,
      'is_profile_public': ?isProfilePublic,
      'require_follow_approval': ?requireFollowApproval,
    };
  }
}
