import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/services/notification_service.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') return true;
        if (methodCall.method == 'periodicallyShow') return null;
        if (methodCall.method == 'cancel') return null;
        if (methodCall.method == 'cancelAll') return null;
        return null;
      },
    );
  });

  group('NotificationService & Settings Integration Tests', () {
    test('NotificationService initializes correctly', () async {
      final service = NotificationService.instance;
      await service.initialize();

      expect(service.isInitialized, isTrue);
    });

    test('Scheduling daily puzzle and streak reminders completes without error', () async {
      final service = NotificationService.instance;
      await service.initialize();

      await expectLater(
        service.scheduleDailyPuzzleReminder(),
        completes,
      );

      await expectLater(
        service.scheduleStreakReminder(),
        completes,
      );
    });

    test('Cancelling reminders completes without error', () async {
      final service = NotificationService.instance;
      await service.initialize();

      await expectLater(service.cancelDailyPuzzleReminder(), completes);
      await expectLater(service.cancelStreakReminder(), completes);
      await expectLater(service.cancelAllNotifications(), completes);
    });

    test('SettingsNotifier toggling updates AppSettings notification state', () async {
      final container = ProviderContainer();

      final initialSettings = container.read(settingsProvider);
      expect(initialSettings.dailyPuzzleNotificationEnabled, isTrue);
      expect(initialSettings.streakNotificationEnabled, isTrue);

      final notifier = container.read(settingsProvider.notifier);
      notifier.toggleDailyPuzzleNotification();

      final updatedSettings = container.read(settingsProvider);
      expect(updatedSettings.dailyPuzzleNotificationEnabled, isFalse);

      notifier.toggleStreakNotification();
      final finalSettings = container.read(settingsProvider);
      expect(finalSettings.streakNotificationEnabled, isFalse);

      container.dispose();
    });
  });
}
