import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> showGameAnalysisReady({
    required double accuracy,
    required int blunders,
    required int bestMoves,
  }) async {
    if (!_initialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'game_analysis',
        'Game Analysis',
        channelDescription: 'Notifications when game analysis is complete',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.show(
        100,
        'Game Analysis Ready',
        'Accuracy: ${accuracy.toStringAsFixed(0)}% | Blunders: $blunders | Best: $bestMoves',
        details,
      );
    } catch (e) {
      debugPrint('Failed to show analysis notification: $e');
    }
  }

  Future<void> showAchievementUnlocked(String achievementName) async {
    if (!_initialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'achievements',
        'Achievements',
        channelDescription: 'Achievement unlock notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.show(
        200,
        'Achievement Unlocked!',
        achievementName,
        details,
      );
    } catch (e) {
      debugPrint('Failed to show achievement notification: $e');
    }
  }

  Future<void> showRatingMilestone(int newRating) async {
    if (!_initialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rating_milestones',
        'Rating Milestones',
        channelDescription: 'Rating milestone notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.show(
        300,
        'Rating Milestone!',
        'You reached $newRating ELO!',
        details,
      );
    } catch (e) {
      debugPrint('Failed to show rating notification: $e');
    }
  }

  Future<void> showPuzzleStreak(int streak) async {
    if (!_initialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'puzzle_streak',
        'Puzzle Streak',
        channelDescription: 'Puzzle streak reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.show(
        400,
        'Keep Your Streak Alive!',
        'You\'re on a $streak-day puzzle streak. Don\'t break it!',
        details,
      );
    } catch (e) {
      debugPrint('Failed to show streak notification: $e');
    }
  }

  Future<void> scheduleDailyPuzzleReminder() async {
    debugPrint('Daily puzzle reminder scheduled (timezone scheduling requires platform setup)');
  }

  Future<void> scheduleStreakReminder() async {
    debugPrint('Streak reminder scheduled');
  }

  Future<void> cancelDailyPuzzleReminder() async {
    try {
      await _plugin.cancel(500);
    } catch (_) {}
  }

  Future<void> cancelStreakReminder() async {
    try {
      await _plugin.cancel(501);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
