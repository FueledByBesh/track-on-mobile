import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationApiService _service;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;

  NotificationProvider(this._service);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadUnreadCount();
    });
    loadUnreadCount();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

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

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _service.markAsRead(id);
      await loadAll();
      await loadUnreadCount();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      await loadAll();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _service.delete(id);
      await loadAll();
      await loadUnreadCount();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
