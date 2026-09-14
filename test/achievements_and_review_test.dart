import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/screens/stats/statistics_screen.dart';
import 'package:chess_master/screens/stats/achievements_screen.dart';
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
      expect(initialList.length, equals(28));
      expect(initialList.every((a) => !a.isUnlocked), isTrue);

      final notifier = container.read(achievementProvider.notifier);
      await notifier.unlock('first_blood');
      await notifier.unlock('giant_slayer');

      final updatedList = container.read(achievementProvider);
      expect(
        updatedList.firstWhere((a) => a.id == 'first_blood').isUnlocked,
        isTrue,
      );
      expect(
        updatedList.firstWhere((a) => a.id == 'giant_slayer').isUnlocked,
        isTrue,
      );
    });

    test('Progress checks unlock the right milestones', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(achievementProvider.notifier);
      notifier.checkGameProgress(
        totalGames: 50,
        bestElo: 1500,
        maxWinStreak: 3,
      );
      notifier.checkBotProgress(
        distinctBotsBeaten: 5,
        strongestBotElo: 1700,
        campaignStars: 18,
        campaignUnlockedLevel: 4,
      );
      notifier.checkPuzzleProgress(
        totalSolved: 50,
        currentStreak: 5,
        peakRating: 1600,
        journeySolved: 100,
      );
      notifier.checkStudyProgress(
        gamesAnalysed: 10,
        lessonsCompleted: 25,
        openingsPlayed: 5,
      );

      // Unlocks are serialized async work; wait for the queue to drain.
      await Future.delayed(const Duration(milliseconds: 500));

      final unlocked =
          container
              .read(achievementProvider)
              .where((a) => a.isUnlocked)
              .map((a) => a.id)
              .toSet();
      for (final id in [
        'first_blood',
        'regular_50',
        'win_streak_3',
        'bot_collector_5',
        'giant_slayer',
        'campaign_trail',
        'campaign_half',
        'puzzle_newbie',
        'puzzle_scholar',
        'hot_streak',
        'tactics_expert',
        'journey_100',
        'first_analysis',
        'analyst_10',
        'lesson_starter',
        'lesson_scholar',
        'opening_explorer',
      ]) {
        expect(unlocked, contains(id));
      }
      // Higher tiers stay locked.
      for (final id in [
        'bot_master_10',
        'grandmaster_slayer',
        'campaign_champion',
        'puzzle_elite',
        'journey_1000',
        'veteran_200',
      ]) {
        expect(unlocked, isNot(contains(id)));
      }
    });

    testWidgets(
      'StatisticsScreen renders Achievements subsection summary',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseServiceProvider.overrideWithValue(MockDatabaseService()),
              stockfishServiceProvider.overrideWithValue(
                MockStockfishService(),
              ),
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
        expect(find.textContaining('Unlocked'), findsWidgets);
      },
    );

    testWidgets('AchievementsScreen groups by category', (tester) async {
      // Tall viewport so the whole lazy list builds without scrolling
      // (nested ListViews make scrollUntilVisible ambiguous).
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AchievementsScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Bots & Battles'), findsOneWidget);
      expect(find.text('Puzzles & Tactics'), findsOneWidget);
      expect(find.text('Study & Analysis'), findsOneWidget);
      expect(find.text('Dedication'), findsOneWidget);
      expect(find.text('First Blood'), findsOneWidget);
      expect(find.text('Puzzle Elite'), findsOneWidget);
    });
  });
}
