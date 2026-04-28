import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/ownership_transfer.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/club_post_service.dart';
import '../services/club_service.dart';
import '../services/follow_service.dart';
import '../services/post_service.dart';
import '../services/user_post_service.dart';
import '../services/user_service.dart';

/// Top-level state for the Groups tab: feed, my-clubs grouping, search
/// results, follow state, and the ownership-transfer inbox.
///
/// Per-club and per-user detail state isn't held here — detail pages
/// own their own local state and call back into this provider only to
/// mutate ambient lists (follow → bump counts / refresh inbox).
class GroupsProvider extends ChangeNotifier {
  final ClubApiService _clubs;
  final ClubPostApiService _clubPosts;
  final UserPostApiService _userPosts;
  final PostApiService _posts;
  final UserApiService _users;
  final FollowApiService _follows;

  GroupsProvider({
    required ClubApiService clubs,
    required ClubPostApiService clubPosts,
    required UserPostApiService userPosts,
    required PostApiService posts,
    required UserApiService users,
    required FollowApiService follows,
  })  : _clubs = clubs,
        _clubPosts = clubPosts,
        _userPosts = userPosts,
        _posts = posts,
        _users = users,
        _follows = follows;

  // ============ STATE ============

  List<Post> _feed = const [];
  MyClubs _myClubs = const MyClubs(owned: [], admin: [], member: []);
  List<Club> _searchedClubs = const [];
  List<UserSearchResult> _searchedUsers = const [];
  List<UserPreview> _incomingFollowRequests = const [];
  List<OwnershipTransfer> _incomingTransfers = const [];
  bool _isLoading = false;
  bool _hasLoadedFeed = false;

  // ----- getters -----
  List<Post> get feed => _feed;
  MyClubs get myClubs => _myClubs;
  List<Club> get searchedClubs => _searchedClubs;
  List<UserSearchResult> get searchedUsers => _searchedUsers;
  List<UserPreview> get incomingFollowRequests => _incomingFollowRequests;
  List<OwnershipTransfer> get incomingTransfers => _incomingTransfers;
  bool get isLoading => _isLoading;

  /// Flat view for callers that just want "all clubs I'm in" regardless
  /// of role. Useful for feed refreshes and menu lists.
  List<Club> get allMyClubs =>
      [..._myClubs.owned, ..._myClubs.admin, ..._myClubs.member];

  // ============ FEED ============

  Future<void> loadFeed() async {
    if (!_hasLoadedFeed) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _feed = await _posts.getFeed();
      _hasLoadedFeed = true;
    } catch (e) {
      debugPrint('Error loading feed: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Post> createClubPost({
    required String clubId,
    required String content,
    List<PostAttachmentRequest> attachments = const [],
  }) async {
    final post = await _clubPosts.create(
      clubId: clubId,
      content: content,
      attachments: attachments,
    );
    await loadFeed();
    return post;
  }

  Future<Post> createUserPost({
    required String content,
    List<PostAttachmentRequest> attachments = const [],
  }) async {
    final post = await _userPosts.create(
      content: content,
      attachments: attachments,
    );
    await loadFeed();
    return post;
  }

  /// Toggle the viewer's reaction. Swaps the updated post into `_feed`
  /// in place so the card re-renders without a full feed refetch.
  Future<void> likePost(PostKind kind, String postId, bool isLike) async {
    try {
      final updated = await _posts.toggleLike(kind, postId, isLike);
      _feed = _feed.map((p) => p.id == updated.id ? updated : p).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }

  // ============ MY CLUBS ============

  Future<void> loadMyClubs() async {
    try {
      _myClubs = await _clubs.getMine();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading clubs: $e');
    }
  }

  Future<void> searchClubs(String query) async {
    try {
      _searchedClubs = await _clubs.search(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching clubs: $e');
    }
  }

  Future<Club> createClub({
    required String name,
    String? handle,
    String? description,
    String? location,
    List<String>? sportTypes,
    String? avatarImageUrl,
    bool? isPublic,
  }) async {
    final club = await _clubs.create(
      name: name,
      handle: handle,
      description: description,
      location: location,
      sportTypes: sportTypes,
      avatarImageUrl: avatarImageUrl,
      isPublic: isPublic,
    );
    await loadMyClubs();
    return club;
  }

  Future<Club> joinClub(String clubId) async {
    try {
      final updated = await _clubs.joinPublic(clubId);
      await loadMyClubs();
      return updated;
    } catch (e) {
      debugPrint('Error joining club: $e');
      rethrow;
    }
  }

  Future<void> requestJoinClub(String clubId) async {
    try {
      await _clubs.requestJoin(clubId);
      await loadMyClubs();
    } catch (e) {
      debugPrint('Error requesting join: $e');
      rethrow;
    }
  }

  Future<void> cancelMyJoinRequest(String clubId) async {
    try {
      await _clubs.cancelMyJoinRequest(clubId);
    } catch (e) {
      debugPrint('Error cancelling join request: $e');
      rethrow;
    }
  }

  Future<void> leaveClub(String clubId) async {
    try {
      await _clubs.leave(clubId);
      await loadMyClubs();
    } catch (e) {
      debugPrint('Error leaving club: $e');
      rethrow;
    }
  }

  // ============ OWNERSHIP TRANSFER INBOX ============

  Future<void> loadIncomingTransfers() async {
    try {
      _incomingTransfers = await _clubs.incomingTransfers();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading transfers: $e');
    }
  }

  Future<void> acceptTransfer(String clubId) async {
    try {
      await _clubs.acceptTransfer(clubId);
      await Future.wait([loadIncomingTransfers(), loadMyClubs()]);
    } catch (e) {
      debugPrint('Error accepting transfer: $e');
      rethrow;
    }
  }

  Future<void> declineTransfer(String clubId) async {
    try {
      await _clubs.declineTransfer(clubId);
      await loadIncomingTransfers();
    } catch (e) {
      debugPrint('Error declining transfer: $e');
      rethrow;
    }
  }

  // ============ PEOPLE — SEARCH + FOLLOW ============

  Future<void> searchUsers(String query) async {
    try {
      _searchedUsers = await _users.search(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  Future<void> loadIncomingFollowRequests() async {
    try {
      _incomingFollowRequests = await _follows.incomingRequests();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading follow requests: $e');
    }
  }

  /// Follow a user. Resolves to the new status (PENDING for
  /// approval-required profiles, ACCEPTED otherwise). Callers can use
  /// the returned value to update local UI state immediately.
  Future<void> followUser(String targetId) async {
    try {
      await _follows.follow(targetId);
    } catch (e) {
      debugPrint('Error following user: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String targetId) async {
    try {
      await _follows.unfollow(targetId);
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      rethrow;
    }
  }

  Future<void> acceptFollowRequest(String followerId) async {
    try {
      await _follows.acceptRequest(followerId);
      await loadIncomingFollowRequests();
    } catch (e) {
      debugPrint('Error accepting follow request: $e');
      rethrow;
    }
  }

  Future<void> rejectFollowRequest(String followerId) async {
    try {
      await _follows.rejectRequest(followerId);
      await loadIncomingFollowRequests();
    } catch (e) {
      debugPrint('Error rejecting follow request: $e');
      rethrow;
    }
  }
}
