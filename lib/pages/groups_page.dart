import 'package:flutter/material.dart';

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
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6B5FFF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6B5FFF),
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

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Post> posts = [
      Post(
        authorName: 'Alex Johnson',
        authorImage: 'AJ',
        timestamp: '2 hours ago',
        content: 'Just completed a 10k run! Personal best time! 🏃',
        likes: 234,
        comments: 45,
        imageUrl: null,
      ),
      Post(
        authorName: 'Fitness Club',
        authorImage: 'FC',
        timestamp: '4 hours ago',
        content:
            'New strength training challenge: 30 days of pushups! Who\'s in? 💪',
        likes: 567,
        comments: 89,
        imageUrl: null,
      ),
      Post(
        authorName: 'Sarah Williams',
        authorImage: 'SW',
        timestamp: '6 hours ago',
        content: 'Yoga session this morning was amazing. Feeling energized!',
        likes: 156,
        comments: 23,
        imageUrl: null,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Info
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B5FFF).withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        post.authorImage,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          post.timestamp,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 12),
              // Content
              Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite_outline,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.likes.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.comments.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.share_outlined,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Share',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key});

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  final List<Club> followedClubs = [
    Club(
      name: 'Morning Runners',
      members: 1234,
      category: 'Running',
      isFollowed: true,
      color: Colors.orange,
    ),
    Club(
      name: 'Gym Warriors',
      members: 2567,
      category: 'Strength',
      isFollowed: true,
      color: Colors.blue,
    ),
  ];

  final List<Club> recommendedClubs = [
    Club(
      name: 'Yoga Enthusiasts',
      members: 890,
      category: 'Flexibility',
      isFollowed: false,
      color: Colors.green,
    ),
    Club(
      name: 'HIIT Masters',
      members: 1456,
      category: 'Cardio',
      isFollowed: false,
      color: Colors.red,
    ),
    Club(
      name: 'Cycling Club',
      members: 2100,
      category: 'Cardio',
      isFollowed: false,
      color: Colors.teal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // My Clubs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'My Clubs',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: followedClubs
                  .map((club) => _ClubTile(club: club))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          // Recommended
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Recommended For You',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: recommendedClubs
                  .map((club) => _ClubTile(club: club))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ClubTile extends StatelessWidget {
  final Club club;

  const _ClubTile({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: club.color.withAlpha(100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(Icons.group, color: club.color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${club.members} members • ${club.category}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: club.isFollowed
                  ? Colors.grey.shade200
                  : const Color(0xFF6B5FFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              club.isFollowed ? 'Following' : 'Follow',
              style: TextStyle(
                color: club.isFollowed ? Colors.black : Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final List<Friend> friends = [
    Friend(
      name: 'John Doe',
      status: 'Active now',
      initials: 'JD',
      favoriteColor: Colors.blue,
      weeklyRuns: 5,
      weeklyWorkouts: 4,
    ),
    Friend(
      name: 'Emma Smith',
      status: '30 min ago',
      initials: 'ES',
      favoriteColor: Colors.pink,
      weeklyRuns: 3,
      weeklyWorkouts: 5,
    ),
    Friend(
      name: 'Mike Johnson',
      status: '2 hours ago',
      initials: 'MJ',
      favoriteColor: Colors.orange,
      weeklyRuns: 6,
      weeklyWorkouts: 3,
    ),
    Friend(
      name: 'Lisa Chen',
      status: 'Active now',
      initials: 'LC',
      favoriteColor: Colors.teal,
      weeklyRuns: 4,
      weeklyWorkouts: 6,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => FriendDetailSheet(friend: friend),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: friend.favoriteColor.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          friend.initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: friend.status == 'Active now'
                              ? Colors.green
                              : Colors.grey,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        friend.status,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 20,
                      color: friend.favoriteColor,
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.call_outlined,
                      size: 20,
                      color: friend.favoriteColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FriendDetailSheet extends StatelessWidget {
  final Friend friend;

  const FriendDetailSheet({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: friend.favoriteColor.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    friend.initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: friend.favoriteColor.withAlpha(100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        friend.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: friend.favoriteColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'This Week Activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActivityCard(
                  title: 'Runs',
                  value: friend.weeklyRuns.toString(),
                  icon: Icons.directions_run,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActivityCard(
                  title: 'Workouts',
                  value: friend.weeklyWorkouts.toString(),
                  icon: Icons.fitness_center,
                  color: friend.favoriteColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Message'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friend.favoriteColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add to Challenge',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ActivityCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class Post {
  final String authorName;
  final String authorImage;
  final String timestamp;
  final String content;
  final int likes;
  final int comments;
  final String? imageUrl;

  Post({
    required this.authorName,
    required this.authorImage,
    required this.timestamp,
    required this.content,
    required this.likes,
    required this.comments,
    this.imageUrl,
  });
}

class Club {
  final String name;
  final int members;
  final String category;
  final bool isFollowed;
  final Color color;

  Club({
    required this.name,
    required this.members,
    required this.category,
    required this.isFollowed,
    required this.color,
  });
}

class Friend {
  final String name;
  final String status;
  final String initials;
  final Color favoriteColor;
  final int weeklyRuns;
  final int weeklyWorkouts;

  Friend({
    required this.name,
    required this.status,
    required this.initials,
    required this.favoriteColor,
    required this.weeklyRuns,
    required this.weeklyWorkouts,
  });
}
