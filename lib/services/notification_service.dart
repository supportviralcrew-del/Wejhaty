import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a persistent ("ongoing", non-swipeable) notification that mirrors
/// a typical prayer-app notification bar: the next prayer's name and time,
/// plus a live-ticking countdown.
///
/// The countdown is rendered by Android itself via the notification's
/// built-in chronometer (`usesChronometer` + `chronometerCountDown`), so we
/// only need to call [showPrayerCountdown] once per prayer change - the OS
/// keeps the "HH:MM:SS remaining" text ticking on its own without the app
/// needing to stay awake or repeatedly re-post the notification.
///
/// iOS does not support ongoing, natively-ticking notifications the way
/// Android does, so this service is effectively a no-op there.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'prayer_countdown_channel';
  static const String _channelName = 'Prayer Countdown';
  static const String _channelDescription =
      'Persistent notification showing the next prayer time and countdown';
  static const int _notificationId = 100;

  /// Prepares the plugin and creates the Android notification channel.
  /// Safe to call multiple times - later calls are a no-op.
  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (!kIsWeb) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        // Default importance: ensures notification appears in status bar
        // and notification shade on Android 13+
        importance: Importance.defaultImportance,
        showBadge: false,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS runtime permission.
  /// Call this once (e.g. after onboarding, or right before first enabling
  /// the notification bar). Returns true if permission is granted.
  Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidImpl?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Shows/updates the persistent countdown notification.
  ///
  /// [title] should already be formatted, e.g. "Asr at 4:23 PM".
  /// [prayerTime] is the DateTime the prayer occurs at - the OS uses this
  /// to drive the live-ticking "time remaining" chronometer text.
  Future<void> showPrayerCountdown({
    required String title,
    required DateTime prayerTime,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true, // not swipeable, matches the reference bar
      autoCancel: false,
      onlyAlertOnce: true, // don't re-alert on every update
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: prayerTime.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      icon: '@drawable/ic_notification',
      // Brand accent — tints the small icon on the status bar / shade on
      // Android versions that support icon tinting.
      color: const Color(0xFF2E6FA8),
      colorized: false,
      subText: 'Prayer Times',
      styleInformation: BigTextStyleInformation(
        title,
        contentTitle: title,
        summaryText: 'Tap to open the app',
      ),
    );

    try {
      await _plugin.show(
        id: _notificationId,
        title: title,
        body: null, // left empty - the chronometer supplies the countdown
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('NotificationService: failed to show notification: $e');
    }
  }

  /// Removes the persistent notification (called when the user disables it
  /// from Settings).
  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('NotificationService: failed to cancel notification: $e');
    }
  }
}