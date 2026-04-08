import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationApiService _service;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  NotificationProvider(this._service);

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _service.getAll();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    try {
      await _service.markAsRead(id);
      await loadAll();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      await loadAll();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _service.delete(id);
      await loadAll();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}
