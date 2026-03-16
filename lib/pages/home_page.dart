import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 100.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1C2A3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _buildCard(context, title: 'Recent Items', icon: Icons.history),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Quick Stats',
                icon: Icons.bar_chart_outlined,
              ),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Notifications',
                icon: Icons.notifications_outlined,
              ),
              const SizedBox(height: 16),
              _buildCard(context, title: 'Activity Feed', icon: Icons.feed),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Achievements',
                icon: Icons.emoji_events,
              ),
              const SizedBox(height: 16),
              _buildCard(context, title: 'Goals', icon: Icons.flag_outlined),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Settings',
                icon: Icons.settings_outlined,
              ),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Help & Support',
                icon: Icons.help_outline,
              ),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Tutorials',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              _buildCard(context, title: 'Community', icon: Icons.group),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Leaderboard',
                icon: Icons.trending_up,
              ),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Calendar',
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 16),
              _buildCard(context, title: 'Reports', icon: Icons.assessment),
              const SizedBox(height: 16),
              Text(
                'More Options',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1C2A3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildCard(context, title: 'Analytics', icon: Icons.analytics),
              const SizedBox(height: 16),
              _buildCard(
                context,
                title: 'Backup & Restore',
                icon: Icons.backup,
              ),
              const SizedBox(height: 16),
              _buildCard(context, title: 'Export Data', icon: Icons.download),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F3),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: const Color(0xFF2D8E7F), size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C2A3A),
            ),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Color(0xFF8B95A5)),
        ],
      ),
    );
  }
}
