import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/models/user_settings.dart';
import 'package:trackon_mobile/data/providers/auth_provider.dart';
import 'package:trackon_mobile/data/providers/permission_provider.dart';
import 'package:trackon_mobile/data/providers/theme_provider.dart';
import 'package:trackon_mobile/data/services/permission_service.dart';
import 'package:trackon_mobile/data/services/user_service.dart';
import 'package:trackon_mobile/ui/sharedwidgets/edit_profile_page.dart';
import 'package:trackon_mobile/ui/sharedwidgets/profile_page.dart';
import 'package:trackon_mobile/ui/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Theme.of(context).colorScheme.primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Appearance'),
            Tab(text: 'Permissions'),
            Tab(text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GeneralTab(),
          _AppearanceTab(),
          _PermissionsTab(),
          _AboutTab(),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatefulWidget {
  const _GeneralTab();

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  String _units = 'Metric (km)';
  bool _autoSync = true;
  bool _weeklyReport = true;

  // ----- server-backed settings -----
  // Loaded once on init and patched per-toggle. Kept separately from
  // the ephemeral units/auto-sync flags above which aren't wired to
  // any backend yet.
  UserSettings? _serverSettings;
  bool _savingSetting = false;

  @override
  void initState() {
    super.initState();
    _loadServerSettings();
  }

  Future<void> _loadServerSettings() async {
    try {
      final s = await context.read<UserApiService>().getMySettings();
      if (!mounted) return;
      setState(() => _serverSettings = s);
    } catch (_) {
      // Non-fatal — privacy section just won't render until a retry.
    }
  }

  /// Patch one setting at a time. Optimistic update to avoid toggle
  /// lag; on failure we revert and toast.
  Future<void> _patchSettings(Map<String, dynamic> patch,
      UserSettings optimistic) async {
    final previous = _serverSettings;
    setState(() {
      _serverSettings = optimistic;
      _savingSetting = true;
    });
    try {
      final updated =
          await context.read<UserApiService>().updateMySettings(patch);
      if (!mounted) return;
      setState(() => _serverSettings = updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _serverSettings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save change')),
      );
    } finally {
      if (mounted) setState(() => _savingSetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Account'),
        _SettingsTile(
          icon: Icons.account_circle_outlined,
          title: 'View Profile',
          subtitle: 'Your public profile page',
          onTap: () => Navigator.push(
            context,
            // Null userId → ProfilePage fetches /api/users/me.
            MaterialPageRoute(
                builder: (_) => const ProfilePage(userId: null)),
          ),
        ),
        _SettingsTile(
          icon: Icons.person_outline,
          title: 'Edit Profile',
          subtitle: 'Name, handle, bio, avatar',
          onTap: () async {
            // Capture service + navigator/scaffold messenger before
            // the await so the linter is happy about cross-async
            // context use.
            final users = context.read<UserApiService>();
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              final me = await users.getMe();
              if (!mounted) return;
              navigator.push(
                MaterialPageRoute(
                    builder: (_) => EditProfilePage(profile: me)),
              );
            } catch (_) {
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                    content: Text('Could not load profile')),
              );
            }
          },
        ),
        _SettingsTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () {},
        ),
        if (_serverSettings != null) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Privacy'),
          // AbsorbPointer keeps the section inert while a PATCH is in
          // flight so users can't stack rapid toggles faster than the
          // server can acknowledge them.
          AbsorbPointer(
            absorbing: _savingSetting,
            child: Column(
              children: [
                _SettingsTileSwitch(
                  icon: Icons.visibility_outlined,
                  title: 'Public profile',
                  subtitle: _serverSettings!.isProfilePublic
                      ? 'Anyone can see your posts and activity.'
                      : 'Only your followers can see posts and activity.',
                  value: _serverSettings!.isProfilePublic,
                  onChanged: (v) {
                    // Backend couples private→approval-on on first
                    // flip; mirror locally so the UI stays in sync
                    // without a second round-trip.
                    final optimistic = _serverSettings!.copyWith(
                      isProfilePublic: v,
                      requireFollowApproval: v
                          ? _serverSettings!.requireFollowApproval
                          : true,
                    );
                    _patchSettings(
                      UserSettings.patch(isProfilePublic: v),
                      optimistic,
                    );
                  },
                ),
                _SettingsTileSwitch(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Require follow approval',
                  subtitle:
                      'New follow requests wait until you accept or decline.',
                  value: _serverSettings!.requireFollowApproval,
                  onChanged: (v) {
                    _patchSettings(
                      UserSettings.patch(requireFollowApproval: v),
                      _serverSettings!.copyWith(requireFollowApproval: v),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Notifications'),
          AbsorbPointer(
            absorbing: _savingSetting,
            child: Column(
              children: [
                _SettingsTileSwitch(
                  icon: Icons.notifications_active_outlined,
                  title: 'Follow notifications',
                  subtitle:
                      'Get notified when someone follows you or accepts your request.',
                  value: _serverSettings!.followNotificationsEnabled,
                  onChanged: (v) {
                    _patchSettings(
                      UserSettings.patch(followNotificationsEnabled: v),
                      _serverSettings!.copyWith(
                        followNotificationsEnabled: v,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _SectionHeader(title: 'Preferences'),
        _SettingsTileDropdown(
          icon: Icons.straighten,
          title: 'Units',
          value: _units,
          options: const ['Metric (km)', 'Imperial (mi)'],
          onChanged: (v) => setState(() => _units = v),
        ),
        _SettingsTileSwitch(
          icon: Icons.sync,
          title: 'Auto Sync',
          subtitle: 'Sync workouts automatically',
          value: _autoSync,
          onChanged: (v) => setState(() => _autoSync = v),
        ),
        _SettingsTileSwitch(
          icon: Icons.insert_chart_outlined,
          title: 'Weekly Report',
          subtitle: 'Receive weekly summary',
          value: _weeklyReport,
          onChanged: (v) => setState(() => _weeklyReport = v),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Data'),
        _SettingsTile(
          icon: Icons.download_outlined,
          title: 'Export Data',
          subtitle: 'Download your activity data',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.delete_outline,
          title: 'Delete Account',
          subtitle: 'Permanently remove your account',
          onTap: () {},
          isDestructive: true,
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Session'),
        _SettingsTile(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: () {
            context.read<AuthProvider>().signOut();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          isDestructive: true,
        ),
      ],
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentAccent = themeProvider.accent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Theme'),
        const SizedBox(height: 8),
        // Segmented mode picker
        Row(
          children: [
            _ThemeModeButton(
              icon: Icons.light_mode,
              label: 'Light',
              isSelected: themeProvider.mode == ThemeMode.light,
              onTap: () => themeProvider.setMode(ThemeMode.light),
            ),
            const SizedBox(width: 8),
            _ThemeModeButton(
              icon: Icons.dark_mode,
              label: 'Dark',
              isSelected: themeProvider.mode == ThemeMode.dark,
              onTap: () => themeProvider.setMode(ThemeMode.dark),
            ),
            const SizedBox(width: 8),
            _ThemeModeButton(
              icon: Icons.phone_android,
              label: 'System',
              isSelected: themeProvider.mode == ThemeMode.system,
              onTap: () => themeProvider.setMode(ThemeMode.system),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Accent Color'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(AppTheme.accentOptions.length, (index) {
            final color = AppTheme.accentOptions[index];
            final isSelected = currentAccent == color;
            return GestureDetector(
              onTap: () => themeProvider.setAccent(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withAlpha(150),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          AppTheme.accentLabels[AppTheme.accentOptions.indexOf(currentAccent)
              .clamp(0, AppTheme.accentLabels.length - 1)],
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Preview'),
        const SizedBox(height: 12),
        _AccentPreviewCard(accent: currentAccent),
      ],
    );
  }
}

/// Live preview card that recolors instantly when the user picks a new
/// accent. Mimics the look of the statistics hero gradient so the user
/// sees exactly how the home page will feel.
class _AccentPreviewCard extends StatelessWidget {
  final Color accent;
  const _AccentPreviewCard({required this.accent});

  @override
  Widget build(BuildContext context) {
    // Derive a lighter shade for the gradient end
    final hsl = HSLColor.fromColor(accent);
    final lighter = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, lighter],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_walk,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '6,421',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'steps today',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Mini bar chart preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in [0.3, 0.5, 0.7, 0.4, 0.9, 0.6, 0.8])
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                        width: 6,
                        height: 36 * h,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(180),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PreviewPill(label: '4.9 km'),
              const SizedBox(width: 8),
              _PreviewPill(label: '256 cal'),
              const SizedBox(width: 8),
              _PreviewPill(label: '32 min'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String label;
  const _PreviewPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withAlpha(220),
        ),
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withAlpha(30)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PermissionProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Location'),
        _PermissionTile(
          icon: Icons.location_on_outlined,
          title: 'Location',
          subtitle: 'Required for run tracking',
          permission: AppPermission.location,
          provider: provider,
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Fitness Data'),
        _PermissionTile(
          icon: Icons.favorite_outline,
          title: 'Fitness',
          subtitle: 'Access step count from Health Connect',
          permission: AppPermission.fitness,
          provider: provider,
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Notifications'),
        _PermissionTile(
          icon: Icons.notifications_outlined,
          title: 'Push notifications',
          subtitle:
              'Allow TrackOn to show alerts for follows, clubs, and activity.',
          permission: AppPermission.notifications,
          provider: provider,
        ),
      ],
    );
  }
}

/// Single permission row. Shows current status as a colored pill and
/// an action button whose label depends on the status:
///   - granted           → "Allowed" (no button, just the pill)
///   - denied            → "Allow" (opens OS prompt via request())
///   - permanentlyDenied → "Open Settings" (escalates to app settings)
///   - unavailable       → "Not supported" (no button)
///   - restricted        → "Restricted" (no button)
///   - unknown           → "Check" (runs refresh())
class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppPermission permission;
  final PermissionProvider provider;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.permission,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final status = provider.statusOf(permission);
    final (statusLabel, statusColor) = _statusStyle(status);
    final busy = provider.isBusy;

    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_actionLabel(status) != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : () => _handleAction(context, status),
                child: Text(_actionLabel(status)!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    AppPermissionStatus status,
  ) async {
    switch (status) {
      case AppPermissionStatus.denied:
      case AppPermissionStatus.unknown:
        await provider.request(permission);
        break;
      case AppPermissionStatus.permanentlyDenied:
        await provider.openAppSettings();
        break;
      case AppPermissionStatus.granted:
      case AppPermissionStatus.restricted:
      case AppPermissionStatus.unavailable:
        break;
    }
  }

  String? _actionLabel(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.denied:
        return 'Allow';
      case AppPermissionStatus.permanentlyDenied:
        return 'Open Settings';
      case AppPermissionStatus.unknown:
        return 'Check';
      case AppPermissionStatus.granted:
      case AppPermissionStatus.restricted:
      case AppPermissionStatus.unavailable:
        return null;
    }
  }

  (String, Color) _statusStyle(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return ('Allowed', Colors.green);
      case AppPermissionStatus.denied:
        return ('Denied', Colors.orange);
      case AppPermissionStatus.permanentlyDenied:
        return ('Blocked', Colors.red);
      case AppPermissionStatus.restricted:
        return ('Restricted', Colors.grey);
      case AppPermissionStatus.unavailable:
        return ('Not supported', Colors.grey);
      case AppPermissionStatus.unknown:
        return ('Unknown', Colors.grey);
    }
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'App Info'),
        _SettingsTile(
          icon: Icons.info_outline,
          title: 'Version',
          subtitle: '1.0.0 (Build 1)',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'Read our terms',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.code,
          title: 'Open Source Licenses',
          subtitle: 'Third-party libraries',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Support'),
        _SettingsTile(
          icon: Icons.help_outline,
          title: 'Help Center',
          subtitle: 'FAQs and guides',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.bug_report_outlined,
          title: 'Report a Bug',
          subtitle: 'Let us know about issues',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.star_outline,
          title: 'Rate the App',
          subtitle: 'Leave a review',
          onTap: () {},
        ),
      ],
    );
  }
}

// Shared setting widgets

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    final accentColor = isDestructive ? scheme.error : scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
      ),
      child: ListTile(
        leading: Icon(icon, color: accentColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? scheme.error : scheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant.withAlpha(120)),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsTileSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTileSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
      ),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: scheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTileDropdown extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SettingsTileDropdown({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
      ),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
        ),
        trailing: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          dropdownColor: cardColor,
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o, style: TextStyle(fontSize: 14, color: scheme.onSurface)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
