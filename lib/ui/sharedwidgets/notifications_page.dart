import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      icon: Icons.emoji_events,
      color: Colors.orange,
      title: 'New Achievement!',
      body: 'You ran 50km this month. Keep it up!',
      time: '2 min ago',
      isSeen: false,
    ),
    NotificationItem(
      icon: Icons.group_add,
      color: const Color(0xFF6B5FFF),
      title: 'Club Invitation',
      body: 'Morning Runners invited you to join their club.',
      time: '15 min ago',
      isSeen: false,
    ),
    NotificationItem(
      icon: Icons.favorite,
      color: Colors.red,
      title: 'Alex liked your run',
      body: 'Alex Johnson liked your 10k run from yesterday.',
      time: '1 hour ago',
      isSeen: false,
    ),
    NotificationItem(
      icon: Icons.directions_run,
      color: Colors.green,
      title: 'Weekly Goal Reached',
      body: 'You completed 5 out of 5 planned workouts this week!',
      time: '3 hours ago',
      isSeen: true,
    ),
    NotificationItem(
      icon: Icons.comment,
      color: Colors.blue,
      title: 'New Comment',
      body: 'Sarah commented on your morning run: "Great pace!"',
      time: '5 hours ago',
      isSeen: true,
    ),
    NotificationItem(
      icon: Icons.update,
      color: Colors.teal,
      title: 'App Update Available',
      body: 'TrackOn v2.1 is available with new features.',
      time: 'Yesterday',
      isSeen: true,
    ),
    NotificationItem(
      icon: Icons.person_add,
      color: Colors.purple,
      title: 'New Follower',
      body: 'Emma Smith started following you.',
      time: 'Yesterday',
      isSeen: true,
    ),
  ];

  void _markAsSeen(int index) {
    setState(() {
      _notifications[index] = _notifications[index].copyWith(isSeen: true);
    });
  }

  void _markAllAsSeen() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isSeen: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unseenCount = _notifications.where((n) => !n.isSeen).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
        actions: [
          if (unseenCount > 0)
            TextButton(
              onPressed: _markAllAsSeen,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFF6B5FFF)),
              ),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationCard(
            notification: notification,
            onMarkSeen: () => _markAsSeen(index),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onMarkSeen;

  const _NotificationCard({
    required this.notification,
    required this.onMarkSeen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notification.isSeen ? Colors.white : const Color(0xFF6B5FFF).withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isSeen ? Colors.grey.shade200 : const Color(0xFF6B5FFF).withAlpha(60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notification.color.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(notification.icon, color: notification.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!notification.isSeen)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6B5FFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      notification.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    if (!notification.isSeen)
                      GestureDetector(
                        onTap: onMarkSeen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B5FFF).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Mark as read',
                            style: TextStyle(
                              color: Color(0xFF6B5FFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final bool isSeen;

  NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.isSeen,
  });

  NotificationItem copyWith({bool? isSeen}) {
    return NotificationItem(
      icon: icon,
      color: color,
      title: title,
      body: body,
      time: time,
      isSeen: isSeen ?? this.isSeen,
    );
  }
}
