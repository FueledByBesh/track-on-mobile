import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/club.dart';
import 'package:trackon_mobile/data/models/post.dart' as post_model;
import 'package:trackon_mobile/data/providers/groups_provider.dart';
import 'package:trackon_mobile/data/services/club_post_service.dart';
import 'package:trackon_mobile/data/services/club_service.dart';
import 'package:trackon_mobile/ui/sharedwidgets/profile_page.dart';
import 'club_notification_settings_page.dart';
import 'club_settings_page.dart';

/// Detail view for a single club. Loads the full [Club] + tab contents
/// from the API on open; state is local to this page (not held in a
/// provider) because per-club detail data is cheap to refetch when the
/// user navigates back.
class ClubDetailPage extends StatefulWidget {
  final String clubId;
  const ClubDetailPage({super.key, required this.clubId});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Club? _club;
  bool _loading = true;
  String? _error;
  bool _aboutVisible = false;

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
    final clubs = context.read<ClubApiService>();
    try {
      final club = await clubs.getById(widget.clubId);
      if (!mounted) return;
      setState(() {
        _club = club;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load club';
      });
    }
  }

  /// Hit after any action that may have changed the viewer's relationship
  /// with the club (join, request, leave, cancel request). Keeps the
  /// button state + the membership tabs in sync.
  Future<void> _reload() => _load();

  Future<void> _onJoinPressed() async {
    final club = _club;
    if (club == null) return;
    final provider = context.read<GroupsProvider>();
    try {
      if (!club.isPublic && club.hasPendingRequest) {
        // Clicking the "Requested" chip cancels the request.
        await provider.cancelMyJoinRequest(club.id);
      } else if (club.isPublic) {
        await provider.joinClub(club.id);
      } else {
        await provider.requestJoinClub(club.id);
      }
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }

  Future<void> _onLeave() async {
    final club = _club;
    if (club == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave club?'),
        content: Text('You\'ll stop seeing posts and challenges from '
            '${club.name}. You can rejoin anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await context.read<GroupsProvider>().leaveClub(club.id);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not leave club')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _club == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Club not found'),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final club = _club!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _ClubSliverHeader(
            club: club,
            onJoinPressed: _onJoinPressed,
            onLeave: _onLeave,
            aboutVisible: _aboutVisible,
            onToggleAbout: club.description != null &&
                    club.description!.isNotEmpty
                ? () => setState(() => _aboutVisible = !_aboutVisible)
                : null,
          ),
          if (club.banInfo != null)
            SliverToBoxAdapter(child: _BanBanner(banInfo: club.banInfo!)),
          if (club.description != null && club.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => SizeTransition(
                  sizeFactor: anim,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _aboutVisible
                    ? _ClubAboutCard(
                        key: const ValueKey('about-visible'),
                        club: club,
                        onClose: () => setState(() => _aboutVisible = false),
                      )
                    : const SizedBox.shrink(key: ValueKey('about-hidden')),
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
                  Tab(text: 'Posts'),
                  Tab(text: 'Challenges'),
                  Tab(text: 'Members'),
                ],
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ClubPostsTab(club: club),
            _ClubChallengesTab(club: club),
            _ClubMembersTab(club: club),
          ],
        ),
      ),
    );
  }
}

// ============ HEADER ============

class _ClubSliverHeader extends StatelessWidget {
  final Club club;
  final VoidCallback onJoinPressed;
  final VoidCallback onLeave;
  final bool aboutVisible;
  final VoidCallback? onToggleAbout;
  const _ClubSliverHeader({
    required this.club,
    required this.onJoinPressed,
    required this.onLeave,
    required this.aboutVisible,
    required this.onToggleAbout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final createdDate = _formatCreatedAt(club.createdAt);

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      title: Text(club.name),
      actions: [
        if (club.userRole == ClubRole.owner)
          IconButton(
            tooltip: 'Club settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubSettingsPage(club: club),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showClubMenu(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Avatar as background if we have one; else a gradient based
            // on the accent color.
            if (club.avatarImageUrl != null)
              Image.network(
                club.avatarImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _gradient(scheme),
              )
            else
              _gradient(scheme),
            // Dark overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(140),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                club.name,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!club.isPublic) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.lock,
                                  color: Colors.white.withAlpha(220),
                                  size: 18),
                            ],
                          ],
                        ),
                      ),
                      if (club.isMember && onToggleAbout != null)
                        _AboutToggleSwitcher(
                          expanded: aboutVisible,
                          onPressed: onToggleAbout!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people,
                          color: Colors.white.withAlpha(200), size: 14),
                      const SizedBox(width: 4),
                      Text('${club.memberCount} members',
                          style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: 13)),
                      const SizedBox(width: 12),
                      Icon(Icons.event,
                          color: Colors.white.withAlpha(200), size: 14),
                      const SizedBox(width: 4),
                      Text('Since $createdDate',
                          style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: 13)),
                    ],
                  ),
                  // Non-members get the Join/Request button row. Banned
                  // users see the button disabled from the banner below
                  // the hero; leave the hero button gone to avoid a
                  // confusing dual affordance.
                  if (!club.isMember && !club.isBanned) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _JoinButton(
                          isPublic: club.isPublic,
                          hasPendingRequest: club.hasPendingRequest,
                          onPressed: onJoinPressed,
                        ),
                        if (onToggleAbout != null) ...[
                          const SizedBox(width: 12),
                          _AboutToggleSwitcher(
                            expanded: aboutVisible,
                            onPressed: onToggleAbout!,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradient(ColorScheme scheme) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primary.withAlpha(180)],
          ),
        ),
      );

  String _formatCreatedAt(String iso) {
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  void _showClubMenu(BuildContext context) {
    final isOwner = club.userRole == ClubRole.owner;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share club'),
              onTap: () => Navigator.pop(context),
            ),
            if (club.isMember)
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const Text('Notification settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClubNotificationSettingsPage(club: club),
                    ),
                  );
                },
              ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text('Report club',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
            if (!isOwner && club.isMember)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Leave club',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onLeave();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final bool isPublic;
  final bool hasPendingRequest;
  final VoidCallback onPressed;
  const _JoinButton({
    required this.isPublic,
    required this.hasPendingRequest,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Private club with a pending request — outlined chip that cancels
    // the request on tap.
    if (!isPublic && hasPendingRequest) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.hourglass_top, color: Colors.white, size: 16),
        label: const Text('Requested',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withAlpha(180)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        ),
      );
    }

    final label = isPublic ? 'Join' : 'Request to Join';
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Fades + collapses the About toggle button when the About section is
/// visible so only one "About" label is on screen at a time.
class _AboutToggleSwitcher extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;
  const _AboutToggleSwitcher(
      {required this.expanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axis: Axis.horizontal,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: expanded
          ? const SizedBox.shrink(key: ValueKey('about-btn-hidden'))
          : _AboutToggle(
              key: const ValueKey('about-btn-visible'),
              expanded: expanded,
              onPressed: onPressed,
            ),
    );
  }
}

class _AboutToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;
  const _AboutToggle(
      {super.key, required this.expanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'About',
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withAlpha(160),
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 450),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withAlpha(230),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
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

// ============ BAN BANNER ============

class _BanBanner extends StatelessWidget {
  final ClubBanInfo banInfo;
  const _BanBanner({required this.banInfo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = banInfo.bannedUntil == null
        ? "You're banned from this club"
        : "You're banned from this club until "
            "${DateFormat('MMM d, yyyy').format(banInfo.bannedUntil!.toLocal())}";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withAlpha(90)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  if (banInfo.reason != null &&
                      banInfo.reason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(banInfo.reason!,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ABOUT CARD ============

class _ClubAboutCard extends StatelessWidget {
  final Club club;
  final VoidCallback onClose;
  const _ClubAboutCard(
      {super.key, required this.club, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final createdDate = _formatDate(club.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onClose,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'About',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_up,
                        size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (club.description != null &&
                      club.description!.isNotEmpty) ...[
                    Text(
                      club.description!,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 10),
                  ],
                  _MetaRow(
                      icon: Icons.alternate_email,
                      label: 'Handle',
                      value: '@${club.handle}'),
                  if (club.sportTypes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaRow(
                        icon: Icons.sports_score,
                        label: 'Sports',
                        value: club.sportTypes.join(' · ')),
                  ],
                  if (club.location != null && club.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaRow(
                        icon: Icons.place_outlined,
                        label: 'Location',
                        value: club.location!),
                  ],
                  const SizedBox(height: 8),
                  _MetaRow(
                    icon: club.isPublic ? Icons.public : Icons.lock_outline,
                    label: 'Visibility',
                    value: club.isPublic ? 'Public' : 'Private',
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                      icon: Icons.event_outlined,
                      label: 'Created',
                      value: createdDate),
                  const SizedBox(height: 8),
                  _MetaRow(
                      icon: Icons.person_outline,
                      label: 'Owner',
                      value: club.createdByName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}

// ============ POSTS TAB ============

class _ClubPostsTab extends StatefulWidget {
  final Club club;
  const _ClubPostsTab({required this.club});

  @override
  State<_ClubPostsTab> createState() => _ClubPostsTabState();
}

class _ClubPostsTabState extends State<_ClubPostsTab> {
  late Future<List<post_model.Post>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPosts();
  }

  Future<List<post_model.Post>> _loadPosts() {
    if (!widget.club.canViewPosts) return Future.value(const []);
    return context.read<ClubPostApiService>().getByClub(widget.club.id);
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    if (!club.canViewPosts) {
      return const _LockedSection(
        icon: Icons.lock_outline,
        label: 'Posts are private',
        detail: 'Join this club to see posts from its members.',
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _loadPosts());
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
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            );
          }
          final posts = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (club.isMember) ...[
                _PostComposer(clubName: club.name),
                const SizedBox(height: 16),
              ],
              ...posts.map((p) => _ClubPostCard(post: p)),
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.forum_outlined,
                            size: 40, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('No posts yet',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  final String clubName;
  const _PostComposer({required this.clubName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withAlpha(30),
            child: Icon(Icons.edit, color: scheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                // Compose flow TBD — hook into GroupsProvider.createClubPost
                // once the composer UI is designed.
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Share to $clubName...',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.image_outlined, color: scheme.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _ClubPostCard extends StatelessWidget {
  final post_model.Post post;
  const _ClubPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final initials = post.authorName.isNotEmpty
        ? post.authorName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
        : '?';

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
          Row(
            children: [
              // Avatar + name row is tappable — opens the author's
              // profile. The overflow button stays separate so it
              // doesn't fight the tap target.
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfilePage(userId: post.authorId)),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(100),
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text(initials,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: scheme.onSurface))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post.authorName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600)),
                            Text(_relativeTime(post.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color:
                                            scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _LikeTap(post: post, isLike: true),
              const SizedBox(width: 24),
              _LikeTap(post: post, isLike: false),
              const SizedBox(width: 24),
              Icon(Icons.mode_comment_outlined,
                  size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post.commentCount}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _LikeTap extends StatelessWidget {
  final post_model.Post post;
  final bool isLike;
  const _LikeTap({required this.post, required this.isLike});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active =
        isLike ? post.userLiked == true : post.userLiked == false;
    final count = isLike ? post.likes : post.dislikes;
    return GestureDetector(
      onTap: () => context
          .read<GroupsProvider>()
          .likePost(post.kind, post.id, isLike),
      child: Row(children: [
        Icon(
          isLike
              ? (active ? Icons.favorite : Icons.favorite_outline)
              : (active ? Icons.thumb_down : Icons.thumb_down_outlined),
          size: 20,
          color: active
              ? (isLike ? Colors.red : Colors.blue)
              : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

// ============ CHALLENGES TAB ============

class _ClubChallengesTab extends StatefulWidget {
  final Club club;
  const _ClubChallengesTab({required this.club});

  @override
  State<_ClubChallengesTab> createState() => _ClubChallengesTabState();
}

class _ClubChallengesTabState extends State<_ClubChallengesTab> {
  late Future<List<Challenge>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Challenge>> _load() {
    if (!widget.club.canViewChallenges) return Future.value(const []);
    return context
        .read<ClubApiService>()
        .getActiveChallenges(widget.club.id);
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    if (!club.canViewChallenges) {
      return const _LockedSection(
        icon: Icons.emoji_events_outlined,
        label: 'Challenges are private',
        detail: 'Join this club to see and compete in its challenges.',
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Challenge>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
              child: Text('Could not load challenges',
                  style: TextStyle(color: scheme.onSurfaceVariant)));
        }
        final challenges = snap.data ?? const [];
        if (challenges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('No challenges yet',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, i) =>
              _ChallengeCard(challenge: challenges[i]),
        );
      },
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final progress = challenge.userProgress != null
        ? (challenge.userProgress! / challenge.targetValue).clamp(0.0, 1.0)
        : 0.0;
    final isComplete = progress >= 1.0;
    final unit = challenge.targetType == 'STEPS' ? 'steps' : 'km';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: challenge.isSubscribed
              ? scheme.primary.withAlpha(80)
              : scheme.outlineVariant,
          width: challenge.isSubscribed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  challenge.targetType,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _dateRange(challenge.startDate, challenge.endDate),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            challenge.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (challenge.description != null) ...[
            const SizedBox(height: 4),
            Text(challenge.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          if (challenge.isSubscribed) ...[
            Row(
              children: [
                Text(
                  '${_formatValue(challenge.userProgress ?? 0)} / ${_formatValue(challenge.targetValue)} $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isComplete ? Colors.green : scheme.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                    isComplete ? Colors.green : scheme.primary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${challenge.subscriberCount} joined',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              if (challenge.isSubscribed)
                OutlinedButton(
                  onPressed: () {
                    context
                        .read<ClubApiService>()
                        .unsubscribeChallenge(challenge.id);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Leave'),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    context
                        .read<ClubApiService>()
                        .subscribeChallenge(challenge.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Join'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateRange(String start, String end) {
    try {
      final s = DateFormat('MMM d').format(DateTime.parse(start));
      final e = DateFormat('MMM d').format(DateTime.parse(end));
      return '$s – $e';
    } catch (_) {
      return '';
    }
  }

  String _formatValue(double v) {
    if (v >= 1000) return NumberFormat('#,###').format(v);
    return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
  }
}

// ============ MEMBERS TAB ============

class _ClubMembersTab extends StatefulWidget {
  final Club club;
  const _ClubMembersTab({required this.club});

  @override
  State<_ClubMembersTab> createState() => _ClubMembersTabState();
}

class _ClubMembersTabState extends State<_ClubMembersTab> {
  late Future<List<ClubMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ClubMember>> _load() {
    if (!widget.club.canViewMembers) return Future.value(const []);
    return context.read<ClubApiService>().getMembers(widget.club.id);
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    if (!club.canViewMembers) {
      return const _LockedSection(
        icon: Icons.people_outline,
        label: 'Members are private',
        detail: "Join this club to see who's in it.",
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<ClubMember>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
              child: Text('Could not load members',
                  style: TextStyle(color: scheme.onSurfaceVariant)));
        }
        final members = [...(snap.data ?? const <ClubMember>[])];
        members.sort((a, b) => a.role.index.compareTo(b.role.index));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = members[i];
            final cardColor =
                Theme.of(context).cardTheme.color ?? scheme.surface;
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: m.userId)),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primary.withAlpha(30),
                      child: Text(
                        m.name.isNotEmpty ? m.name[0] : '?',
                        style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface)),
                          Text(m.email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    _RoleBadge(role: m.role),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final ClubRole role;
  const _RoleBadge({required this.role});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
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

class _LockedSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  const _LockedSection({
    required this.icon,
    required this.label,
    required this.detail,
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
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
