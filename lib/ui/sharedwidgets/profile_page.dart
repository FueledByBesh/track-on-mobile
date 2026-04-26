import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/post.dart' as post_model;
import 'package:trackon_mobile/data/models/user.dart';
import 'package:trackon_mobile/data/models/user_activity_stats.dart';
import 'package:trackon_mobile/data/providers/groups_provider.dart';
import 'package:trackon_mobile/data/services/club_post_service.dart';
import 'package:trackon_mobile/data/services/follow_service.dart';
import 'package:trackon_mobile/data/services/user_post_service.dart';
import 'package:trackon_mobile/data/services/user_service.dart';

import 'followers_list_page.dart';
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
  static const int _windowDays = 30;

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
      final data = widget.profile.isSelf
          ? await api.getMyActivityStats(days: _windowDays)
          : await api.getActivityStatsById(
              widget.profile.id,
              days: _windowDays,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_run,
                  size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                widget.profile.isSelf
                    ? 'No activity in the last $_windowDays days.'
                    : 'No recent activity.',
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _WindowLabel(days: d.windowDays),
        const SizedBox(height: 10),
        _HeadlineStrip(totals: d.totals),
        const SizedBox(height: 16),
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

class _WindowLabel extends StatelessWidget {
  final int days;
  const _WindowLabel({required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      'LAST $days DAYS',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
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
  final Widget child;
  const _Section({required this.title, required this.child});

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
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
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
  late Future<List<post_model.Post>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Fetches both kinds in parallel and interleaves by createdAt DESC.
  /// Mirrors the backend feed composition for a single user's timeline.
  Future<List<post_model.Post>> _load() async {
    if (!_canViewContent(widget.profile, widget.stats)) return const [];
    final clubPosts = context.read<ClubPostApiService>();
    final userPosts = context.read<UserPostApiService>();
    final results = await Future.wait([
      clubPosts.getByAuthor(widget.profile.id),
      userPosts.getByAuthor(widget.profile.id),
    ]);
    final merged = [...results[0], ...results[1]];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
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
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        await _future;
      },
      child: FutureBuilder<List<post_model.Post>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Text('Could not load posts',
                    style: TextStyle(color: scheme.onSurfaceVariant)));
          }
          final posts = snap.data ?? const [];
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.profile.isSelf
                      ? "You haven't posted yet."
                      : 'No posts yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, i) => _ProfilePostCard(post: posts[i]),
          );
        },
      ),
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  final post_model.Post post;
  const _ProfilePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kind badge: club name for club posts, "Personal" for user posts.
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  post.kind == post_model.PostKind.club
                      ? (post.clubName ?? 'Club')
                      : 'Personal',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(_relativeTime(post.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_outline,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post.likes}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 16),
              Icon(Icons.mode_comment_outlined,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post.commentCount}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

String _relativeTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
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

class _ClubsTab extends StatelessWidget {
  final UserProfile profile;
  final UserStats stats;
  const _ClubsTab({required this.profile, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (!_canViewContent(profile, stats)) {
      return const _LockedTab(
        icon: Icons.groups_outlined,
        label: 'Clubs are private',
        detail: 'Follow this user to see their clubs.',
      );
    }
    if (!profile.isSelf) {
      final scheme = Theme.of(context).colorScheme;
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
    // Self-view — reuse the provider's already-loaded grouping.
    final provider = context.watch<GroupsProvider>();
    final all = provider.allMyClubs;
    final scheme = Theme.of(context).colorScheme;
    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text("You haven't joined any clubs yet.",
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: all.length,
      itemBuilder: (context, i) {
        final c = all[i];
        final cardColor =
            Theme.of(context).cardTheme.color ?? scheme.surface;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.groups, size: 22, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    Text('@${c.handle}',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}
