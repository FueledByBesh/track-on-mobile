import 'package:flutter/material.dart';

import 'package:trackon_mobile/data/models/user.dart';

/// Circular user avatar. Uses the remote [UserProfile.avatarImageUrl]
/// when present, otherwise falls back to the user's initials drawn on
/// a primary-color gradient. Pass [sizePx] to control the diameter;
/// the internal font size scales with it.
///
/// The [profile] may be null for placeholder rendering (e.g. while
/// the user record is still loading from cache/network) — in that case
/// a neutral person icon is shown.
class UserAvatar extends StatelessWidget {
  final UserProfile? profile;
  final double sizePx;

  const UserAvatar({
    super.key,
    required this.profile,
    this.sizePx = 40,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (profile == null) {
      return Container(
        width: sizePx,
        height: sizePx,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withAlpha(40),
          border: Border.all(
            color: scheme.primary.withAlpha(80),
            width: 1.5,
          ),
        ),
        child: Icon(Icons.person, size: sizePx * 0.55, color: scheme.primary),
      );
    }

    final p = profile!;
    return Container(
      width: sizePx,
      height: sizePx,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withAlpha(160)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: p.avatarImageUrl != null
            ? DecorationImage(
                image: NetworkImage(p.avatarImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: p.avatarImageUrl == null
          ? Center(
              child: Text(
                _initials(p),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: sizePx * 0.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  static String _initials(UserProfile p) {
    final first = p.firstName.isNotEmpty ? p.firstName[0] : '';
    final last = p.lastName.isNotEmpty ? p.lastName[0] : '';
    final combined = (first + last).toUpperCase();
    if (combined.isNotEmpty) return combined;
    return p.handle.isNotEmpty ? p.handle[0].toUpperCase() : '?';
  }
}
