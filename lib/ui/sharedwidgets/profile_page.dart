import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/club.dart';
import 'package:trackon_mobile/data/models/post.dart' as post_model;
import 'package:trackon_mobile/data/models/user.dart';
import 'package:trackon_mobile/data/models/user_activity_stats.dart';
import 'package:trackon_mobile/data/providers/groups_provider.dart';
import 'package:trackon_mobile/data/services/club_post_service.dart';
import 'package:trackon_mobile/data/services/follow_service.dart';
import 'package:trackon_mobile/data/services/user_post_service.dart';
import 'package:trackon_mobile/data/services/user_service.dart';

import '../pages/clubs/club_detail_page.dart';
import '../pages/groups/create_post_page.dart';
import '../pages/groups/post_detail_page.dart';
import 'followers_list_page.dart';
import 'post_attachments_viewer.dart';
import 'edit_profile_page.dart';
import 'user_avatar.dart';

/// Unified profile page for both the viewer's own profile and any
/// other user's.
///
/// The page hits two endpoints in parallel: the cacheable profile
/// core ([UserProfile]) and the live stats ([UserStats]). Profile
/// core is usually a 304 so the cached copy powers the header with
/// almost no latency; stats almost always returns fresh counts. The
/// follow-state machine on the header (Follow / Requested / Following)
/// drives off stats; the Edit pencil on self-view drives off profile.
///
/// Private profiles render a locked state on the content tabs when the
/// viewer isn't following — matches the ClubDetailPage gating pattern.
class ProfilePage extends StatefulWidget {
  /// Target user id. Pass `null` to show the current user's profile
  /// (page fetches via `/api/users/me`). Useful for the settings-tab
  /// "Profile" entry point which doesn't carry an id.
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _profile;
  UserStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final users = context.read<UserApiService>();
    try {
      final results = widget.userId == null
          ? await Future.wait([users.getMe(), users.getMyStats()])
          : await Future.wait([
              users.getById(widget.userId!),
              users.getStatsById(widget.userId!),
            ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _stats = results[1] as UserStats;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load profile';
      });
    }
  }

  /// Re-fetch stats after any follow-state change. Profile core doesn't
  /// move when someone follows, so there's no reason to refetch it.
  Future<void> _reloadStats() async {
    final users = context.read<UserApiService>();
    try {
      final fresh = widget.userId == null
          ? await users.getMyStats()
          : await users.getStatsById(widget.userId!);
      if (!mounted) return;
      setState(() => _stats = fresh);
    } catch (_) {
      // Non-fatal; the stale stats stay visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _profile == null || _stats == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Profile not found'),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _profile!;
    final s = _stats!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _HandleTitle(handle: p.handle),
        actions: [
          if (p.isSelf)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await Navigator.push<UserProfile>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditProfilePage(profile: p)),
                );
                if (updated != null && mounted) {
                  setState(() => _profile = updated);
                }
              },
            ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: p,
              stats: s,
              onFollowChanged: _reloadStats,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: scheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: scheme.primary,
                tabs: const [
                  Tab(text: 'Activity'),
                  Tab(text: 'Posts'),
                  Tab(text: 'Clubs'),
                ],
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ActivityTab(profile: p, stats: s),
            _PostsTab(profile: p, stats: s),
            _ClubsTab(profile: p, stats: s),
          ],
        ),
      ),
    );
  }
}

// ============ APPBAR TITLE ============

/// `@handle` + copy-to-clipboard icon. Shown as the AppBar title so the
/// handle is always visible (and copyable) without cluttering the
/// header body with a duplicate.
class _HandleTitle extends StatelessWidget {
  final String handle;
  const _HandleTitle({required this.handle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '@$handle',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => _copy(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.content_copy,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '@$handle'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('@$handle copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============ HEADER ============

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final UserStats stats;

  /// Called after a follow/unfollow/request action so the page can
  /// refetch stats.
  final VoidCallback onFollowChanged;

  const _ProfileHeader({
    required this.profile,
    required this.stats,
    required this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: avatar (left) + compact stats (right).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(profile: profile, sizePx: 84),
              const SizedBox(width: 20),
              Expanded(child: _StatsRow(profile: profile, stats: stats)),
            ],
          ),
          const SizedBox(height: 12),
          // Name (bold), bio, location — below the avatar row.
          Text(
            profile.fullName.isNotEmpty
                ? profile.fullName
                : '@${profile.handle}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              profile.bio!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.35,
                  ),
            ),
          ],
          if (profile.location != null && profile.location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(profile.location!,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
          if (!profile.isSelf) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _FollowButton(
                profile: profile,
                stats: stats,
                onChanged: onFollowChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Follow / Requested / Following button state machine. Non-self only.
/// Optimistic toggle — the underlying re-fetch via `onChanged` keeps
/// counts in sync afterward.
class _FollowButton extends StatefulWidget {
  final UserProfile profile;
  final UserStats stats;
  final VoidCallback onChanged;
  const _FollowButton({
    required this.profile,
    required this.stats,
    required this.onChanged,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    final s = widget.stats;
    setState(() => _busy = true);
    try {
      final follows = context.read<FollowApiService>();
      if (s.isFollowing || s.hasPendingFollowRequest) {
        await follows.unfollow(widget.profile.id);
      } else {
        await follows.follow(widget.profile.id);
      }
      widget.onChanged();
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
    final s = widget.stats;

    if (s.hasPendingFollowRequest) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : _onPressed,
        icon: const Icon(Icons.hourglass_top, size: 16),
        label: const Text('Requested'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        ),
      );
    }
    if (s.isFollowing) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : _onPressed,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Following'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        ),
      );
    }
    return ElevatedButton(
      onPressed: _busy ? null : _onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      ),
      child: const Text('Follow',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Four tappable tiles: Posts / Followers / Following / Clubs.
/// Followers and Following push to [FollowersListPage]. Posts and
/// Clubs don't navigate yet — they scroll you to the relevant tab
/// instead (or no-op for now).
class _StatsRow extends StatelessWidget {
  final UserProfile profile;
  final UserStats stats;
  const _StatsRow({required this.profile, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatTile(
            label: 'Posts', value: stats.postsCount, onTap: null),
        _StatTile(
          label: 'Followers',
          value: stats.followersCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowersListPage(
                userId: profile.id,
                userName: profile.fullName,
                showFollowers: true,
              ),
            ),
          ),
        ),
        _StatTile(
          label: 'Following',
          value: stats.followingCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowersListPage(
                userId: profile.id,
                userName: profile.fullName,
                showFollowers: false,
              ),
            ),
          ),
        ),
        _StatTile(
            label: 'Clubs', value: stats.clubsCount, onTap: null),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;
  const _StatTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatCount(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: content,
      ),
    );
  }

  /// "1.2k" / "2.3M" style. Small counts render as-is.
  static String _formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 1_000_000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v < 10 ? 1 : 0)}k';
    }
    final v = n / 1_000_000;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)}M';
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  _TabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) =>
      old.tabBar != tabBar || old.backgroundColor != backgroundColor;
}

// ============ PRIVATE GATING HELPER ============

/// True iff the viewer can read this profile's content tabs.
/// Mirrors the backend `UserAccessEvaluator.canViewContent` rule.
bool _canViewContent(UserProfile p, UserStats s) =>
    p.isSelf || p.isProfilePublic || s.isFollowing;

class _LockedTab extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  const _LockedTab({
    required this.label,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    )),
            const SizedBox(height: 6),
            Text(detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ============ ACTIVITY TAB ============
//
// Activity listing for other users needs a new /api/activities/user/{id}
// endpoint with its own public/private gating. Deferred. For now the
// tab shows a lightweight "coming soon" even for self — the Home page
// is the canonical place to see your own activities today.

class _ActivityTab extends StatefulWidget {
  final UserProfile profile;
  final UserStats stats;
  const _ActivityTab({required this.profile, required this.stats});

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  _WindowPreset _preset = _WindowPreset.last30;

  UserActivityStats? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_canViewContent(widget.profile, widget.stats)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<UserApiService>();
      final days = _preset.days;
      final data = widget.profile.isSelf
          ? await api.getMyActivityStats(days: days)
          : await api.getActivityStatsById(
              widget.profile.id,
              days: days,
            );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load activity stats';
      });
    }
  }

  void _changePreset(_WindowPreset p) {
    if (p == _preset) return;
    setState(() => _preset = p);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewContent(widget.profile, widget.stats)) {
      return const _LockedTab(
        icon: Icons.lock_outline,
        label: 'Activity is private',
        detail: 'Follow this user to see their runs and workouts.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final d = _data;
    if (d == null || d.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      // Keep the chooser visible so the user can widen the window
      // to find activity outside the empty preset.
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _WindowChooser(selected: _preset, onChanged: _changePreset),
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_run,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  widget.profile.isSelf
                      ? 'No activity in this period.'
                      : 'No recent activity.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _WindowChooser(selected: _preset, onChanged: _changePreset),
        const SizedBox(height: 14),
        _HeadlineStrip(totals: d.totals),
        const SizedBox(height: 16),
        if (d.records.any((r) => !r.isEmpty)) ...[
          _Section(
            title: 'Personal records',
            subtitle: 'Best · ${_preset.label}',
            child: _PersonalRecordsStrip(records: d.records),
          ),
          const SizedBox(height: 12),
        ],
        _Section(
          title: 'Last 12 weeks',
          subtitle: 'Daily activity heatmap',
          child: _ActivityHeatmapCalendar(days: d.heatmap),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Weekly distance',
          child: _WeeklyBarChart(weekly: d.weekly),
        ),
        const SizedBox(height: 12),
        if (d.types.isNotEmpty)
          _Section(
            title: 'By activity type',
            child: _TypeDonut(types: d.types),
          ),
      ],
    );
  }
}

// ============ ACTIVITY-TAB WIDGETS ============

enum _WindowPreset {
  thisMonth,
  last30,
  last15,
  last7,
  allTime,
}

extension _WindowPresetX on _WindowPreset {
  String get label => switch (this) {
        _WindowPreset.thisMonth => 'This month',
        _WindowPreset.last30 => 'Last 30 days',
        _WindowPreset.last15 => 'Last 15 days',
        _WindowPreset.last7 => 'Last 7 days',
        _WindowPreset.allTime => 'All time',
      };

  /// How many days the backend should look back for this preset.
  int get days {
    switch (this) {
      case _WindowPreset.thisMonth:
        // Days elapsed in the current calendar month (incl. today).
        return DateTime.now().day;
      case _WindowPreset.last30:
        return 30;
      case _WindowPreset.last15:
        return 15;
      case _WindowPreset.last7:
        return 7;
      case _WindowPreset.allTime:
        // Big enough to cover anyone's activity history. Backend
        // clamps to 365 — that's fine; "all time" effectively means
        // "as far back as the server allows".
        return 36500;
    }
  }
}

class _WindowChooser extends StatelessWidget {
  final _WindowPreset selected;
  final ValueChanged<_WindowPreset> onChanged;

  const _WindowChooser({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in _WindowPreset.values) ...[
            _Chip(
              label: p.label,
              active: p == selected,
              scheme: scheme,
              onTap: () => onChanged(p),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HeadlineStrip extends StatelessWidget {
  final ActivityTotals totals;
  const _HeadlineStrip({required this.totals});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 2-up grid so long values (e.g. 3-digit km) don't crush each other.
    return LayoutBuilder(
      builder: (context, c) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _headlineCell(
              scheme: scheme,
              width: (c.maxWidth - 10) / 2,
              label: 'Distance',
              value: '${totals.distanceKm.toStringAsFixed(1)} km',
              icon: Icons.route,
            ),
            _headlineCell(
              scheme: scheme,
              width: (c.maxWidth - 10) / 2,
              label: 'Sessions',
              value: '${totals.sessions}',
              icon: Icons.fitness_center,
            ),
            _headlineCell(
              scheme: scheme,
              width: (c.maxWidth - 10) / 2,
              label: 'Time',
              value: _formatDuration(totals.durationSeconds),
              icon: Icons.timer_outlined,
            ),
            _headlineCell(
              scheme: scheme,
              width: (c.maxWidth - 10) / 2,
              label: 'Longest',
              value: '${totals.longestKm.toStringAsFixed(1)} km',
              icon: Icons.emoji_events_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _headlineCell({
    required ColorScheme scheme,
    required double width,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<ActivityWeekBucket> weekly;
  const _WeeklyBarChart({required this.weekly});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (weekly.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No weekly data',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    final maxY = weekly
            .map((w) => w.totalKm)
            .fold<double>(0, (a, b) => a > b ? a : b) *
        1.15;

    // Colors reused in the donut below so the visual mapping stays
    // consistent: run=primary, bike=tertiary, walk=secondary.
    final runColor = scheme.primary;
    final bikeColor = scheme.tertiary;
    final walkColor = scheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY > 0 ? maxY : 1,
              barGroups: [
                for (int i = 0; i < weekly.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weekly[i].totalKm,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        rodStackItems: [
                          BarChartRodStackItem(
                              0, weekly[i].runningKm, runColor),
                          BarChartRodStackItem(
                            weekly[i].runningKm,
                            weekly[i].runningKm + weekly[i].bikingKm,
                            bikeColor,
                          ),
                          BarChartRodStackItem(
                            weekly[i].runningKm + weekly[i].bikingKm,
                            weekly[i].totalKm,
                            walkColor,
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withAlpha(80),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= weekly.length) {
                        return const SizedBox.shrink();
                      }
                      // Only label every other bar so they don't crush
                      // on narrow screens. Show the week-start in M/d.
                      if (weekly.length > 6 && idx % 2 != 0) {
                        return const SizedBox.shrink();
                      }
                      final date =
                          DateTime.tryParse(weekly[idx].weekStart);
                      if (date == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('M/d').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, _) => Text(
                      value.toInt() == 0
                          ? ''
                          : '${value.toInt()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendDot(color: runColor, label: 'Run'),
            const SizedBox(width: 12),
            _LegendDot(color: bikeColor, label: 'Bike'),
            const SizedBox(width: 12),
            _LegendDot(color: walkColor, label: 'Walk'),
            const Spacer(),
            Text(
              'km',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeDonut extends StatelessWidget {
  final List<ActivityTypeShare> types;
  const _TypeDonut({required this.types});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = types.fold<double>(0, (a, b) => a + b.distanceKm);
    if (total <= 0) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No type breakdown',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    final slices = types.map((t) {
      final pct = (t.distanceKm / total) * 100;
      return PieChartSectionData(
        value: t.distanceKm,
        color: _typeColor(t.activityType, scheme),
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        radius: 42,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sections: slices,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in types)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _LegendDot(
                    color: _typeColor(t.activityType, scheme),
                    label:
                        '${_typeLabel(t.activityType)} · ${t.distanceKm.toStringAsFixed(1)} km',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _typeColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'RUNNING':
        return scheme.primary;
      case 'BIKING':
        return scheme.tertiary;
      case 'WALKING':
        return scheme.secondary;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'RUNNING':
        return 'Running';
      case 'BIKING':
        return 'Biking';
      case 'WALKING':
        return 'Walking';
      default:
        return type;
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ============ PERSONAL RECORDS STRIP ============

class _PersonalRecordsStrip extends StatefulWidget {
  final List<ActivityRecordsByType> records;
  const _PersonalRecordsStrip({required this.records});

  @override
  State<_PersonalRecordsStrip> createState() =>
      _PersonalRecordsStripState();
}

class _PersonalRecordsStripState extends State<_PersonalRecordsStrip> {
  /// Index into `widget.records` of the currently-shown type. The list
  /// comes back from the server sorted by total distance, so 0 is the
  /// user's most-active type.
  int _selected = 0;

  /// Activity types we know how to icon. Anything else falls back to
  /// the generic `directions_run` icon.
  IconData _iconFor(String type) => switch (type.toUpperCase()) {
        'RUNNING' => Icons.directions_run,
        'BIKING' || 'CYCLING' => Icons.directions_bike,
        'WALKING' => Icons.directions_walk,
        _ => Icons.directions_run,
      };

  String _labelFor(String type) =>
      type.isEmpty ? '—' : type[0] + type.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.records.isEmpty) return const SizedBox.shrink();
    final selected = widget.records[_selected.clamp(0, widget.records.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type chip row — only renders when the user has more than one
        // activity type with data; otherwise the chips would be a row
        // of one and add visual noise for nothing.
        if (widget.records.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < widget.records.length; i++) ...[
                  _TypeChip(
                    icon: _iconFor(widget.records[i].activityType),
                    label: _labelFor(widget.records[i].activityType),
                    active: i == _selected,
                    scheme: scheme,
                    onTap: () => setState(() => _selected = i),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2x2 grid of record tiles for the selected type.
        Row(children: [
          Expanded(
            child: _RecordTile(
              icon: Icons.straighten,
              label: 'Longest',
              value: selected.longestKm > 0
                  ? '${selected.longestKm.toStringAsFixed(2)} km'
                  : '—',
              scheme: scheme,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RecordTile(
              icon: Icons.timer_outlined,
              label: 'Longest time',
              value: selected.longestDurationSeconds > 0
                  ? _formatDuration(selected.longestDurationSeconds)
                  : '—',
              scheme: scheme,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _RecordTile(
              icon: Icons.bolt,
              label: 'Fastest pace',
              value: selected.fastestPaceMinPerKm > 0
                  ? _formatPace(selected.fastestPaceMinPerKm)
                  : '—',
              scheme: scheme,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RecordTile(
              icon: Icons.repeat,
              label: 'Sessions',
              value: selected.sessions > 0 ? '${selected.sessions}' : '—',
              scheme: scheme,
            ),
          ),
        ]),
      ],
    );
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  static String _formatPace(double minPerKm) {
    final m = minPerKm.floor();
    final sec = ((minPerKm - m) * 60).round();
    return "$m'${sec.toString().padLeft(2, '0')}\"";
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withAlpha(30)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? scheme.primary.withAlpha(120)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  const _RecordTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ ACTIVITY HEATMAP CALENDAR ============

class _ActivityHeatmapCalendar extends StatelessWidget {
  final List<ActivityHeatmapDay> days;
  const _ActivityHeatmapCalendar({required this.days});

  static const int _weeks = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Index sparse data by ISO date for O(1) lookup while painting.
    final byDay = <String, ActivityHeatmapDay>{
      for (final d in days) d.day: d,
    };

    // Find the max for color scaling. Falls back to 1 to avoid /0.
    final maxKm =
        days.fold<double>(0, (m, d) => d.distanceKm > m ? d.distanceKm : m);
    final scale = maxKm <= 0 ? 1.0 : maxKm;

    // The grid runs 12 columns (weeks) × 7 rows (days). The most recent
    // week is the rightmost column. Each column starts on Monday.
    final today = DateTime.now();
    // Snap to ISO Monday of this week.
    final mondayThisWeek =
        today.subtract(Duration(days: today.weekday - 1));

    final cols = <Widget>[];
    for (int w = _weeks - 1; w >= 0; w--) {
      final colDays = <Widget>[];
      for (int d = 0; d < 7; d++) {
        final cellDate = mondayThisWeek
            .subtract(Duration(days: w * 7))
            .add(Duration(days: d));
        // Future dates within the current week → empty/dimmed cell.
        final isFuture =
            cellDate.isAfter(DateTime(today.year, today.month, today.day));
        final key = _isoKey(cellDate);
        final entry = byDay[key];
        final dist = entry?.distanceKm ?? 0;
        colDays.add(_HeatCell(
          intensity: isFuture ? -1 : dist / scale,
          scheme: scheme,
          tooltip: isFuture
              ? null
              : entry == null
                  ? '${cellDate.day}/${cellDate.month} · No activity'
                  : '${cellDate.day}/${cellDate.month} · '
                      '${entry.distanceKm.toStringAsFixed(1)} km · '
                      '${entry.sessions} session${entry.sessions == 1 ? "" : "s"}',
        ));
        if (d < 6) colDays.add(const SizedBox(height: 3));
      }
      cols.add(Column(children: colDays));
      if (w > 0) cols.add(const SizedBox(width: 3));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(children: cols),
        ),
        const SizedBox(height: 10),
        // Legend strip
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less',
                style: TextStyle(
                    fontSize: 10, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            for (final i in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
              _HeatCell(intensity: i, scheme: scheme),
              const SizedBox(width: 2),
            ],
            const SizedBox(width: 4),
            Text('More',
                style: TextStyle(
                    fontSize: 10, color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  static String _isoKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

class _HeatCell extends StatelessWidget {
  /// -1 = future (dimmed), 0..1 = activity intensity.
  final double intensity;
  final ColorScheme scheme;
  final String? tooltip;

  const _HeatCell({
    required this.intensity,
    required this.scheme,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (intensity < 0) {
      color = scheme.surfaceContainerHighest.withAlpha(80);
    } else if (intensity == 0) {
      color = scheme.surfaceContainerHighest;
    } else {
      // Step into 4 buckets so the gradient looks like GitHub's.
      final step = intensity <= 0.25
          ? 60
          : intensity <= 0.5
              ? 110
              : intensity <= 0.75
                  ? 180
                  : 230;
      color = scheme.primary.withAlpha(step);
    }
    final cell = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    if (tooltip == null) return cell;
    return Tooltip(message: tooltip!, child: cell);
  }
}

// ============ POSTS TAB ============

class _PostsTab extends StatefulWidget {
  final UserProfile profile;
  final UserStats stats;
  const _PostsTab({required this.profile, required this.stats});

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  List<post_model.Post> _posts = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches both kinds in parallel and interleaves by createdAt DESC.
  /// [silent] skips the spinner — used for refreshes after actions
  /// (like/dislike, post create, returning from detail).
  Future<void> _load({bool silent = false}) async {
    if (!_canViewContent(widget.profile, widget.stats)) {
      if (mounted) setState(() { _posts = const []; _loading = false; });
      return;
    }
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final clubPosts = context.read<ClubPostApiService>();
      final userPosts = context.read<UserPostApiService>();
      final results = await Future.wait([
        clubPosts.getByAuthor(widget.profile.id),
        userPosts.getByAuthor(widget.profile.id),
      ]);
      final merged = [...results[0], ...results[1]];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _posts = merged;
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _openComposer() async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
    if (refreshed == true) _load(silent: true);
  }

  Future<void> _openPost(post_model.Post post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
    );
    // The detail page can mutate likes/dislikes/comments; refresh on
    // return so the list reflects the latest server state.
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewContent(widget.profile, widget.stats)) {
      return const _LockedTab(
        icon: Icons.forum_outlined,
        label: 'Posts are private',
        detail: 'Follow this user to see their posts.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final isSelf = widget.profile.isSelf;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Text('Could not load posts',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _posts.isEmpty
          ? ListView(
              children: [
                if (isSelf)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _ComposeRow(onTap: _openComposer),
                  ),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 48, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        isSelf
                            ? "You haven't posted yet."
                            : 'No posts yet.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      if (isSelf) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _openComposer,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Create your first post'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _posts.length + (isSelf ? 1 : 0),
              itemBuilder: (context, i) {
                if (isSelf && i == 0) {
                  return _ComposeRow(onTap: _openComposer);
                }
                final post = _posts[isSelf ? i - 1 : i];
                return _ProfilePostCard(
                  post: post,
                  onChanged: () => _load(silent: true),
                  onTap: () => _openPost(post),
                );
              },
            ),
    );
  }
}

class _ComposeRow extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposeRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              "What's on your mind?",
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  final post_model.Post post;

  /// Called after a like/dislike toggle so the parent can refresh its
  /// list and pick up the new counts from the server.
  final VoidCallback? onChanged;

  /// Override the default "open detail page" behavior — used so the
  /// parent can refresh its list when the user returns from detail.
  final VoidCallback? onTap;

  const _ProfilePostCard({
    required this.post,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kind badge + timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.kind == post_model.PostKind.club
                        ? (post.clubName ?? 'Club')
                        : 'Personal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(_localDateTime(post.createdAt),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),

          // Content + attachments — tap anywhere to open detail.
          InkWell(
            onTap: onTap ??
                () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PostDetailPage(post: post)),
                    ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    post.content,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.45),
                  ),
                ),
                if (post.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child:
                        PostAttachmentsViewer(attachments: post.attachments),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: scheme.outlineVariant),

          // Action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _ProfileActionBtn(
                  icon: post.userLiked == true
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_up_outlined,
                  label: '${post.likes}',
                  color: post.userLiked == true
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  onTap: () async {
                    await context
                        .read<GroupsProvider>()
                        .likePost(post.kind, post.id, true);
                    onChanged?.call();
                  },
                ),
                _ProfileActionBtn(
                  icon: post.userLiked == false
                      ? Icons.thumb_down_rounded
                      : Icons.thumb_down_outlined,
                  label: '${post.dislikes}',
                  color: post.userLiked == false
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  onTap: () async {
                    await context
                        .read<GroupsProvider>()
                        .likePost(post.kind, post.id, false);
                    onChanged?.call();
                  },
                ),
                _ProfileActionBtn(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.commentCount}',
                  color: scheme.onSurfaceVariant,
                  onTap: onTap ??
                      () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    PostDetailPage(post: post)),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ProfileActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local date + time, e.g. "28 Apr · 14:32" (current year) or
/// "12 Mar 2024 · 14:32" (prior years).
String _localDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year) {
      return '${dt.day} ${months[dt.month - 1]} · $hh:$mm';
    }
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hh:$mm';
  } catch (_) {
    return '';
  }
}

// ============ CLUBS TAB ============
//
// For the viewer's own profile we use the grouped `/api/clubs/mine`
// endpoint via GroupsProvider. For other users there's no endpoint
// yet that returns "clubs user X is in" scoped to the viewer's
// visibility — that's a Chunk-later item. For now non-self shows a
// placeholder.

class _ClubsTab extends StatefulWidget {
  final UserProfile profile;
  final UserStats stats;
  const _ClubsTab({required this.profile, required this.stats});

  @override
  State<_ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<_ClubsTab> {
  @override
  void initState() {
    super.initState();
    // Ensure the provider has fresh data when the tab opens. The
    // provider's loadMyClubs() internally guards against duplicate
    // concurrent calls, but a direct call here means we don't depend
    // on the user having visited the Groups tab first.
    if (widget.profile.isSelf) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<GroupsProvider>().loadMyClubs();
      });
    }
  }

  Future<void> _refresh() =>
      context.read<GroupsProvider>().loadMyClubs();

  @override
  Widget build(BuildContext context) {
    if (!_canViewContent(widget.profile, widget.stats)) {
      return const _LockedTab(
        icon: Icons.groups_outlined,
        label: 'Clubs are private',
        detail: 'Follow this user to see their clubs.',
      );
    }

    final scheme = Theme.of(context).colorScheme;

    if (!widget.profile.isSelf) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Clubs listing for other users coming soon.',
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final provider = context.watch<GroupsProvider>();
    final all = provider.allMyClubs;

    if (all.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined,
                        size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text("You haven't joined any clubs yet.",
                        style:
                            TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: all.length,
        itemBuilder: (context, i) => _ProfileClubCard(club: all[i]),
      ),
    );
  }
}

class _ProfileClubCard extends StatelessWidget {
  final Club club;
  const _ProfileClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ClubDetailPage(clubId: club.id)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.groups,
                      size: 28, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              club.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!club.isPublic) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock,
                                size: 13,
                                color: scheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${club.handle} · ${club.memberCount} ${club.memberCount == 1 ? "member" : "members"}',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (club.userRole != null) ...[
                        const SizedBox(height: 8),
                        _ProfileClubRoleTag(role: club.userRole!),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileClubRoleTag extends StatelessWidget {
  final ClubRole role;
  const _ProfileClubRoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, label) = switch (role) {
      ClubRole.owner =>
        (Colors.amber.withAlpha(40), Colors.amber.shade800, 'OWNER'),
      ClubRole.admin =>
        (scheme.primary.withAlpha(30), scheme.primary, 'ADMIN'),
      ClubRole.member => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          'MEMBER'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
