import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/auth_provider.dart';

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
          labelColor: const Color(0xFF6B5FFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6B5FFF),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Account'),
        _SettingsTile(
          icon: Icons.person_outline,
          title: 'Edit Profile',
          subtitle: 'Name, email, photo',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () {},
        ),
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

class _AppearanceTab extends StatefulWidget {
  const _AppearanceTab();

  @override
  State<_AppearanceTab> createState() => _AppearanceTabState();
}

class _AppearanceTabState extends State<_AppearanceTab> {
  String _theme = 'System';
  bool _animations = true;
  int _selectedAccent = 0;

  final List<Color> _accentColors = [
    const Color(0xFF6B5FFF),
    Colors.blue,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Theme'),
        _SettingsTileDropdown(
          icon: Icons.brightness_6,
          title: 'App Theme',
          value: _theme,
          options: const ['Light', 'Dark', 'System'],
          onChanged: (v) => setState(() => _theme = v),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Accent Color'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: List.generate(_accentColors.length, (index) {
            final isSelected = index == _selectedAccent;
            return GestureDetector(
              onTap: () => setState(() => _selectedAccent = index),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColors[index],
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _accentColors[index].withAlpha(150),
                            blurRadius: 8,
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
        const SizedBox(height: 24),
        _SectionHeader(title: 'Other'),
        _SettingsTileSwitch(
          icon: Icons.animation,
          title: 'Animations',
          subtitle: 'Enable UI animations',
          value: _animations,
          onChanged: (v) => setState(() => _animations = v),
        ),
      ],
    );
  }
}

class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab();

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  bool _locationAlways = false;
  bool _locationWhileUsing = true;
  bool _notifications = true;
  bool _healthKit = false;
  bool _camera = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Location'),
        _SettingsTileSwitch(
          icon: Icons.location_on_outlined,
          title: 'While Using App',
          subtitle: 'Required for run tracking',
          value: _locationWhileUsing,
          onChanged: (v) => setState(() => _locationWhileUsing = v),
        ),
        _SettingsTileSwitch(
          icon: Icons.location_searching,
          title: 'Always Allow',
          subtitle: 'Background run tracking',
          value: _locationAlways,
          onChanged: (v) => setState(() => _locationAlways = v),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Other Permissions'),
        _SettingsTileSwitch(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Push notifications',
          value: _notifications,
          onChanged: (v) => setState(() => _notifications = v),
        ),
        _SettingsTileSwitch(
          icon: Icons.favorite_outline,
          title: 'Health Data',
          subtitle: 'Access HealthKit / Google Fit',
          value: _healthKit,
          onChanged: (v) => setState(() => _healthKit = v),
        ),
        _SettingsTileSwitch(
          icon: Icons.camera_alt_outlined,
          title: 'Camera',
          subtitle: 'For profile photo',
          value: _camera,
          onChanged: (v) => setState(() => _camera = v),
        ),
      ],
    );
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
          color: Colors.grey.shade600,
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
    final color = isDestructive ? Colors.red : const Color(0xFF6B5FFF);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6B5FFF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF6B5FFF),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6B5FFF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
