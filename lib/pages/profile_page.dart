import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 100.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Profile Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5F3),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2D8E7F), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 50, color: Color(0xFF2D8E7F)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'User Name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1C2A3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'user@example.com',
                style: TextStyle(fontSize: 14, color: Color(0xFF8B95A5)),
              ),
              const SizedBox(height: 32),
              _buildProfileSection(
                context,
                title: 'Account',
                items: [
                  _buildProfileItem('Edit Profile', Icons.edit_outlined),
                  _buildProfileItem('Privacy Settings', Icons.shield_outlined),
                  _buildProfileItem(
                    'Notifications',
                    Icons.notifications_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildProfileSection(
                context,
                title: 'General',
                items: [
                  _buildProfileItem('Help & Support', Icons.help_outline),
                  _buildProfileItem('About', Icons.info_outlined),
                  _buildProfileItem(
                    'Terms & Conditions',
                    Icons.description_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE8ECEF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logged out successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C2A3A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B95A5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8ECEF)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(
              items.length,
              (index) => Column(
                children: [
                  items[index],
                  if (index < items.length - 1)
                    const Divider(height: 1, color: Color(0xFFE8ECEF)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2D8E7F), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C2A3A),
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF8B95A5)),
        ],
      ),
    );
  }
}
