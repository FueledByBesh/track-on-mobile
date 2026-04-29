import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/user.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../sharedwidgets/profile_page.dart';

/// User-focused third tab. Hosts three things:
///   1. Search bar — finds users by name / handle / email.
///   2. Pending follow-request inbox — banner when the viewer has
///      incoming follow requests (private profile / approval-required).
///   3. "People you follow" list — simple always-visible listing.
///      Suggestions section will be added once the backend ships a
///      `/api/users/suggestions` endpoint.
class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isSearching = _searchController.text.isNotEmpty;

    return Column(
      children: [
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
              if (query.isNotEmpty) provider.searchUsers(query);
              setState(() {});
            },
          ),
        ),
        // Follow-request inbox — only shown outside search mode so it
        // doesn't compete with the search results for attention.
        if (provider.incomingFollowRequests.isNotEmpty && !isSearching)
          _FollowRequestsBanner(
              requests: provider.incomingFollowRequests, provider: provider),
        Expanded(
          child: isSearching
              ? _buildSearchResults(provider, scheme)
              : _buildEmptyState(scheme),
        ),
      ],
    );
  }

  Widget _buildSearchResults(GroupsProvider provider, ColorScheme scheme) {
    final results = provider.searchedUsers;
    if (results.isEmpty) {
      return Center(
          child: Text('No users found',
              style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) =>
          _UserSearchRow(user: results[index]),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Find people to follow',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Search by name or @handle to discover other runners.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner listing incoming follow requests. Each row has accept/decline
/// actions; taps flow through [GroupsProvider] which refreshes the
/// inbox on resolution.
class _FollowRequestsBanner extends StatelessWidget {
  final List<UserPreview> requests;
  final GroupsProvider provider;
  const _FollowRequestsBanner(
      {required this.requests, required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Follow Requests',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...requests.map((u) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: scheme.primary.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    // Tapping the avatar/name opens the requester's
                    // profile so you can see who's asking before
                    // deciding to accept.
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProfilePage(userId: u.id)),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  scheme.primary.withAlpha(40),
                              child: Text(
                                u.fullName.isNotEmpty
                                    ? u.fullName[0]
                                    : '?',
                                style: TextStyle(color: scheme.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(u.fullName,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface)),
                                  Text('@${u.handle}',
                                      style: TextStyle(
                                          fontSize: 12,
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
                      tooltip: 'Accept',
                      onPressed: () =>
                          provider.acceptFollowRequest(u.id),
                      icon: const Icon(Icons.check, color: Colors.green),
                    ),
                    IconButton(
                      tooltip: 'Decline',
                      onPressed: () =>
                          provider.rejectFollowRequest(u.id),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Search-result row. Tap → profile page. "Follow" button hits the
/// provider and locally swaps the CTA to reflect the new state.
class _UserSearchRow extends StatefulWidget {
  final UserSearchResult user;
  const _UserSearchRow({required this.user});

  @override
  State<_UserSearchRow> createState() => _UserSearchRowState();
}

class _UserSearchRowState extends State<_UserSearchRow> {
  bool _followed = false;
  bool _pending = false;
  bool _busy = false;

  Future<void> _toggle() async {
    final provider = context.read<GroupsProvider>();
    setState(() => _busy = true);
    try {
      if (_followed || _pending) {
        await provider.unfollowUser(widget.user.id);
        setState(() {
          _followed = false;
          _pending = false;
        });
      } else {
        await provider.followUser(widget.user.id);
        // Status on the follow response would tell us PENDING vs
        // ACCEPTED; we don't propagate it here yet — this row is a
        // simple toggle for now. Swap to the dedicated profile page's
        // button once that lands.
        setState(() => _followed = true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final user = widget.user;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(userId: user.id)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary.withAlpha(30),
              child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0] : '?',
                  style: TextStyle(color: scheme.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  Text(user.email,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (_followed)
              OutlinedButton(
                onPressed: _busy ? null : _toggle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Following'),
              )
            else if (_pending)
              OutlinedButton(
                onPressed: _busy ? null : _toggle,
                child: const Text('Requested'),
              )
            else
              ElevatedButton(
                onPressed: _busy ? null : _toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Follow',
                    style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
