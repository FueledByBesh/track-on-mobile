import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trackon_mobile/data/models/club.dart';
import 'package:trackon_mobile/data/models/post.dart';
import 'club_notification_settings_page.dart';
import 'club_settings_page.dart';
import 'mock_clubs.dart';

class ClubDetailPage extends StatefulWidget {
  final Club club;
  const ClubDetailPage({super.key, required this.club});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Club _club;
  bool _aboutVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _club = widget.club;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleMembership() {
    setState(() {
      // For private clubs the user hasn't joined: toggle a pending request
      // instead of joining. Mock-only — the backend will do this properly.
      if (!_club.isPublic && !_club.isMember) {
        _club = _copyWith(hasPendingRequest: !_club.hasPendingRequest);
        return;
      }
      _club = _copyWith(
        isMember: !_club.isMember,
        memberCount: _club.isMember
            ? _club.memberCount - 1
            : _club.memberCount + 1,
        hasPendingRequest: false,
      );
    });
  }

  Club _copyWith({
    bool? isMember,
    int? memberCount,
    bool? hasPendingRequest,
  }) {
    return Club(
      id: _club.id,
      name: _club.name,
      handle: _club.handle,
      description: _club.description,
      createdByName: _club.createdByName,
      memberCount: memberCount ?? _club.memberCount,
      isMember: isMember ?? _club.isMember,
      createdAt: _club.createdAt,
      sportTypes: _club.sportTypes,
      location: _club.location,
      userRole: _club.userRole,
      isPublic: _club.isPublic,
      hasPendingRequest: hasPendingRequest ?? _club.hasPendingRequest,
      nonMembersCanViewPosts: _club.nonMembersCanViewPosts,
      nonMembersCanViewChallenges: _club.nonMembersCanViewChallenges,
      nonMembersCanViewMembers: _club.nonMembersCanViewMembers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _ClubSliverHeader(
            club: _club,
            onJoinToggle: _toggleMembership,
            aboutVisible: _aboutVisible,
            onToggleAbout: _club.description != null &&
                    _club.description!.isNotEmpty
                ? () => setState(() => _aboutVisible = !_aboutVisible)
                : null,
          ),
          if (_club.description != null && _club.description!.isNotEmpty)
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
                        club: _club,
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
              backgroundColor:
                  Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ClubPostsTab(club: _club),
            _ClubChallengesTab(club: _club),
            _ClubMembersTab(club: _club),
          ],
        ),
      ),
    );
  }
}

// ============ HEADER ============

class _ClubSliverHeader extends StatelessWidget {
  final Club club;
  final VoidCallback onJoinToggle;
  final bool aboutVisible;
  final VoidCallback? onToggleAbout;
  const _ClubSliverHeader({
    required this.club,
    required this.onJoinToggle,
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
        if (club.userRole == 'OWNER')
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
            // Gradient cover (replace with real cover image later)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    scheme.primary.withAlpha(180),
                  ],
                ),
              ),
            ),
            // Dark overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(100),
                  ],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row — for joined members, the About toggle lives
                  // here to save vertical space for the hero image.
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
                      Text(
                        '${club.memberCount} members',
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.event,
                          color: Colors.white.withAlpha(200), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Since $createdDate',
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // Non-members still get the Join button (and About toggle
                  // beside it) below the meta row.
                  if (!club.isMember) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _JoinButton(
                          isPublic: club.isPublic,
                          hasPendingRequest: club.hasPendingRequest,
                          onPressed: onJoinToggle,
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

  String _formatCreatedAt(String iso) {
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  void _showClubMenu(BuildContext context) {
    final isOwner = club.userRole == 'OWNER';
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
            // Notification settings are member-only — nothing to subscribe
            // to when you're a guest.
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
            // Owners can't report or leave their own club — reporting is
            // handled by platform admins, and leaving requires transferring
            // ownership first (done from settings).
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
                onTap: () => _confirmLeave(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave club?'),
        content: Text('You\'ll stop seeing posts and challenges from '
            '${club.name}. You can rejoin anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      Navigator.pop(context); // close the bottom sheet
      onJoinToggle();
    }
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
    // Private club with a pending request — show outlined "Requested" chip
    // that cancels the request on tap.
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      ),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Fades + collapses the About toggle button when the About section is
/// visible below the hero, so only one "About" label is on screen at a time.
/// When the user re-collapses the section, the button fades back in.
class _AboutToggleSwitcher extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;
  const _AboutToggleSwitcher({required this.expanded, required this.onPressed});

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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) =>
      old.tabBar != tabBar || old.backgroundColor != backgroundColor;
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
            // Tappable header — tapping "About" + chevron collapses the card
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
                    value: club.handle,
                  ),
                  if (club.sportTypes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaRow(
                      icon: Icons.sports_score,
                      label: 'Sports',
                      value: club.sportTypes.join(' · '),
                    ),
                  ],
                  if (club.location != null && club.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: club.location!,
                    ),
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
                    value: createdDate,
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.person_outline,
                    label: 'Owner',
                    value: club.createdByName,
                  ),
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
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ============ POSTS TAB ============

class _ClubPostsTab extends StatelessWidget {
  final Club club;
  const _ClubPostsTab({required this.club});

  @override
  Widget build(BuildContext context) {
    if (!club.canViewPosts) {
      return const _LockedSection(
        icon: Icons.lock_outline,
        label: 'Posts are private',
        detail: 'Join this club to see posts from its members.',
      );
    }
    final posts = MockClubData.postsForClub(club.id);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Composer (members only)
        if (club.isMember) ...[
          _PostComposer(clubName: club.name),
          const SizedBox(height: 16),
        ],
        // Posts
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
                // Open composer (not implemented in mock)
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Share to $clubName...',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
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
  final Post post;
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
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
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      _relativeTime(post.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
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
              Icon(
                post.userLiked == true
                    ? Icons.favorite
                    : Icons.favorite_outline,
                size: 20,
                color: post.userLiked == true
                    ? Colors.red
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('${post.likes}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 24),
              Icon(Icons.mode_comment_outlined,
                  size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${post.commentCount}',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Icon(Icons.share_outlined,
                  size: 20, color: scheme.onSurfaceVariant),
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

// ============ CHALLENGES TAB ============

class _ClubChallengesTab extends StatelessWidget {
  final Club club;
  const _ClubChallengesTab({required this.club});

  @override
  Widget build(BuildContext context) {
    if (!club.canViewChallenges) {
      return const _LockedSection(
        icon: Icons.emoji_events_outlined,
        label: 'Challenges are private',
        detail: 'Join this club to see and compete in its challenges.',
      );
    }
    final challenges = MockClubData.challengesForClub(club.id);
    final scheme = Theme.of(context).colorScheme;

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
      itemBuilder: (context, i) => _ChallengeCard(challenge: challenges[i]),
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
            Text(
              challenge.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          // Progress bar (only for subscribed)
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
                  onPressed: () {},
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
                  onPressed: () {},
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

class _ClubMembersTab extends StatelessWidget {
  final Club club;
  const _ClubMembersTab({required this.club});

  @override
  Widget build(BuildContext context) {
    if (!club.canViewMembers) {
      return const _LockedSection(
        icon: Icons.people_outline,
        label: 'Members are private',
        detail: 'Join this club to see who\'s in it.',
      );
    }
    final members = MockClubData.membersForClub(club.id);
    final scheme = Theme.of(context).colorScheme;

    // Sort: OWNER first, then ADMIN, then MEMBER
    members.sort((a, b) {
      const order = {'OWNER': 0, 'ADMIN': 1, 'MEMBER': 2};
      return (order[a.role] ?? 3).compareTo(order[b.role] ?? 3);
    });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = members[i];
        final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
        return Container(
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
                      color: scheme.primary, fontWeight: FontWeight.w600),
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
                    Text(
                      m.email,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _RoleBadge(role: m.role),
            ],
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, label) = switch (role) {
      'OWNER' => (Colors.amber.withAlpha(40), Colors.amber.shade800, 'OWNER'),
      'ADMIN' => (
          scheme.primary.withAlpha(30),
          scheme.primary,
          'ADMIN'
        ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, 'MEMBER'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// Placeholder shown in a tab when the current user isn't allowed to see
/// its contents (private club, non-member, owner hasn't opened up the
/// section via visibility settings).
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
