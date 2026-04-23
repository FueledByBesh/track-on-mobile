import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/user.dart';
import 'package:trackon_mobile/data/services/follow_service.dart';

import 'profile_page.dart';

/// Either followers or following list — same layout, single page.
/// [showFollowers] picks which endpoint to hit.
class FollowersListPage extends StatefulWidget {
  final String userId;

  /// Displayed in the app-bar title. Pass the owner's display name so
  /// the page reads "alex's followers" / "alex's following".
  final String userName;

  final bool showFollowers;

  const FollowersListPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.showFollowers,
  });

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  late Future<List<UserPreview>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<UserPreview>> _load() {
    final follows = context.read<FollowApiService>();
    return widget.showFollowers
        ? follows.followersOf(widget.userId)
        : follows.followingOf(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.showFollowers ? 'Followers' : 'Following';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<UserPreview>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Could not load $title',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final users = snap.data ?? const [];
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.showFollowers
                      ? 'No followers yet'
                      : 'Not following anyone yet',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _UserRow(user: users[i]),
          );
        },
      ),
    );
  }
}

/// Single row in the followers / following list. Tapping the row
/// opens the user's profile; the trailing button is a compact
/// follow toggle that reflects the viewer's current relationship.
class _UserRow extends StatefulWidget {
  final UserPreview user;
  const _UserRow({required this.user});

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  late bool _isFollowing = widget.user.isFollowing;
  late bool _isPending = widget.user.hasPendingFollowRequest;
  bool _busy = false;

  Future<void> _toggle() async {
    final follows = context.read<FollowApiService>();
    setState(() => _busy = true);
    try {
      if (_isFollowing || _isPending) {
        await follows.unfollow(widget.user.id);
        setState(() {
          _isFollowing = false;
          _isPending = false;
        });
      } else {
        final action = await follows.follow(widget.user.id);
        setState(() {
          _isFollowing = action.isAccepted;
          _isPending = action.isPending;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final u = widget.user;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProfilePage(userId: u.id)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.primary.withAlpha(30),
              backgroundImage: u.avatarImageUrl != null
                  ? NetworkImage(u.avatarImageUrl!)
                  : null,
              child: u.avatarImageUrl == null
                  ? Text(
                      u.fullName.isNotEmpty ? u.fullName[0] : '?',
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  Text('@${u.handle}',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            _trailingButton(scheme),
          ],
        ),
      ),
    );
  }

  Widget _trailingButton(ColorScheme scheme) {
    if (_isPending) {
      return OutlinedButton(
        onPressed: _busy ? null : _toggle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Requested', style: TextStyle(fontSize: 12)),
      );
    }
    if (_isFollowing) {
      return OutlinedButton(
        onPressed: _busy ? null : _toggle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Following', style: TextStyle(fontSize: 12)),
      );
    }
    return ElevatedButton(
      onPressed: _busy ? null : _toggle,
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: const Text('Follow',
          style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
