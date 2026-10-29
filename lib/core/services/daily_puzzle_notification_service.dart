import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit-testable Local Daily Puzzle Notification Service
class DailyPuzzleNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Clock _clock;
  bool _initialized = false;

  DailyPuzzleNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    Clock clock = const Clock(),
  })  : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _clock = clock;

  static final DailyPuzzleNotificationService instance =
      DailyPuzzleNotificationService();

  Clock get clock => _clock;

  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTap,
  }) async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Timezone initialization failed: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<bool> hasSystemPermission() async {
    try {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        return enabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Calculates the next 7 daily notification times given target hour & minute
  List<DateTime> calculateNext7NotificationTimes({
    required int hour,
    required int minute,
    bool isTodaySolved = false,
  }) {
    final now = _clock.now();
    final List<DateTime> times = [];

    for (int i = 0; i < 7; i++) {
      final targetDate = DateTime(now.year, now.month, now.day + i, hour, minute);

      // If it's today (i == 0)
      if (i == 0) {
        // Skip today if already solved OR if target time has already passed today
        if (isTodaySolved || targetDate.isBefore(now)) {
          continue;
        }
      }

      times.add(targetDate);
    }

    return times;
  }

  /// Builds notification body copy given a streak count
  static String buildNotificationBody(int streakCount) {
    if (streakCount > 0) {
      return 'Keep your $streakCount-day streak going — today\'s puzzle is ready';
    }
    return 'Today\'s puzzle is ready';
  }

  /// Schedule rolling 7 days of daily puzzle notifications
  Future<void> scheduleRolling7Days({
    required int hour,
    required int minute,
    required int streakCount,
    bool isTodaySolved = false,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Cancel previous scheduled notifications (IDs 1001-1007)
      for (int id = 1001; id <= 1007; id++) {
        await _notificationsPlugin.cancel(id);
      }

      final times = calculateNext7NotificationTimes(
        hour: hour,
        minute: minute,
        isTodaySolved: isTodaySolved,
      );

      final body = buildNotificationBody(streakCount);

      const androidDetails = AndroidNotificationDetails(
        'daily_puzzle',
        'Daily Puzzle',
        channelDescription: 'Daily puzzle reminder notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      for (int i = 0; i < times.length && i < 7; i++) {
        final scheduledTime = times[i];
        final id = 1001 + i;

        try {
          final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
          await _notificationsPlugin.zonedSchedule(
            id,
            'ChessMaster Puzzle',
            body,
            tzScheduledTime,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'daily_puzzle',
          );
        } catch (e) {
          debugPrint('Failed to schedule zoned notification $id: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to schedule rolling 7 days: $e');
    }
  }

  /// Cancel today's pending notification
  Future<void> cancelTodayNotification() async {
    try {
      await _notificationsPlugin.cancel(1001);
    } catch (_) {}
  }

  /// Cancel all daily puzzle notifications
  Future<void> cancelAll() async {
    try {
      for (int id = 1001; id <= 1007; id++) {
        await _notificationsPlugin.cancel(id);
      }
    } catch (_) {}
  }

  /// Prompt eligibility check:
  /// - Ask at most twice in total
  /// - Second ask at least 7 days after the first ask
  /// - Never ask if system permission already granted
  Future<bool> shouldShowPrompt() async {
    final hasPermission = await hasSystemPermission();
    if (hasPermission) return false;

    final prefs = await SharedPreferences.getInstance();
    final promptCount = prefs.getInt('daily_puzzle_prompt_count') ?? 0;
    final lastPromptTimeMs = prefs.getInt('daily_puzzle_last_prompt_time') ?? 0;

    if (promptCount >= 2) return false;

    if (promptCount == 1) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptTimeMs);
      if (_clock.now().difference(lastPrompt).inDays < 7) {
        return false;
      }
    }

    return true;
  }

  Future<void> recordPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final promptCount = prefs.getInt('daily_puzzle_prompt_count') ?? 0;
    await prefs.setInt('daily_puzzle_prompt_count', promptCount + 1);
    await prefs.setInt('daily_puzzle_last_prompt_time', _clock.now().millisecondsSinceEpoch);
  }
}
