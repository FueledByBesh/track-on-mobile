class AppNotification {
  final String id;
  final String title;
  final String? description;
  final bool markedAsRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.title,
    this.description,
    required this.markedAsRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      markedAsRead: json['markedAsRead'] ?? false,
      createdAt: json['createdAt'] ?? '',
    );
  }
}
