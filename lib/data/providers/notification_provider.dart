import 'package:flutter/material.dart';

import '../local/notification_cache_database.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

/// Cache-backed notification state.
///
/// Reads come from a local SQLite cache; writes (mark-read, delete)
/// are local-first then synced to the server. The list is
/// incrementally refreshed by passing the cache's `lastFetchedAt`
/// timestamp to `GET /api/notifications?since=...` — only newer rows
/// come down the wire. A separate full-resync flow, triggered
/// manually from the settings sheet, ignores the cache and rewrites
/// everything from scratch.
///
/// Notifications are never auto-read on page open. The user must tap,
/// swipe, or mark-all-read to clear the unread state.
class NotificationProvider extends ChangeNotifier {
  final NotificationApiService _service;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  int _unreadCount = 0;

  NotificationProvider(this._service);

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  /// True while a full re-sync is running — the UI uses this to swap
  /// the re-sync button's icon for a spinner.
  bool get isSyncing => _isSyncing;

  int get unreadCount => _unreadCount;

  // ============ LOAD ============

  /// Reads everything from the local cache and publishes it. Fast —
  /// no network. Call from `initState` on the notifications page so
  /// the list paints immediately; the caller then fires [reloadDelta]
  /// to pull new items since the cache's last fetch.
  Future<void> loadFromCache() async {
    try {
      _notifications = await NotificationCacheDatabase.readAll();
      _recomputeUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error reading notification cache: $e');
    }
  }

  /// Incremental fetch. Cursor = `MAX(cache.createdAt)` — derived
  /// from the cache itself so there's no client clock in the loop
  /// (skew can't cause missed rows) and the empty-cache path
  /// naturally routes to the same full-resync logic.
  ///
  /// Cache empty → auto-resync (same code path the settings button
  /// uses, but the main list shows the loading indicator instead of
  /// the sheet's "Re-syncing…" label).
  Future<void> reloadDelta() async {
    _isLoading = true;
    notifyListeners();
    try {
      final cursor = await NotificationCacheDatabase.maxCreatedAt();
      if (cursor == null) {
        // No rows yet → no cursor to ask from. Resync.
        await _doFullResync();
      } else {
        final fetched = await _service.getSince(cursor);
        if (fetched.isNotEmpty) {
          await NotificationCacheDatabase.upsertAll(fetched);
        }
      }
      _notifications = await NotificationCacheDatabase.readAll();
      _recomputeUnreadCount();
    } catch (e) {
      debugPrint('Error in reloadDelta: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Full re-sync: wipe the cache, fetch everything, write it back.
  /// Fixes drift (deleted server-side rows, missed deltas from a
  /// very long offline stretch, manual cache corruption). Exposed
  /// through the settings sheet — users won't normally need it
  /// because [reloadDelta] already handles the empty-cache case.
  Future<void> fullResync() async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _doFullResync();
      _notifications = await NotificationCacheDatabase.readAll();
      _recomputeUnreadCount();
    } catch (e) {
      debugPrint('Error in fullResync: $e');
    }
    _isSyncing = false;
    notifyListeners();
  }

  /// Shared "rewrite the cache from the server" primitive. Callers
  /// own their own loading-flag semantics.
  Future<void> _doFullResync() async {
    final fresh = await _service.getAll();
    await NotificationCacheDatabase.clear();
    if (fresh.isNotEmpty) {
      await NotificationCacheDatabase.upsertAll(fresh);
    }
  }

  /// Cheap standalone refresh for the badge on the home-header bell.
  /// Doesn't touch the cache or the in-memory list.
  Future<void> refreshUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  // ============ LOCAL-FIRST MUTATIONS ============

  /// Toggle a single notification's read state. Updates the cache +
  /// in-memory list instantly; fires the server write in the
  /// background. On server failure the optimistic change sticks —
  /// the next full re-sync would pull the authoritative value back.
  Future<void> toggleRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final target = _notifications[idx];
    final updated = target.copyWith(markedAsRead: !target.markedAsRead);
    _applyLocalUpdate(updated);

    try {
      if (updated.markedAsRead) {
        await _service.markAsRead(id);
      } else {
        // Server has no "mark unread" endpoint today. The toggle is
        // purely local until a future endpoint lands; a re-sync will
        // snap it back to the server truth.
      }
    } catch (e) {
      debugPrint('Error toggling read on $id: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final target = _notifications[idx];
    if (target.markedAsRead) return;
    _applyLocalUpdate(target.copyWith(markedAsRead: true));
    try {
      await _service.markAsRead(id);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications
        .map((n) => n.markedAsRead ? n : n.copyWith(markedAsRead: true))
        .toList();
    _unreadCount = 0;
    // Persist the flipped rows so the cache and in-memory list stay
    // aligned across page navigations.
    await NotificationCacheDatabase.upsertAll(_notifications);
    notifyListeners();
    try {
      await _service.markAllAsRead();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    _notifications = _notifications.where((n) => n.id != id).toList();
    await NotificationCacheDatabase.removeById(id);
    _recomputeUnreadCount();
    notifyListeners();
    try {
      await _service.delete(id);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // ============ INTERNALS ============

  Future<void> _applyLocalUpdate(AppNotification updated) async {
    _notifications = [
      for (final n in _notifications)
        if (n.id == updated.id) updated else n,
    ];
    _recomputeUnreadCount();
    await NotificationCacheDatabase.upsertOne(updated);
    notifyListeners();
  }

  void _recomputeUnreadCount() {
    _unreadCount =
        _notifications.where((n) => !n.markedAsRead).length;
  }
}
