import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Local-only, privacy-preserving notification service.
/// Schedules local daily puzzle reminders and streak protection nudges.
/// Zero background network traffic, zero servers, zero third-party telemetry.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      final success = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _isInitialized = success ?? true;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
      _isInitialized = true;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
    return true;
  }

  /// Schedule local daily puzzle reminder
  Future<void> scheduleDailyPuzzleReminder() async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'daily_puzzle_channel',
      'Daily Puzzle Reminders',
      channelDescription: 'Local notification when Today\'s Chess Puzzle is ready',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.cancel(1001);
      await _notificationsPlugin.periodicallyShow(
        1001,
        'Today\'s Chess Puzzle is Ready! 🧩',
        'Solve today\'s puzzle and keep your tactics sharp.',
        RepeatInterval.daily,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily puzzle notification: $e');
    }
  }

  /// Schedule local streak warning reminder
  Future<void> scheduleStreakReminder() async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'streak_reminder_channel',
      'Streak Protection Reminders',
      channelDescription: 'Local notification to protect your daily chess streak',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.cancel(1002);
      await _notificationsPlugin.periodicallyShow(
        1002,
        'Protect Your Chess Streak! 🔥',
        'Play a quick game or solve a puzzle today to maintain your daily streak.',
        RepeatInterval.daily,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule streak notification: $e');
    }
  }

  Future<void> cancelDailyPuzzleReminder() async {
    try {
      await _notificationsPlugin.cancel(1001);
    } catch (e) {
      debugPrint('Failed to cancel daily puzzle notification: $e');
    }
  }

  Future<void> cancelStreakReminder() async {
    try {
      await _notificationsPlugin.cancel(1002);
    } catch (e) {
      debugPrint('Failed to cancel streak notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }
}
