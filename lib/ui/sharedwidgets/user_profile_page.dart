import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final String initials;
  final String handle;
  final String bio;
  final Color color;
  final String location;
  final String totalDistance;
  final String joinedDate;
  final int postsCount;
  final String followers;
  final String following;
  final List<UserPost> posts;

  UserProfile({
    required this.name,
    required this.initials,
    required this.handle,
    required this.bio,
    required this.color,
    required this.location,
    required this.totalDistance,
    required this.joinedDate,
    required this.postsCount,
    required this.followers,
    required this.following,
    required this.posts,
  });
}

class UserPost {
  final String text;
  final String time;
  final int likes;
  final int comments;
  final bool hasImage;
  final Color? imageColor;
  final IconData? imageIcon;
  final String? imageCaption;

  UserPost({
    required this.text,
    required this.time,
    required this.likes,
    required this.comments,
    this.hasImage = false,
    this.imageColor,
    this.imageIcon,
    this.imageCaption,
  });
}

// Mock profiles keyed by name for easy lookup
final Map<String, UserProfile> mockProfiles = {
  'John Doe': UserProfile(
    name: 'John Doe',
    initials: 'JD',
    handle: '@johndoe',
    bio: 'Marathon runner and trail enthusiast. 5AM club member. '
        'Training for my first ultra.',
    color: Colors.blue,
    location: 'New York, NY',
    totalDistance: '2,340 km',
    joinedDate: 'Joined Mar 2023',
    postsCount: 87,
    followers: '1.2k',
    following: '256',
    posts: [
      UserPost(
        text: 'Early morning 15k through Central Park. The city is so peaceful at 5AM.',
        time: '3 hours ago',
        likes: 142,
        comments: 18,
        hasImage: true,
        imageColor: Colors.blue.shade100,
        imageIcon: Icons.park,
        imageCaption: 'Central Park Sunrise',
      ),
      UserPost(
        text: 'Hit a new 5k PR today: 19:45! Sub-20 finally done.',
        time: '2 days ago',
        likes: 287,
        comments: 43,
      ),
      UserPost(
        text: 'Rest day vibes. Recovery is part of the process.',
        time: '4 days ago',
        likes: 98,
        comments: 7,
      ),
    ],
  ),
  'Emma Smith': UserProfile(
    name: 'Emma Smith',
    initials: 'ES',
    handle: '@emmasmith',
    bio: 'Yoga instructor & distance runner. Balancing strength and flexibility. '
        'Plant-based athlete.',
    color: Colors.pink,
    location: 'Austin, TX',
    totalDistance: '1,890 km',
    joinedDate: 'Joined Jun 2023',
    postsCount: 64,
    followers: '890',
    following: '312',
    posts: [
      UserPost(
        text: 'Sunrise yoga followed by a 10k. Best way to start the weekend!',
        time: '1 hour ago',
        likes: 213,
        comments: 29,
        hasImage: true,
        imageColor: Colors.pink.shade100,
        imageIcon: Icons.self_improvement,
        imageCaption: 'Morning Yoga Flow',
      ),
      UserPost(
        text: 'New plant-based meal prep for the week. Fueling right makes all the difference.',
        time: '3 days ago',
        likes: 176,
        comments: 34,
        hasImage: true,
        imageColor: Colors.green.shade100,
        imageIcon: Icons.restaurant,
        imageCaption: 'Meal Prep Sunday',
      ),
      UserPost(
        text: 'Completed my first trail half marathon! The hills were no joke.',
        time: '1 week ago',
        likes: 342,
        comments: 56,
      ),
    ],
  ),
  'Mike Johnson': UserProfile(
    name: 'Mike Johnson',
    initials: 'MJ',
    handle: '@mikej',
    bio: 'CrossFit athlete turned runner. Love pushing limits. '
        'Coach at FitBox gym.',
    color: Colors.orange,
    location: 'Denver, CO',
    totalDistance: '3,120 km',
    joinedDate: 'Joined Jan 2023',
    postsCount: 112,
    followers: '1.8k',
    following: '189',
    posts: [
      UserPost(
        text: 'Mountain trail run at 8,000ft elevation. Lungs were on fire but the views were worth it.',
        time: '5 hours ago',
        likes: 398,
        comments: 61,
        hasImage: true,
        imageColor: Colors.orange.shade100,
        imageIcon: Icons.landscape,
        imageCaption: 'Rocky Mountain Trail',
      ),
      UserPost(
        text: 'New coaching program starts next week. 12-week marathon prep for beginners. DM if interested!',
        time: '1 day ago',
        likes: 156,
        comments: 42,
      ),
      UserPost(
        text: 'Leg day + 8k tempo run. The combo that keeps giving.',
        time: '3 days ago',
        likes: 224,
        comments: 19,
        hasImage: true,
        imageColor: Colors.red.shade100,
        imageIcon: Icons.fitness_center,
        imageCaption: 'Post-Workout',
      ),
    ],
  ),
  'Lisa Chen': UserProfile(
    name: 'Lisa Chen',
    initials: 'LC',
    handle: '@lisachen',
    bio: 'Triathlete in training. Swim, bike, run, repeat. '
        'Data nerd who tracks everything.',
    color: Colors.teal,
    location: 'San Francisco, CA',
    totalDistance: '4,560 km',
    joinedDate: 'Joined Nov 2022',
    postsCount: 203,
    followers: '3.4k',
    following: '421',
    posts: [
      UserPost(
        text: 'Brick workout done: 40k bike + 10k run. Triathlon training is no joke.',
        time: '2 hours ago',
        likes: 445,
        comments: 72,
        hasImage: true,
        imageColor: Colors.teal.shade100,
        imageIcon: Icons.directions_bike,
        imageCaption: 'Brick Workout Session',
      ),
      UserPost(
        text: 'Swimming form finally clicking after months of drills. Slow progress is still progress.',
        time: '2 days ago',
        likes: 267,
        comments: 38,
      ),
      UserPost(
        text: 'Race day tomorrow! Alcatraz triathlon here I come.',
        time: '5 days ago',
        likes: 512,
        comments: 89,
        hasImage: true,
        imageColor: Colors.blue.shade100,
        imageIcon: Icons.emoji_events,
        imageCaption: 'Race Bib Ready',
      ),
      UserPost(
        text: 'Recovery week stats: 3 easy runs, 2 swims, 1 yoga session. Feeling refreshed.',
        time: '1 week ago',
        likes: 178,
        comments: 21,
      ),
    ],
  ),
  'Alex Johnson': UserProfile(
    name: 'Alex Johnson',
    initials: 'AJ',
    handle: '@alexj',
    bio: 'Running fanatic. 10k specialist. Always chasing that runner\'s high.',
    color: const Color(0xFF6B5FFF),
    location: 'Chicago, IL',
    totalDistance: '1,450 km',
    joinedDate: 'Joined Sep 2023',
    postsCount: 45,
    followers: '670',
    following: '198',
    posts: [
      UserPost(
        text: 'Just completed a 10k run! Personal best time!',
        time: '2 hours ago',
        likes: 234,
        comments: 45,
        hasImage: true,
        imageColor: Colors.purple.shade100,
        imageIcon: Icons.directions_run,
        imageCaption: '10k Finish',
      ),
      UserPost(
        text: 'Interval training at the track. 8x400m with 90s rest. Feeling fast.',
        time: '3 days ago',
        likes: 145,
        comments: 22,
      ),
    ],
  ),
  'Sarah Williams': UserProfile(
    name: 'Sarah Williams',
    initials: 'SW',
    handle: '@sarahw',
    bio: 'Yoga lover & mindful runner. Finding zen one mile at a time.',
    color: Colors.green,
    location: 'Portland, OR',
    totalDistance: '980 km',
    joinedDate: 'Joined Dec 2023',
    postsCount: 38,
    followers: '520',
    following: '275',
    posts: [
      UserPost(
        text: 'Yoga session this morning was amazing. Feeling energized!',
        time: '6 hours ago',
        likes: 156,
        comments: 23,
        hasImage: true,
        imageColor: Colors.green.shade100,
        imageIcon: Icons.self_improvement,
        imageCaption: 'Morning Yoga',
      ),
      UserPost(
        text: 'Rainy run through Forest Park. There\'s something magical about running in the rain.',
        time: '2 days ago',
        likes: 198,
        comments: 31,
      ),
    ],
  ),
};

UserProfile getFallbackProfile(String name, String initials, Color color) {
  return mockProfiles[name] ?? UserProfile(
    name: name,
    initials: initials,
    handle: '@${name.toLowerCase().replaceAll(' ', '')}',
    bio: 'Fitness enthusiast on a journey.',
    color: color,
    location: 'Somewhere',
    totalDistance: '500 km',
    joinedDate: 'Joined 2024',
    postsCount: 10,
    followers: '120',
    following: '80',
    posts: [
      UserPost(
        text: 'Just getting started on my fitness journey!',
        time: '1 day ago',
        likes: 24,
        comments: 5,
      ),
    ],
  );
}

class UserProfilePage extends StatelessWidget {
  final UserProfile profile;

  const UserProfilePage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(profile.name),
      ),
      body: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: profile.posts.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ProfileHeader(profile: profile);
          }
          return _PostCard(
            profile: profile,
            post: profile.posts[index - 1],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [profile.color, profile.color.withAlpha(150)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: profile.color.withAlpha(80),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                profile.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.handle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              profile.bio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileStat(value: profile.postsCount.toString(), label: 'Posts'),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _ProfileStat(value: profile.followers, label: 'Followers'),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _ProfileStat(value: profile.following, label: 'Following'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _InfoChip(icon: Icons.location_on_outlined, label: profile.location),
              _InfoChip(icon: Icons.directions_run, label: profile.totalDistance),
              _InfoChip(icon: Icons.calendar_today, label: profile.joinedDate),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: profile.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Message'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Posts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final UserProfile profile;
  final UserPost post;

  const _PostCard({required this.profile, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [profile.color, profile.color.withAlpha(150)],
                  ),
                ),
                child: Center(
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      post.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
          if (post.hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 180,
                color: post.imageColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      post.imageIcon ?? Icons.image,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.imageCaption ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _PostAction(icon: Icons.favorite_outline, label: post.likes.toString()),
              const SizedBox(width: 20),
              _PostAction(icon: Icons.mode_comment_outlined, label: post.comments.toString()),
              const SizedBox(width: 20),
              _PostAction(icon: Icons.share_outlined, label: 'Share'),
              const Spacer(),
              Icon(Icons.bookmark_outline, size: 20, color: Colors.grey.shade500),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PostAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
