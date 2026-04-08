import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/friendship.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/club_service.dart';
import '../services/friendship_service.dart';
import '../services/post_service.dart';

class GroupsProvider extends ChangeNotifier {
  final PostApiService _postService;
  final ClubApiService _clubService;
  final FriendshipApiService _friendshipService;

  List<Post> _feed = [];
  List<Club> _myClubs = [];
  List<Club> _searchedClubs = [];
  List<Friendship> _friends = [];
  List<Friendship> _incomingRequests = [];
  List<UserSearchResult> _searchedUsers = [];
  bool _isLoading = false;
  bool _hasLoadedFeed = false;

  GroupsProvider(this._postService, this._clubService, this._friendshipService);

  List<Post> get feed => _feed;
  List<Club> get myClubs => _myClubs;
  List<Club> get searchedClubs => _searchedClubs;
  List<Friendship> get friends => _friends;
  List<Friendship> get incomingRequests => _incomingRequests;
  List<UserSearchResult> get searchedUsers => _searchedUsers;
  bool get isLoading => _isLoading;

  Future<void> loadFeed() async {
    if (!_hasLoadedFeed) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _feed = await _postService.getFeed();
      _hasLoadedFeed = true;
    } catch (e) {
      debugPrint('Error loading feed: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMyClubs() async {
    try {
      _myClubs = await _clubService.getMyClubs();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading clubs: $e');
    }
  }

  Future<void> searchClubs(String query) async {
    try {
      _searchedClubs = await _clubService.search(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching clubs: $e');
    }
  }

  Future<void> joinClub(String clubId) async {
    try {
      await _clubService.join(clubId);
      await loadMyClubs();
    } catch (e) {
      debugPrint('Error joining club: $e');
    }
  }

  Future<void> leaveClub(String clubId) async {
    try {
      await _clubService.leave(clubId);
      await loadMyClubs();
    } catch (e) {
      debugPrint('Error leaving club: $e');
    }
  }

  Future<void> loadFriends() async {
    try {
      _friends = await _friendshipService.getFriends();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  Future<void> loadIncomingRequests() async {
    try {
      _incomingRequests = await _friendshipService.getIncomingRequests();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading requests: $e');
    }
  }

  Future<void> searchUsers(String query) async {
    try {
      _searchedUsers = await _friendshipService.searchUsers(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  Future<void> sendFriendRequest(String email) async {
    try {
      await _friendshipService.sendRequest(email);
      await loadFriends();
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _friendshipService.acceptRequest(friendshipId);
      await loadFriends();
      await loadIncomingRequests();
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
  }

  Future<void> rejectRequest(String friendshipId) async {
    try {
      await _friendshipService.rejectRequest(friendshipId);
      await loadIncomingRequests();
    } catch (e) {
      debugPrint('Error rejecting request: $e');
    }
  }

  Future<Post> createPost({required String content, String? imageUrl, String? clubId}) async {
    final post = await _postService.create(content: content, imageUrl: imageUrl, clubId: clubId);
    await loadFeed();
    return post;
  }

  Future<void> likePost(String postId, bool isLike) async {
    try {
      await _postService.toggleLike(postId, isLike);
      await loadFeed();
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }
}
