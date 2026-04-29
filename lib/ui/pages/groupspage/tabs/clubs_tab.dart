import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/club.dart';
import '../../../../data/models/ownership_transfer.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../sharedwidgets/profile_page.dart';
import '../../clubs/club_detail_page.dart';
import '../../clubs/create_club_page.dart';

/// "Your clubs" — search bar at the top, transfer-inbox banner above
/// the list, then the viewer's clubs grouped by role (Owned / Admin /
/// Joined) with a quiet "+ Create a new club" tile pinned to the top
/// of the list. Switching the search field into a non-empty query
/// flips the body to remote search results.
class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key});

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupsProvider>();
    final isSearching = _searchController.text.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    final my = provider.myClubs;

    return Column(
      children: [
        // Pending-ownership-transfer banners (inbox). Shown above the
        // search so users notice before drilling into any club.
        if (provider.incomingTransfers.isNotEmpty && !isSearching)
          _PendingTransfersBanner(
              transfers: provider.incomingTransfers, provider: provider),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or @handle',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (query) {
              if (query.isNotEmpty) provider.searchClubs(query);
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: isSearching
              ? _buildSearchResults(provider, scheme)
              : RefreshIndicator(
                  onRefresh: () => provider.loadMyClubs(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // Empty state: hero banner encouraging creation.
                      // With clubs: a compact tile at the top of the
                      // list so creation is always one tap away.
                      if (my.isEmpty)
                        const _CreateClubEmptyBanner()
                      else
                        const _CreateClubTile(),
                      if (my.owned.isNotEmpty) ...[
                        _ClubSectionHeader(
                          title: 'My Clubs',
                          subtitle: 'Clubs you created',
                          count: my.owned.length,
                        ),
                        ...my.owned.map((c) => _ClubRowCard(club: c)),
                        const SizedBox(height: 16),
                      ],
                      if (my.admin.isNotEmpty) ...[
                        _ClubSectionHeader(
                          title: 'Admin of',
                          subtitle: 'Clubs you help manage',
                          count: my.admin.length,
                        ),
                        ...my.admin.map((c) => _ClubRowCard(club: c)),
                        const SizedBox(height: 16),
                      ],
                      if (my.member.isNotEmpty) ...[
                        _ClubSectionHeader(
                          title: 'Joined',
                          subtitle: "Clubs you're a member of",
                          count: my.member.length,
                        ),
                        ...my.member.map((c) => _ClubRowCard(club: c)),
                        const SizedBox(height: 16),
                      ],
                      if (my.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: Text(
                              'Or search to find existing clubs to join',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(GroupsProvider provider, ColorScheme scheme) {
    final results = provider.searchedClubs;
    if (results.isEmpty) {
      return Center(
        child: Text('No clubs found',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, i) => _ClubRowCard(club: results[i]),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Banner surfacing pending ownership transfers addressed to the user.
/// Tapping a row opens the accept/decline dialog; both actions flow
/// through GroupsProvider so `myClubs` refreshes on accept.
class _PendingTransfersBanner extends StatelessWidget {
  final List<OwnershipTransfer> transfers;
  final GroupsProvider provider;
  const _PendingTransfersBanner(
      {required this.transfers, required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: transfers.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  // Tapping the message opens the transferring owner's
                  // profile — useful if the recipient wants to check
                  // who's asking before accepting.
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProfilePage(userId: t.fromUserId)),
                    ),
                    child: Text(
                      '${t.fromUserName} wants to transfer ownership of '
                      '${t.clubName} to you',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurface),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _confirm(context, t, accept: false),
                  child: const Text('Decline',
                      style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => _confirm(context, t, accept: true),
                  child: Text('Accept',
                      style: TextStyle(color: scheme.primary)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, OwnershipTransfer t,
      {required bool accept}) async {
    try {
      if (accept) {
        await provider.acceptTransfer(t.clubId);
      } else {
        await provider.declineTransfer(t.clubId);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? 'You now own ${t.clubName}'
              : 'Declined ownership of ${t.clubName}')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong')));
    }
  }
}

/// Full-width gradient hero for first-time users — shown in place of
/// any sections when [MyClubs.isEmpty]. Tapping anywhere on the card
/// navigates to [CreateClubPage].
class _CreateClubEmptyBanner extends StatelessWidget {
  const _CreateClubEmptyBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateClubPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                scheme.primary.withAlpha(180),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Start your own club',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Bring people together around your sport, your pace, '
                'your schedule.',
                style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 13,
                    height: 1.35),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Create a club',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "+ Create a new club" tile shown at the top of the list
/// when the user already has at least one club — a quiet, always-
/// available entry point.
class _CreateClubTile extends StatelessWidget {
  const _CreateClubTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateClubPage()),
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary.withAlpha(70)),
          ),
          child: Row(
            children: [
              Icon(Icons.add, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                'Create a new club',
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  const _ClubSectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubRowCard extends StatelessWidget {
  final Club club;
  const _ClubRowCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final provider = context.read<GroupsProvider>();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubDetailPage(clubId: club.id)),
      ),
      child: Container(
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(Icons.groups, color: scheme.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          club.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!club.isPublic) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.lock,
                            size: 12, color: scheme.onSurfaceVariant),
                      ],
                      if (club.userRole != null) ...[
                        const SizedBox(width: 6),
                        _InlineRoleBadge(role: club.userRole!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${club.handle}  ·  ${club.memberCount} members',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!club.isMember)
              _JoinOrRequestButton(club: club, provider: provider)
            else
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Compact join / request button. Dispatches to the right provider
/// method based on the club's privacy; disabled + relabeled while a
/// request is pending.
class _JoinOrRequestButton extends StatelessWidget {
  final Club club;
  final GroupsProvider provider;
  const _JoinOrRequestButton({required this.club, required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!club.isPublic && club.hasPendingRequest) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Requested'),
      );
    }

    final label = club.isPublic ? 'Join' : 'Request';
    return ElevatedButton(
      onPressed: () => _onPressed(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    try {
      if (club.isPublic) {
        await provider.joinClub(club.id);
      } else {
        await provider.requestJoinClub(club.id);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }
}

class _InlineRoleBadge extends StatelessWidget {
  final ClubRole role;
  const _InlineRoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, label) = switch (role) {
      ClubRole.owner => (
          Colors.amber.withAlpha(40),
          Colors.amber.shade800,
          'OWNER'
        ),
      ClubRole.admin => (
          scheme.primary.withAlpha(30),
          scheme.primary,
          'ADMIN'
        ),
      ClubRole.member => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          'MEMBER'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
