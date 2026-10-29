import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/services/daily_puzzle_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyPuzzleNotificationService Unit Tests', () {
    test('calculateNext7NotificationTimes includes today when target is in future and unsolved', () {
      final fixedNow = DateTime(2025, 5, 10, 8, 0, 0); // 8:00 AM
      final service = DailyPuzzleNotificationService(clock: Clock.fixed(fixedNow));

      final times = service.calculateNext7NotificationTimes(
        hour: 9,
        minute: 0,
        isTodaySolved: false,
      );

      expect(times.length, equals(7));
      expect(times.first, equals(DateTime(2025, 5, 10, 9, 0, 0))); // Today at 9 AM
      expect(times.last, equals(DateTime(2025, 5, 16, 9, 0, 0)));
    });

    test('calculateNext7NotificationTimes skips today when target time has passed', () {
      final fixedNow = DateTime(2025, 5, 10, 10, 0, 0); // 10:00 AM (past 9 AM)
      final service = DailyPuzzleNotificationService(clock: Clock.fixed(fixedNow));

      final times = service.calculateNext7NotificationTimes(
        hour: 9,
        minute: 0,
        isTodaySolved: false,
      );

      expect(times.length, equals(6));
      expect(times.first, equals(DateTime(2025, 5, 11, 9, 0, 0))); // Starts tomorrow
    });

    test('calculateNext7NotificationTimes skips today when today puzzle is solved', () {
      final fixedNow = DateTime(2025, 5, 10, 8, 0, 0); // 8:00 AM
      final service = DailyPuzzleNotificationService(clock: Clock.fixed(fixedNow));

      final times = service.calculateNext7NotificationTimes(
        hour: 9,
        minute: 0,
        isTodaySolved: true, // Solved today
      );

      expect(times.length, equals(6));
      expect(times.first, equals(DateTime(2025, 5, 11, 9, 0, 0))); // Starts tomorrow
    });

    test('buildNotificationBody returns expected copy for streak 0 vs positive streak', () {
      expect(
        DailyPuzzleNotificationService.buildNotificationBody(0),
        equals('Today\'s puzzle is ready'),
      );

      expect(
        DailyPuzzleNotificationService.buildNotificationBody(5),
        equals('Keep your 5-day streak going — today\'s puzzle is ready'),
      );
    });

    test('shouldShowPrompt respects 2-prompt limit and 7-day interval rule', () async {
      final baseTime = DateTime(2025, 5, 1, 10, 0, 0);
      final service = DailyPuzzleNotificationService(clock: Clock.fixed(baseTime));

      // Initially 0 prompts -> should show
      SharedPreferences.setMockInitialValues({
        'daily_puzzle_prompt_count': 0,
        'daily_puzzle_last_prompt_time': 0,
      });

      expect(await service.shouldShowPrompt(), isTrue);

      // Recorded prompt 1 on May 1
      await service.recordPromptShown();

      // Check 3 days later (May 4) -> should NOT show (< 7 days)
      final day3Service = DailyPuzzleNotificationService(
        clock: Clock.fixed(baseTime.add(const Duration(days: 3))),
      );
      expect(await day3Service.shouldShowPrompt(), isFalse);

      // Check 8 days later (May 9) -> SHOULD show (>= 7 days)
      final day8Service = DailyPuzzleNotificationService(
        clock: Clock.fixed(baseTime.add(const Duration(days: 8))),
      );
      expect(await day8Service.shouldShowPrompt(), isTrue);

      // Recorded prompt 2 -> now prompt_count == 2 -> should NEVER show again
      await day8Service.recordPromptShown();

      final day20Service = DailyPuzzleNotificationService(
        clock: Clock.fixed(baseTime.add(const Duration(days: 20))),
      );
      expect(await day20Service.shouldShowPrompt(), isFalse);
    });
  });
}
