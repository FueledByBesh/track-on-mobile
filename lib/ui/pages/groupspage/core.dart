import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/groups_provider.dart';
import 'package:trackon_mobile/data/models/post.dart' as post_model;

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupsProvider>();
      provider.loadFeed();
      provider.loadMyClubs();
      provider.loadFriends();
      provider.loadIncomingRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Groups',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Feed'),
              Tab(text: 'Clubs'),
              Tab(text: 'Friends'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [FeedTab(), ClubsTab(), FriendsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ FEED TAB ============

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupsProvider>();
    final feed = provider.feed;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dynamic_feed, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No posts yet', style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Follow clubs and add friends to see posts', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadFeed(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: feed.length,
        itemBuilder: (context, index) => _PostCard(post: feed[index]),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final post_model.Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final initials = post.authorName.isNotEmpty
        ? post.authorName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                width: 40, height: 40,
                decoration: BoxDecoration(color: scheme.primary.withAlpha(100), shape: BoxShape.circle),
                child: Center(child: Text(initials, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: scheme.onSurface))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    if (post.clubName != null)
                      Text(post.clubName!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => context.read<GroupsProvider>().likePost(post.id, true),
                child: Row(children: [
                  Icon(
                    post.userLiked == true ? Icons.favorite : Icons.favorite_outline,
                    size: 20,
                    color: post.userLiked == true ? Colors.red : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text('${post.likes}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => context.read<GroupsProvider>().likePost(post.id, false),
                child: Row(children: [
                  Icon(
                    post.userLiked == false ? Icons.thumb_down : Icons.thumb_down_outlined,
                    size: 20,
                    color: post.userLiked == false ? Colors.blue : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text('${post.dislikes}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 24),
              Row(children: [
                Icon(Icons.mode_comment_outlined, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ CLUBS TAB ============

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
    final clubs = isSearching ? provider.searchedClubs : provider.myClubs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search clubs...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (query) {
              if (query.isNotEmpty) {
                provider.searchClubs(query);
              }
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: clubs.isEmpty
              ? Center(child: Text(isSearching ? 'No clubs found' : 'No clubs yet', style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    final club = clubs[index];
                    final scheme = Theme.of(context).colorScheme;
                    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant)),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: scheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Icon(Icons.groups, color: scheme.primary)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(club.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                Text('${club.memberCount} members', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (!club.isMember)
                            ElevatedButton(
                              onPressed: () => provider.joinClub(club.id),
                              style: ElevatedButton.styleFrom(backgroundColor: scheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: const Text('Join', style: TextStyle(color: Colors.white)),
                            )
                          else
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============ FRIENDS TAB ============

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupsProvider>();
    final isSearching = _searchController.text.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (query) {
              if (query.isNotEmpty) provider.searchUsers(query);
              setState(() {});
            },
          ),
        ),
        // Incoming requests
        if (provider.incomingRequests.isNotEmpty && !isSearching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Friend Requests', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...provider.incomingRequests.map((req) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: Text(req.friendName.isNotEmpty ? req.friendName : req.friendEmail)),
                      IconButton(onPressed: () => provider.acceptRequest(req.friendshipId), icon: const Icon(Icons.check, color: Colors.green)),
                      IconButton(onPressed: () => provider.rejectRequest(req.friendshipId), icon: const Icon(Icons.close, color: Colors.red)),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        Expanded(
          child: isSearching
              ? _buildSearchResults(provider)
              : _buildFriendsList(provider),
        ),
      ],
    );
  }

  Widget _buildSearchResults(GroupsProvider provider) {
    final results = provider.searchedUsers;
    if (results.isEmpty) return const Center(child: Text('No users found', style: TextStyle(color: Colors.grey)));
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final user = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: scheme.primary.withAlpha(30),
                child: Text(user.fullName.isNotEmpty ? user.fullName[0] : '?', style: TextStyle(color: scheme.primary))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                Text(user.email, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ])),
              ElevatedButton(
                onPressed: () {
                  provider.sendFriendRequest(user.email);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to ${user.fullName}')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: scheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(GroupsProvider provider) {
    final friends = provider.friends;
    if (friends.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No friends yet', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text('Search for users above', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: scheme.primary.withAlpha(30),
                child: Text(friend.friendName.isNotEmpty ? friend.friendName[0] : '?', style: TextStyle(color: scheme.primary))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(friend.friendName.isNotEmpty ? friend.friendName : friend.friendEmail, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                Text(friend.friendEmail, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ])),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
