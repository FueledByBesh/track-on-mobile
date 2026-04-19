import 'package:trackon_mobile/data/models/club.dart';
import 'package:trackon_mobile/data/models/post.dart';

/// Static mock data for club UI iteration. Remove once the backend is wired.
class MockClubData {
  MockClubData._();

  /// Clubs the current user created.
  static final List<Club> ownedClubs = [
    Club(
      id: 'mock-o1',
      name: 'Morning Runners',
      handle: '@morning-runners',
      sportTypes: const ['Running', 'Road'],
      location: 'San Francisco, CA',
      description: 'Early birds who hit the pavement before sunrise. '
          'We post daily route challenges and weekly leaderboards.',
      createdByName: 'You',
      memberCount: 248,
      isMember: true,
      userRole: 'OWNER',
      createdAt: '2025-06-12T08:00:00Z',
      isPublic: true,
    ),
  ];

  /// Clubs where the user is an admin (but didn't create).
  static final List<Club> adminClubs = [
    Club(
      id: 'mock-a1',
      name: 'Weekend Warriors',
      handle: '@weekend-warriors',
      sportTypes: const ['Running', 'Half Marathon'],
      location: 'Austin, TX',
      description: 'Casual athletes training for their first half-marathon.',
      createdByName: 'Jordan Park',
      memberCount: 89,
      isMember: true,
      userRole: 'ADMIN',
      createdAt: '2026-01-05T18:30:00Z',
      isPublic: false,
      nonMembersCanViewPosts: true,
    ),
    Club(
      id: 'mock-a2',
      name: 'Trail Blazers',
      handle: '@trail-blazers',
      sportTypes: const ['Running', 'Trail', 'Hiking'],
      location: 'Denver, CO',
      description: 'Trail running, hiking, and off-road adventures.',
      createdByName: 'Emma Rodriguez',
      memberCount: 512,
      isMember: true,
      userRole: 'ADMIN',
      createdAt: '2025-09-20T10:00:00Z',
      isPublic: true,
    ),
  ];

  /// Clubs where the user is a regular member.
  static final List<Club> memberClubs = [
    Club(
      id: 'mock-m1',
      name: 'City Cyclists',
      handle: '@city-cyclists',
      sportTypes: const ['Cycling', 'Road'],
      location: 'Amsterdam, NL',
      description: 'Urban cycling enthusiasts sharing routes, gear tips, '
          'and weekend rides.',
      createdByName: 'Maria Dubois',
      memberCount: 1432,
      isMember: true,
      userRole: 'MEMBER',
      createdAt: '2024-03-21T12:00:00Z',
      isPublic: true,
    ),
    Club(
      id: 'mock-m2',
      name: 'Yoga for Athletes',
      handle: '@yoga-athletes',
      sportTypes: const ['Yoga', 'Mobility'],
      location: 'Online',
      description: 'Recovery flows, mobility work, and mindfulness '
          'for runners and cyclists.',
      createdByName: 'Aisha Patel',
      memberCount: 321,
      isMember: true,
      userRole: 'MEMBER',
      createdAt: '2025-11-02T07:00:00Z',
      isPublic: false,
    ),
    Club(
      id: 'mock-m3',
      name: 'Swim Squad',
      handle: '@swim-squad',
      sportTypes: const ['Swimming', 'Open Water'],
      location: 'Miami, FL',
      description: 'Pool and open-water swimmers at all levels.',
      createdByName: 'Tom Nakamura',
      memberCount: 156,
      isMember: true,
      userRole: 'MEMBER',
      createdAt: '2025-08-14T16:45:00Z',
      isPublic: true,
    ),
  ];

  /// Recommended clubs the user hasn't joined yet. Mix of public and private
  /// so the UI exercises both flows.
  static final List<Club> recommendedClubs = [
    Club(
      id: 'mock-r1',
      name: 'Ultra Runners',
      handle: '@ultra-runners',
      sportTypes: const ['Running', 'Ultra'],
      location: 'Global',
      description: '50K+ runners only. Long runs, race prep, recovery.',
      createdByName: 'Kai Osei',
      memberCount: 2871,
      isMember: false,
      userRole: null,
      createdAt: '2023-11-10T09:00:00Z',
      isPublic: false,
      nonMembersCanViewPosts: true,
      nonMembersCanViewChallenges: true,
    ),
    Club(
      id: 'mock-r2',
      name: 'Strength & Conditioning',
      handle: '@strength-conditioning',
      sportTypes: const ['Strength', 'Mobility'],
      location: 'Online',
      description: 'Lifting programs designed for endurance athletes.',
      createdByName: 'Lena Weiss',
      memberCount: 642,
      isMember: false,
      userRole: null,
      createdAt: '2024-07-03T11:00:00Z',
      isPublic: true,
    ),
    Club(
      id: 'mock-r3',
      name: 'Local 5K Community',
      handle: '@local-5k',
      sportTypes: const ['Running', '5K'],
      location: 'Brooklyn, NY',
      description: 'Weekly parkrun meetups within 10 km of you.',
      createdByName: 'Oscar Lindqvist',
      memberCount: 427,
      isMember: false,
      userRole: null,
      createdAt: '2025-02-18T06:30:00Z',
      isPublic: true,
    ),
    Club(
      id: 'mock-r4',
      name: 'Nutrition & Fuel',
      handle: '@nutrition-fuel',
      sportTypes: const ['Nutrition'],
      location: 'Online',
      description: 'Race-day nutrition, hydration strategies, '
          'and gear reviews. Fully private — request to join.',
      createdByName: 'Dr. Ravi Kumar',
      memberCount: 1893,
      isMember: false,
      userRole: null,
      createdAt: '2024-10-01T14:00:00Z',
      isPublic: false,
    ),
    Club(
      id: 'mock-r5',
      name: 'Elite Track Squad',
      handle: '@elite-track',
      sportTypes: const ['Running', 'Track', 'Racing'],
      location: 'Eugene, OR',
      description: 'Invite-only club. Request pending.',
      createdByName: 'Coach Marcus',
      memberCount: 34,
      isMember: false,
      userRole: null,
      hasPendingRequest: true,
      createdAt: '2025-04-02T09:00:00Z',
      isPublic: false,
    ),
  ];

  /// Aggregated list used by the club detail page and any consumer that
  /// needs "all mock clubs" in one place.
  static List<Club> get clubs => [
        ...ownedClubs,
        ...adminClubs,
        ...memberClubs,
        ...recommendedClubs,
      ];

  static List<Post> postsForClub(String clubId) {
    final clubName = clubs.firstWhere((c) => c.id == clubId).name;
    return [
      Post(
        id: '$clubId-p1',
        authorName: 'Sarah Kim',
        authorEmail: 'sarah@example.com',
        clubId: clubId,
        clubName: clubName,
        content: 'Just finished a 10K at 4:32 pace! '
            'New PR. Thanks everyone for the pre-run motivation in the chat.',
        likes: 42,
        dislikes: 0,
        commentCount: 8,
        userLiked: true,
        createdAt: '2026-04-17T06:45:00Z',
      ),
      Post(
        id: '$clubId-p2',
        authorName: 'Dmitri Volkov',
        authorEmail: 'dmitri@example.com',
        clubId: clubId,
        clubName: clubName,
        content: 'Reminder: tomorrow 6am meetup at Riverside Park. '
            'Bring water, the forecast says 24C.',
        likes: 18,
        dislikes: 0,
        commentCount: 3,
        userLiked: null,
        createdAt: '2026-04-16T21:10:00Z',
      ),
      Post(
        id: '$clubId-p3',
        authorName: 'Priya Mehta',
        authorEmail: 'priya@example.com',
        clubId: clubId,
        clubName: clubName,
        content: 'Anyone have recommendations for road shoes under \$120? '
            'Mine are done after 800km.',
        likes: 7,
        dislikes: 0,
        commentCount: 12,
        userLiked: null,
        createdAt: '2026-04-15T14:20:00Z',
      ),
    ];
  }

  static List<Challenge> challengesForClub(String clubId) {
    return [
      Challenge(
        id: '$clubId-c1',
        clubId: clubId,
        title: 'April 200K Challenge',
        description: 'Log 200 kilometers by the end of April. '
            'Top 3 get featured on the home feed.',
        targetType: 'DISTANCE',
        targetValue: 200,
        startDate: '2026-04-01',
        endDate: '2026-04-30',
        subscriberCount: 87,
        isSubscribed: true,
        userProgress: 124.3,
      ),
      Challenge(
        id: '$clubId-c2',
        clubId: clubId,
        title: 'Weekend Warrior Steps',
        description: '50,000 steps across Saturday and Sunday.',
        targetType: 'STEPS',
        targetValue: 50000,
        startDate: '2026-04-19',
        endDate: '2026-04-20',
        subscriberCount: 34,
        isSubscribed: false,
        userProgress: null,
      ),
      Challenge(
        id: '$clubId-c3',
        clubId: clubId,
        title: 'May Marathon Prep',
        description: 'Build to 50km/week by the end of May. '
            'Structured program with weekly check-ins.',
        targetType: 'DISTANCE',
        targetValue: 50,
        startDate: '2026-05-01',
        endDate: '2026-05-31',
        subscriberCount: 12,
        isSubscribed: false,
        userProgress: null,
      ),
    ];
  }

  static List<ClubMember> membersForClub(String clubId) {
    return [
      ClubMember(
        userId: '$clubId-u1',
        name: 'Alex Chen',
        email: 'alex@example.com',
        role: 'OWNER',
        joinedAt: '2025-06-12T08:00:00Z',
      ),
      ClubMember(
        userId: '$clubId-u2',
        name: 'Sarah Kim',
        email: 'sarah@example.com',
        role: 'ADMIN',
        joinedAt: '2025-06-15T10:22:00Z',
      ),
      ClubMember(
        userId: '$clubId-u3',
        name: 'Dmitri Volkov',
        email: 'dmitri@example.com',
        role: 'ADMIN',
        joinedAt: '2025-07-02T14:00:00Z',
      ),
      ClubMember(
        userId: '$clubId-u4',
        name: 'Priya Mehta',
        email: 'priya@example.com',
        role: 'MEMBER',
        joinedAt: '2025-08-18T09:15:00Z',
      ),
      ClubMember(
        userId: '$clubId-u5',
        name: 'Jordan Park',
        email: 'jordan@example.com',
        role: 'MEMBER',
        joinedAt: '2025-09-01T16:40:00Z',
      ),
      ClubMember(
        userId: '$clubId-u6',
        name: 'Mia Tanaka',
        email: 'mia@example.com',
        role: 'MEMBER',
        joinedAt: '2025-11-11T11:11:00Z',
      ),
    ];
  }
}
