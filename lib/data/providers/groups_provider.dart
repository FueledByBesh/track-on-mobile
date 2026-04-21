import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/friendship.dart';
import '../models/ownership_transfer.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/club_post_service.dart';
import '../services/club_service.dart';
import '../services/friendship_service.dart';
import '../services/post_service.dart';
import '../services/user_post_service.dart';

/// Top-level state for the Groups tab: feed, my-clubs grouping, search
/// results, friends, and the ownership-transfer inbox.
///
/// Per-club detail state (members, posts, challenges, settings) is NOT
/// held here — the detail page owns that locally and only calls back
/// into this provider to mutate ambient state (join → refresh
/// `_myClubs` grouping). Keeps this class from becoming a dumping
/// ground.
class GroupsProvider extends ChangeNotifier {
  final ClubApiService _clubs;
  final ClubPostApiService _clubPosts;
  final UserPostApiService _userPosts;
  final PostApiService _posts;
  final FriendshipApiService _friendships;

  GroupsProvider({
    required ClubApiService clubs,
    required ClubPostApiService clubPosts,
    required UserPostApiService userPosts,
    required PostApiService posts,
    required FriendshipApiService friendships,
  })  : _clubs = clubs,
        _clubPosts = clubPosts,
        _userPosts = userPosts,
        _posts = posts,
        _friendships = friendships;

  // ============ STATE ============

  List<Post> _feed = const [];
  MyClubs _myClubs = const MyClubs(owned: [], admin: [], member: []);
  List<Club> _searchedClubs = const [];
  List<Friendship> _friends = const [];
  List<Friendship> _incomingFriendRequests = const [];
  List<UserSearchResult> _searchedUsers = const [];
  List<OwnershipTransfer> _incomingTransfers = const [];
  bool _isLoading = false;
  bool _hasLoadedFeed = false;

  // ----- getters -----
  List<Post> get feed => _feed;
  MyClubs get myClubs => _myClubs;
  List<Club> get searchedClubs => _searchedClubs;
  List<Friendship> get friends => _friends;
  List<Friendship> get incomingRequests => _incomingFriendRequests;
  List<UserSearchResult> get searchedUsers => _searchedUsers;
  List<OwnershipTransfer> get incomingTransfers => _incomingTransfers;
  bool get isLoading => _isLoading;

  /// Flat view for callers that just want "all clubs I'm in" without
  /// caring about role. Useful in menus and for feed refreshes.
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
    String? imageUrl,
    PostAttachmentKind? attachmentKind,
    String? attachmentRefId,
  }) async {
    final post = await _clubPosts.create(
      clubId: clubId,
      content: content,
      imageUrl: imageUrl,
      attachmentKind: attachmentKind,
      attachmentRefId: attachmentRefId,
    );
    await loadFeed();
    return post;
  }

  Future<Post> createUserPost({
    required String content,
    String? imageUrl,
    PostAttachmentKind? attachmentKind,
    String? attachmentRefId,
  }) async {
    final post = await _userPosts.create(
      content: content,
      imageUrl: imageUrl,
      attachmentKind: attachmentKind,
      attachmentRefId: attachmentRefId,
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

  /// Public-club direct join. For private clubs the detail page calls
  /// [requestJoinClub] instead — the server 400s on this path otherwise.
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

  /// Private-club join request. After success we reload `/mine` because
  /// the `allowJoinWithoutRequest` shortcut can flip the grouping
  /// (user instantly becomes a MEMBER).
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

  /// Called from the accept-transfer banner. Reloads `/mine` since the
  /// user's role in the relevant club just flipped to OWNER.
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

  // ============ FRIENDS ============

  Future<void> loadFriends() async {
    try {
      _friends = await _friendships.getFriends();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  Future<void> loadIncomingRequests() async {
    try {
      _incomingFriendRequests = await _friendships.getIncomingRequests();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading requests: $e');
    }
  }

  Future<void> searchUsers(String query) async {
    try {
      _searchedUsers = await _friendships.searchUsers(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  Future<void> sendFriendRequest(String email) async {
    try {
      await _friendships.sendRequest(email);
      await loadFriends();
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _friendships.acceptRequest(friendshipId);
      await Future.wait([loadFriends(), loadIncomingRequests()]);
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
  }

  Future<void> rejectRequest(String friendshipId) async {
    try {
      await _friendships.rejectRequest(friendshipId);
      await loadIncomingRequests();
    } catch (e) {
      debugPrint('Error rejecting request: $e');
    }
  }
}
