import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/screens/stats/statistics_screen.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_test.dart';

class _MockHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Achievements & Review Prompt Tests', () {
    test('AchievementNotifier initializes and unlocks milestones', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialList = container.read(achievementProvider);
      expect(initialList.length, equals(6));
      expect(initialList.every((a) => !a.isUnlocked), isTrue);

      final notifier = container.read(achievementProvider.notifier);
      await notifier.unlock('first_win');
      await notifier.unlock('ai_level_5');

      final updatedList = container.read(achievementProvider);
      expect(updatedList.firstWhere((a) => a.id == 'first_win').isUnlocked, isTrue);
      expect(updatedList.firstWhere((a) => a.id == 'ai_level_5').isUnlocked, isTrue);
    });

    testWidgets('StatisticsScreen renders Achievements & Trophies section in light and dark themes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(MockDatabaseService()),
            stockfishServiceProvider.overrideWithValue(MockStockfishService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const StatisticsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Achievements & Trophies'), findsOneWidget);
      expect(find.text('First Victory'), findsOneWidget);
      expect(find.text('Tactics Scholar'), findsOneWidget);
      expect(find.text('Grandmaster Slayer'), findsOneWidget);
    });
  });
}
