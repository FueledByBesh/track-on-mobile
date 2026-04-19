import 'package:flutter/material.dart';
import 'package:trackon_mobile/data/models/club.dart';

/// Club notification settings. Everyone (owner/admin/member) gets the
/// top-level "allow notifications" + push + per-trigger toggles. Owners
/// and admins additionally get moderation-related triggers (join
/// requests, post approval requests).
///
/// Push permission is gated on the OS-level notification permission —
/// if the system hasn't granted it, the in-club push toggle is read-only
/// and we show a warning pointing to system settings.
class ClubNotificationSettingsPage extends StatefulWidget {
  final Club club;
  const ClubNotificationSettingsPage({super.key, required this.club});

  @override
  State<ClubNotificationSettingsPage> createState() =>
      _ClubNotificationSettingsPageState();
}

class _ClubNotificationSettingsPageState
    extends State<ClubNotificationSettingsPage> {
  // Master: notifications in general (in-app badge + push together).
  bool _allowNotifications = false;
  // Nested under master: actually deliver as system push.
  bool _allowPush = false;

  // Granular triggers
  String _postsFrom = 'ALL'; // ALL / STAFF_ONLY / NONE
  bool _challengeStarted = true;
  bool _challengeEndingSoon = true;
  bool _challengeResults = true;
  bool _mentionsInPosts = true;

  // Admin/owner-only triggers
  bool _joinRequests = true;
  bool _postApprovalRequests = true;

  // Mock OS-level push permission. Flip this in debug to preview the
  // "permission denied" UX. Real wiring will read from PermissionProvider.
  static const bool _osPushGranted = false;

  bool get _isStaff =>
      widget.club.userRole == 'OWNER' || widget.club.userRole == 'ADMIN';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master toggle
          _SwitchTile(
            title: 'Allow notifications',
            subtitle: 'Get in-app activity from ${widget.club.name}.',
            value: _allowNotifications,
            onChanged: (v) => setState(() {
              _allowNotifications = v;
              if (!v) _allowPush = false;
            }),
          ),

          // Everything below is only relevant once notifications are on.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _allowNotifications
                ? _buildEnabledSections(scheme)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnabledSections(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _SwitchTile(
          title: 'Send as push',
          subtitle:
              'Deliver as a system push notification, not just in-app.',
          value: _allowPush,
          enabled: _osPushGranted,
          onChanged: (v) => setState(() => _allowPush = v),
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
          value: _postsFrom,
          options: const [
            ('ALL', 'All members'),
            ('STAFF_ONLY', 'Admins & owner only'),
            ('NONE', 'None'),
          ],
          onChanged: (v) => setState(() => _postsFrom = v),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'Mentions',
          subtitle: 'Notify me when someone @mentions me in a post.',
          value: _mentionsInPosts,
          onChanged: (v) => setState(() => _mentionsInPosts = v),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'Challenges'),
        _SwitchTile(
          title: 'New challenges',
          subtitle: 'When a challenge is launched in this club.',
          value: _challengeStarted,
          onChanged: (v) => setState(() => _challengeStarted = v),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'Ending soon',
          subtitle: 'Reminder 24 hours before a challenge you\'ve joined ends.',
          value: _challengeEndingSoon,
          onChanged: (v) => setState(() => _challengeEndingSoon = v),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'Results & rankings',
          subtitle: 'When a challenge ends and results are posted.',
          value: _challengeResults,
          onChanged: (v) => setState(() => _challengeResults = v),
        ),
        if (_isStaff) ...[
          const SizedBox(height: 20),
          _SectionLabel(label: 'Moderation (admins)'),
          _SwitchTile(
            title: 'Join requests',
            subtitle: 'Notify me when someone asks to join this private club.',
            value: _joinRequests,
            onChanged: (v) => setState(() => _joinRequests = v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            title: 'Posts awaiting approval',
            subtitle: 'Notify me when a member submits a post that '
                'needs admin review.',
            value: _postApprovalRequests,
            onChanged: (v) => setState(() => _postApprovalRequests = v),
          ),
        ],
        const SizedBox(height: 24),
      ],
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

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const _ChoiceTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

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
            children: options.map((opt) {
              final selected = opt.$1 == value;
              return GestureDetector(
                onTap: () => onChanged(opt.$1),
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
