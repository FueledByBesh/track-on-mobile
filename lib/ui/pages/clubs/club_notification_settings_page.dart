import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/club.dart';
import 'package:trackon_mobile/data/models/club_notification_prefs.dart';
import 'package:trackon_mobile/data/services/club_service.dart';

/// Club notification settings. Everyone (owner/admin/member) gets the
/// top-level "allow notifications" + push + per-trigger toggles. Owners
/// and admins additionally get moderation-related triggers (join
/// requests, post approval requests).
///
/// Prefs are lazy-created server-side on first GET, so the very first
/// render of this page for a given (user, club) pair triggers the
/// insert. Each toggle PUTs its own change — no Save button.
class ClubNotificationSettingsPage extends StatefulWidget {
  final Club club;
  const ClubNotificationSettingsPage({super.key, required this.club});

  @override
  State<ClubNotificationSettingsPage> createState() =>
      _ClubNotificationSettingsPageState();
}

class _ClubNotificationSettingsPageState
    extends State<ClubNotificationSettingsPage> {
  late Future<ClubNotificationPrefs> _future;
  ClubNotificationPrefs? _prefs;
  bool _saving = false;

  /// Mock OS-level push permission. Flip in debug to preview the
  /// "permission denied" UX. Real wiring will read from
  /// PermissionProvider once a PUSH permission enum value is added.
  static const bool _osPushGranted = false;

  bool get _isStaff =>
      widget.club.userRole == ClubRole.owner ||
      widget.club.userRole == ClubRole.admin;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ClubNotificationPrefs> _load() async {
    final prefs = await context
        .read<ClubApiService>()
        .getNotificationPrefs(widget.club.id);
    _prefs = prefs;
    return prefs;
  }

  /// Each toggle calls this immediately on change. Fire-and-forget feel
  /// — the UI updates optimistically via setState first, then the PUT
  /// confirms. Rolling back on failure would be churn; we show an
  /// error SnackBar and let the user retry.
  Future<void> _save(Map<String, dynamic> patch,
      ClubNotificationPrefs optimistic) async {
    setState(() {
      _prefs = optimistic;
      _saving = true;
    });
    try {
      final updated = await context
          .read<ClubApiService>()
          .updateNotificationPrefs(widget.club.id, patch);
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save change')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: FutureBuilder<ClubNotificationPrefs>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || _prefs == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load settings'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return _buildBody();
        },
      ),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;
    final p = _prefs!;

    return AbsorbPointer(
      absorbing: _saving,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master toggle
          _SwitchTile(
            title: 'Allow notifications',
            subtitle: 'Get in-app activity from ${widget.club.name}.',
            value: p.allowNotifications,
            onChanged: (v) {
              // Master off drags push off too so the dispatcher only
              // needs to check the master flag.
              final optimistic = _copyWith(p,
                  allowNotifications: v, allowPush: v ? p.allowPush : false);
              _save(
                ClubNotificationPrefs.patch(
                  allowNotifications: v,
                  allowPush: v ? null : false,
                ),
                optimistic,
              );
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: p.allowNotifications
                ? _buildEnabledSections(scheme, p)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnabledSections(ColorScheme scheme, ClubNotificationPrefs p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _SwitchTile(
          title: 'Send as push',
          subtitle:
              'Deliver as a system push notification, not just in-app.',
          value: p.allowPush,
          enabled: _osPushGranted,
          onChanged: (v) => _save(
            ClubNotificationPrefs.patch(allowPush: v),
            _copyWith(p, allowPush: v),
          ),
        ),
        if (!_osPushGranted) ...[
          const SizedBox(height: 6),
          const _Warning(
            message: 'Please allow push notifications in settings.',
          ),
        ],
        const SizedBox(height: 20),
        _SectionLabel(label: 'Posts'),
        _ChoiceTile(
          title: 'Notify me about posts',
          value: p.postsFrom,
          onChanged: (v) => _save(
            ClubNotificationPrefs.patch(postsFrom: v),
            _copyWith(p, postsFrom: v),
          ),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'Mentions',
          subtitle: 'Notify me when someone @mentions me in a post.',
          value: p.mentions,
          onChanged: (v) => _save(
            ClubNotificationPrefs.patch(mentions: v),
            _copyWith(p, mentions: v),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'Challenges'),
        _SwitchTile(
          title: 'New challenges',
          subtitle: 'When a challenge is launched in this club.',
          value: p.challengeStarted,
          onChanged: (v) => _save(
            ClubNotificationPrefs.patch(challengeStarted: v),
            _copyWith(p, challengeStarted: v),
          ),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'Ending soon',
          subtitle:
              "Reminder 24 hours before a challenge you've joined ends.",
          value: p.challengeEndingSoon,
          onChanged: (v) => _save(
            ClubNotificationPrefs.patch(challengeEndingSoon: v),
            _copyWith(p, challengeEndingSoon: v),
          ),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'Results & rankings',
          subtitle: 'When a challenge ends and results are posted.',
          value: p.challengeResults,
          onChanged: (v) => _save(
            ClubNotificationPrefs.patch(challengeResults: v),
            _copyWith(p, challengeResults: v),
          ),
        ),
        if (_isStaff) ...[
          const SizedBox(height: 20),
          _SectionLabel(label: 'Moderation (admins)'),
          _SwitchTile(
            title: 'Join requests',
            subtitle:
                'Notify me when someone asks to join this private club.',
            value: p.joinRequests,
            onChanged: (v) => _save(
              ClubNotificationPrefs.patch(joinRequests: v),
              _copyWith(p, joinRequests: v),
            ),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            title: 'Posts awaiting approval',
            subtitle: 'Notify me when a member submits a post that '
                'needs admin review.',
            value: p.postApprovalRequests,
            onChanged: (v) => _save(
              ClubNotificationPrefs.patch(postApprovalRequests: v),
              _copyWith(p, postApprovalRequests: v),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Ad-hoc copyWith — the model doesn't need one outside this page.
  ClubNotificationPrefs _copyWith(
    ClubNotificationPrefs p, {
    bool? allowNotifications,
    bool? allowPush,
    PostsFromPref? postsFrom,
    bool? mentions,
    bool? challengeStarted,
    bool? challengeEndingSoon,
    bool? challengeResults,
    bool? joinRequests,
    bool? postApprovalRequests,
  }) {
    return ClubNotificationPrefs(
      allowNotifications: allowNotifications ?? p.allowNotifications,
      allowPush: allowPush ?? p.allowPush,
      postsFrom: postsFrom ?? p.postsFrom,
      mentions: mentions ?? p.mentions,
      challengeStarted: challengeStarted ?? p.challengeStarted,
      challengeEndingSoon: challengeEndingSoon ?? p.challengeEndingSoon,
      challengeResults: challengeResults ?? p.challengeResults,
      joinRequests: joinRequests ?? p.joinRequests,
      postApprovalRequests: postApprovalRequests ?? p.postApprovalRequests,
    );
  }
}

// ============ WIDGETS ============

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented picker for the single {@code postsFrom} enum. Options are
/// baked in so callers don't have to restate them every time.
class _ChoiceTile extends StatelessWidget {
  final String title;
  final PostsFromPref value;
  final ValueChanged<PostsFromPref> onChanged;
  const _ChoiceTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  static const _options = [
    (PostsFromPref.all, 'All members'),
    (PostsFromPref.staffOnly, 'Admins & owner only'),
    (PostsFromPref.none, 'None'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: scheme.onSurface)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _options.map((opt) {
              final selected = opt.$1 == value;
              return GestureDetector(
                onTap: selected ? null : () => onChanged(opt.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withAlpha(30)
                        : scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String message;
  const _Warning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
