import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackon_mobile/data/providers/notification_provider.dart';

/// Actions the user can bind to a swipe gesture. Persisted to
/// SharedPreferences under the keys below.
enum _SwipeAction { none, toggleRead, delete }

const String _prefSwipeRight = 'notifications.swipe_right';
const String _prefSwipeLeft = 'notifications.swipe_left';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Start with a mapping that feels natural (swipe right = positive
  // action / dismiss the unread state, swipe left = destructive).
  // Overridden by persisted prefs once they load.
  _SwipeAction _swipeRight = _SwipeAction.toggleRead;
  _SwipeAction _swipeLeft = _SwipeAction.delete;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSwipePrefs();
      _bootstrapList();
    });
  }

  Future<void> _loadSwipePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _swipeRight = _SwipeActionCodec.decode(
          prefs.getString(_prefSwipeRight)) ??
          _SwipeAction.toggleRead;
      _swipeLeft = _SwipeActionCodec.decode(
          prefs.getString(_prefSwipeLeft)) ??
          _SwipeAction.delete;
    });
  }

  Future<void> _setSwipeRight(_SwipeAction v) async {
    setState(() => _swipeRight = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSwipeRight, _SwipeActionCodec.encode(v));
  }

  Future<void> _setSwipeLeft(_SwipeAction v) async {
    setState(() => _swipeLeft = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSwipeLeft, _SwipeActionCodec.encode(v));
  }

  /// Render cached rows first (instant), then fire a delta fetch
  /// against the server's `since` endpoint. Neither path marks any
  /// notifications as read — that's now a deliberate user action.
  Future<void> _bootstrapList() async {
    final provider = context.read<NotificationProvider>();
    await provider.loadFromCache();
    if (!mounted) return;
    await provider.reloadDelta();
  }

  Future<void> _pullToRefresh() {
    // Pull-to-refresh is the delta path, not the full-resync path.
    return context.read<NotificationProvider>().reloadDelta();
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SettingsSheet(
        swipeRight: _swipeRight,
        swipeLeft: _swipeLeft,
        onSwipeRightChanged: _setSwipeRight,
        onSwipeLeftChanged: _setSwipeLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final scheme = Theme.of(context).colorScheme;
    final hasUnread = notifications.any((n) => !n.markedAsRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: provider.markAllAsRead,
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _pullToRefresh,
        child: provider.isLoading && notifications.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: _EmptyState(scheme: scheme),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _NotificationTile(
                        key: ValueKey(n.id),
                        title: n.title,
                        description: n.description,
                        markedAsRead: n.markedAsRead,
                        swipeRight: _swipeRight,
                        swipeLeft: _swipeLeft,
                        onSwipeRight: () =>
                            _performSwipe(_swipeRight, n.id),
                        onSwipeLeft: () =>
                            _performSwipe(_swipeLeft, n.id),
                        onTap: () {
                          // Tap = mark-as-read explicitly (no auto-
                          // mark on render).
                          if (!n.markedAsRead) {
                            context
                                .read<NotificationProvider>()
                                .markAsRead(n.id);
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _performSwipe(_SwipeAction action, String id) async {
    final provider = context.read<NotificationProvider>();
    switch (action) {
      case _SwipeAction.toggleRead:
        await provider.toggleRead(id);
        break;
      case _SwipeAction.delete:
        await provider.deleteNotification(id);
        break;
      case _SwipeAction.none:
        break;
    }
  }
}

// ============ TILE ============

/// One row in the list. Wrapped in a Dismissible so both swipe
/// directions fire configurable actions. When the bound action is
/// `none`, the underlying Dismissible's `confirmDismiss` vetoes the
/// dismiss so the row stays in place — swipe feels "sticky" rather
/// than going away with no effect.
class _NotificationTile extends StatelessWidget {
  final String title;
  final String? description;
  final bool markedAsRead;
  final _SwipeAction swipeRight;
  final _SwipeAction swipeLeft;
  final Future<void> Function() onSwipeRight;
  final Future<void> Function() onSwipeLeft;
  final VoidCallback onTap;

  const _NotificationTile({
    super.key,
    required this.title,
    required this.description,
    required this.markedAsRead,
    required this.swipeRight,
    required this.swipeLeft,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final border = scheme.outlineVariant;

    // DismissDirection.horizontal lets both sides fire, but we gate
    // each on whether the bound action is non-none.
    final allowRight = swipeRight != _SwipeAction.none;
    final allowLeft = swipeLeft != _SwipeAction.none;
    final direction = allowRight && allowLeft
        ? DismissDirection.horizontal
        : allowRight
            ? DismissDirection.startToEnd
            : allowLeft
                ? DismissDirection.endToStart
                : DismissDirection.none;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('dismiss-$title-$description'),
        direction: direction,
        background: _SwipeBackground(
          action: swipeRight,
          alignment: Alignment.centerLeft,
          scheme: scheme,
        ),
        secondaryBackground: _SwipeBackground(
          action: swipeLeft,
          alignment: Alignment.centerRight,
          scheme: scheme,
        ),
        // For non-destructive actions (toggle-read) vet the dismiss
        // and fire the callback inline. For destructive (delete) let
        // the default dismiss animation remove the row, then call
        // the handler from onDismissed.
        confirmDismiss: (dir) async {
          final action = dir == DismissDirection.startToEnd
              ? swipeRight
              : swipeLeft;
          if (action == _SwipeAction.toggleRead) {
            if (dir == DismissDirection.startToEnd) {
              await onSwipeRight();
            } else {
              await onSwipeLeft();
            }
            // Return false so the row doesn't visually disappear —
            // read/unread stays in-place.
            return false;
          }
          return true;
        },
        onDismissed: (dir) {
          final action = dir == DismissDirection.startToEnd
              ? swipeRight
              : swipeLeft;
          if (action == _SwipeAction.delete) {
            if (dir == DismissDirection.startToEnd) {
              onSwipeRight();
            } else {
              onSwipeLeft();
            }
          }
        },
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: markedAsRead
                  ? cardColor
                  : scheme.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications,
                      color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: markedAsRead
                              ? FontWeight.normal
                              : FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (description != null &&
                          description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!markedAsRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final _SwipeAction action;
  final Alignment alignment;
  final ColorScheme scheme;

  const _SwipeBackground({
    required this.action,
    required this.alignment,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    if (action == _SwipeAction.none) {
      return const SizedBox.shrink();
    }
    final color = switch (action) {
      _SwipeAction.delete => Colors.red,
      _SwipeAction.toggleRead => scheme.primary,
      _SwipeAction.none => Colors.transparent,
    };
    final icon = switch (action) {
      _SwipeAction.delete => Icons.delete_outline,
      _SwipeAction.toggleRead => Icons.mark_email_read_outlined,
      _SwipeAction.none => Icons.circle,
    };
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

// ============ EMPTY STATE ============

class _EmptyState extends StatelessWidget {
  final ColorScheme scheme;
  const _EmptyState({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No notifications',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ SETTINGS SHEET ============

/// Swipe-action prefs + re-sync button.
class _SettingsSheet extends StatelessWidget {
  final _SwipeAction swipeRight;
  final _SwipeAction swipeLeft;
  final Future<void> Function(_SwipeAction) onSwipeRightChanged;
  final Future<void> Function(_SwipeAction) onSwipeLeftChanged;

  const _SettingsSheet({
    required this.swipeRight,
    required this.swipeLeft,
    required this.onSwipeRightChanged,
    required this.onSwipeLeftChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _SectionLabel(label: 'Swipe actions'),
                const SizedBox(height: 8),
                _SwipeActionField(
                  label: 'Swipe right',
                  value: swipeRight,
                  onChanged: (v) => onSwipeRightChanged(v),
                ),
                const SizedBox(height: 12),
                _SwipeActionField(
                  label: 'Swipe left',
                  value: swipeLeft,
                  onChanged: (v) => onSwipeLeftChanged(v),
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: 'Sync'),
                const SizedBox(height: 8),
                Text(
                  'Pull down on the list to fetch new notifications. '
                  'Re-sync rewrites the local cache from scratch — '
                  'use it if the list feels out of date.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.isSyncing
                        ? null
                        : () async {
                            await provider.fullResync();
                          },
                    icon: provider.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.cloud_sync),
                    label: Text(provider.isSyncing
                        ? 'Re-syncing…'
                        : 'Re-sync now'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SwipeActionField extends StatelessWidget {
  final String label;
  final _SwipeAction value;
  final ValueChanged<_SwipeAction> onChanged;

  const _SwipeActionField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        DropdownButton<_SwipeAction>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: _SwipeAction.values
              .map((a) => DropdownMenuItem<_SwipeAction>(
                    value: a,
                    child: Text(_SwipeActionCodec.label(a)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _SwipeActionCodec {
  static String encode(_SwipeAction a) => switch (a) {
        _SwipeAction.none => 'none',
        _SwipeAction.toggleRead => 'toggle_read',
        _SwipeAction.delete => 'delete',
      };

  static _SwipeAction? decode(String? s) {
    switch (s) {
      case 'none':
        return _SwipeAction.none;
      case 'toggle_read':
        return _SwipeAction.toggleRead;
      case 'delete':
        return _SwipeAction.delete;
      default:
        return null;
    }
  }

  static String label(_SwipeAction a) => switch (a) {
        _SwipeAction.none => 'Nothing',
        _SwipeAction.toggleRead => 'Toggle read',
        _SwipeAction.delete => 'Delete',
      };
}
