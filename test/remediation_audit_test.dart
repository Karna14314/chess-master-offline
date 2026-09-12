import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/screens/home/home_screen.dart';
import 'package:chess_master/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Journey Mode Business Rules Regression Tests', () {
    test('skipPuzzle is rejected in Journey mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(puzzleProvider.notifier);
      notifier.setModeConfig(mode: PuzzleFilterMode.journey);

      final initialPuzzle = container.read(puzzleProvider).currentPuzzle;

      // Attempt skip
      await notifier.skipPuzzle();

      // State should remain unchanged in Journey mode
      final currentPuzzle = container.read(puzzleProvider).currentPuzzle;
      expect(currentPuzzle, equals(initialPuzzle));
      expect(
        container.read(puzzleProvider).mode,
        equals(PuzzleFilterMode.journey),
      );
    });

    test('showSolution is rejected in Journey mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(puzzleProvider.notifier);
      notifier.setModeConfig(mode: PuzzleFilterMode.journey);

      // Attempt showSolution
      await notifier.showSolution();

      // showingSolution must remain false
      expect(container.read(puzzleProvider).showingSolution, isFalse);
    });
  });

  group('Daily Puzzle State Isolation Regression Tests', () {
    test(
      'Solving non-daily puzzle does not mark Daily Puzzle as completed',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final streakNotifier = container.read(streakProvider.notifier);
        await streakNotifier.loadStreak();

        expect(
          container.read(streakProvider).isDailyPuzzleSolvedToday,
          isFalse,
        );

        // Mark generic puzzle solved
        await streakNotifier.markPuzzleSolvedToday();

        // Generic puzzle solved should be true, but Daily Puzzle solved MUST remain false
        expect(container.read(streakProvider).isPuzzleSolvedToday, isTrue);
        expect(
          container.read(streakProvider).isDailyPuzzleSolvedToday,
          isFalse,
        );
      },
    );

    test(
      'Solving Daily Puzzle marks isDailyPuzzleSolvedToday as true',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final streakNotifier = container.read(streakProvider.notifier);
        await streakNotifier.loadStreak();

        // Mark Daily Puzzle solved
        await streakNotifier.markDailyPuzzleSolvedToday();

        expect(container.read(streakProvider).isDailyPuzzleSolvedToday, isTrue);
      },
    );
  });

  group('Home Screen Viewport Information Hierarchy Tests', () {
    testWidgets('Renders Game Modes in the upper viewport', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Game Modes'), findsOneWidget);
      expect(find.text('Play Bot'), findsOneWidget);
      expect(find.text('Daily Puzzle'), findsOneWidget);
      expect(find.text('Play Friend'), findsOneWidget);
      expect(find.text('Analyze Game'), findsOneWidget);
    });
  });
}
