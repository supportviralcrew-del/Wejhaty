import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType {
  subscriptionSuccess,
  subscriptionFailed,
  subscriptionExpired,
  subscriptionCancelled,
  creditsRefilled,
  creditsLow,
  tripStarted,
  tripCompleted,
  tripProgress,
  error,
  info,
}

class NotificationEvent {
  final String id;
  final NotificationType type;
  final String title;
  final String titleAr;
  final String message;
  final String messageAr;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  NotificationEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.titleAr,
    required this.message,
    required this.messageAr,
    required this.timestamp,
    this.metadata,
    this.isRead = false,
  });

  NotificationEvent copyWith({bool? isRead}) {
    return NotificationEvent(
      id: id,
      type: type,
      title: title,
      titleAr: titleAr,
      message: message,
      messageAr: messageAr,
      timestamp: timestamp,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'titleAr': titleAr,
      'message': message,
      'messageAr': messageAr,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
      'isRead': isRead,
    };
  }

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      id: json['id'] as String,
      type: _parseType(json['type'] as String),
      title: json['title'] as String,
      titleAr: json['titleAr'] as String? ?? json['title'] as String,
      message: json['message'] as String,
      messageAr: json['messageAr'] as String? ?? json['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  static NotificationType _parseType(String typeString) {
    return NotificationType.values.firstWhere(
      (e) => e.toString() == typeString,
      orElse: () => NotificationType.info,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory NotificationEvent.fromJsonString(String jsonString) {
    return NotificationEvent.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

class NotificationLogService extends ChangeNotifier {
  static final NotificationLogService instance = NotificationLogService._();
  NotificationLogService._();

  static const int _maxNotifications = 100;
  static const String _notificationsKey = 'notification_log';

  final List<NotificationEvent> _notifications = [];
  SharedPreferences? _prefs;

  List<NotificationEvent> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((e) => !e.isRead).length;
  bool get hasUnread => unreadCount > 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notificationsJson = _prefs?.getStringList(_notificationsKey);
    if (notificationsJson != null) {
      _notifications.clear();
      for (final jsonString in notificationsJson) {
        try {
          final event = NotificationEvent.fromJsonString(jsonString);
          _notifications.add(event);
        } catch (e) {
          debugPrint('Failed to load notification: $e');
        }
      }
      notifyListeners();
    }
  }

  Future<void> _saveNotifications() async {
    // Keep only the most recent notifications
    if (_notifications.length > _maxNotifications) {
      _notifications.removeRange(0, _notifications.length - _maxNotifications);
    }
    
    // Store as proper JSON strings (includes isRead status)
    final notificationsJson = _notifications.map((e) => e.toJsonString()).toList();
    await _prefs?.setStringList(_notificationsKey, notificationsJson);
    notifyListeners();
  }

  void log({
    required NotificationType type,
    required String title,
    String titleAr = '',
    required String message,
    String messageAr = '',
    Map<String, dynamic>? metadata,
    bool showSystemNotification = false,
  }) {
    final event = NotificationEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      titleAr: titleAr.isEmpty ? title : titleAr,
      message: message,
      messageAr: messageAr.isEmpty ? message : messageAr,
      timestamp: DateTime.now(),
      metadata: metadata,
      isRead: false,
    );
    
    _notifications.add(event);
    _saveNotifications();
    
    debugPrint('Notification logged: $title - $message');
  }

  void logSubscriptionSuccess({String? price}) {
    log(
      type: NotificationType.subscriptionSuccess,
      title: 'Subscription Activated',
      titleAr: 'تم تفعيل الاشتراك',
      message: 'Premium subscription has been activated successfully${price != null ? ' for $price' : ''}',
      messageAr: 'تم تفعيل الاشتراك الممتاز بنجاح${price != null ? ' مقابل $price' : ''}',
      metadata: {'price': price},
    );
  }

  void logSubscriptionFailed(String reason) {
    log(
      type: NotificationType.subscriptionFailed,
      title: 'Subscription Failed',
      titleAr: 'فشل الاشتراك',
      message: reason,
      messageAr: reason,
      metadata: {'reason': reason},
    );
  }

  void logSubscriptionExpired() {
    log(
      type: NotificationType.subscriptionExpired,
      title: 'Subscription Expired',
      titleAr: 'انتهاء الاشتراك',
      message: 'Your premium subscription has expired. You have been reverted to the free tier.',
      messageAr: 'انتهى اشتراكك الممتاز. تم إرجاعك إلى النسخة المجانية.',
    );
  }

  void logSubscriptionCancelled() {
    log(
      type: NotificationType.subscriptionCancelled,
      title: 'Subscription Cancelled',
      titleAr: 'إلغاء الاشتراك',
      message: 'Your subscription has been cancelled through Google Play.',
      messageAr: 'تم إلغاء اشتراكك عبر Google Play.',
    );
  }

  void logCreditsRefilled(int amount, int maxCredits) {
    log(
      type: NotificationType.creditsRefilled,
      title: 'Credits Refilled',
      titleAr: 'إعادة تعبئة الرصيد',
      message: 'Your credits have been refilled to $amount/$maxCredits',
      messageAr: 'تمت إعادة تعبئة رصيدك إلى $amount/$maxCredits',
      metadata: {'amount': amount, 'maxCredits': maxCredits},
    );
  }

  void logCreditsLow(int remaining) {
    log(
      type: NotificationType.creditsLow,
      title: 'Low Credits Warning',
      titleAr: 'تحذير انخفاض الرصيد',
      message: 'You have $remaining credits remaining. Consider upgrading to premium for 2,000 credits refilled every 2–6 days.',
      messageAr: 'لديك $remaining رصيد متبقي. فكر في الترقية إلى البريميوم للحصول على 2,000 رصيد يتجدد كل 2-6 أيام.',
      metadata: {'remaining': remaining},
    );
  }

  void logTripStarted(String destination, double totalDistanceKm) {
    log(
      type: NotificationType.tripStarted,
      title: 'Trip Started',
      titleAr: 'بدء الرحلة',
      message: 'Trip to $destination started. Total distance: ${totalDistanceKm.toStringAsFixed(1)} km',
      messageAr: 'بدأت الرحلة إلى $destination. المسافة الإجمالية: ${totalDistanceKm.toStringAsFixed(1)} كم',
      metadata: {
        'destination': destination,
        'totalDistanceKm': totalDistanceKm,
      },
    );
  }

  void logTripCompleted(String destination, double totalDistanceKm) {
    log(
      type: NotificationType.tripCompleted,
      title: 'Trip Completed',
      titleAr: 'إكمال الرحلة',
      message: 'Trip to $destination completed. Total distance: ${totalDistanceKm.toStringAsFixed(1)} km',
      messageAr: 'اكتملت الرحلة إلى $destination. المسافة الإجمالية: ${totalDistanceKm.toStringAsFixed(1)} كم',
      metadata: {
        'destination': destination,
        'totalDistanceKm': totalDistanceKm,
      },
    );
  }

  void logTripProgress(String destination, double remainingKm, int percentComplete) {
    log(
      type: NotificationType.tripProgress,
      title: 'Trip Progress',
      titleAr: 'تقدم الرحلة',
      message: '$percentComplete% complete to $destination. ${remainingKm.toStringAsFixed(1)} km remaining',
      messageAr: '$percentComplete% مكتمل إلى $destination. ${remainingKm.toStringAsFixed(1)} كم متبقي',
      metadata: {
        'destination': destination,
        'remainingKm': remainingKm,
        'percentComplete': percentComplete,
      },
    );
  }

  void logError(String title, String message) {
    log(
      type: NotificationType.error,
      title: title,
      titleAr: title,
      message: message,
      messageAr: message,
    );
  }

  void logInfo(String title, String message) {
    log(
      type: NotificationType.info,
      title: title,
      titleAr: title,
      message: message,
      messageAr: message,
    );
  }

  void clear() {
    _notifications.clear();
    _saveNotifications();
  }

  void clearOlderThan(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    _notifications.removeWhere((e) => e.timestamp.isBefore(cutoff));
    _saveNotifications();
  }

  // ── Read status (persisted) ──────────────────────────────────────────────

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((e) => e.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    await _saveNotifications();
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) await _saveNotifications();
  }

  Future<void> markAsUnread(String id) async {
    final idx = _notifications.indexWhere((e) => e.id == id);
    if (idx == -1 || !_notifications[idx].isRead) return;
    _notifications[idx] = _notifications[idx].copyWith(isRead: false);
    await _saveNotifications();
  }
}
