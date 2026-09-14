import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/providers/journey_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/screens/home/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/theme/app_theme.dart';

class MockDatabaseService extends Fake implements DatabaseService {
  @override
  Future<Map<String, dynamic>?> getStatistics() async => {
    'current_puzzle_rating': 1200,
    'puzzles_solved': 0,
    'puzzles_attempted': 0,
  };

  @override
  Future<void> savePuzzleProgress(int puzzleId, bool solved) async {}

  @override
  Future<void> updateStatistics(Map<String, dynamic> updates) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
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

    test('Solving Journey puzzle on retry completes current level and advances level progress', () async {
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(MockDatabaseService()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(puzzleProvider, (_, __) {});

      final mockPuzzles = [
        Puzzle(
          id: 101,
          fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
          moves: ['f1c4', 'g8f6'],
          rating: 800,
          themes: ['opening'],
          searchableThemes: ['opening'],
          popularity: 100,
        ),
      ];

      final notifier = container.read(puzzleProvider.notifier);
      notifier.loadPuzzlesForTesting(mockPuzzles);
      notifier.setModeConfig(mode: PuzzleFilterMode.journey);

      expect(container.read(journeyProvider).currentLevel, equals(1));
      expect(container.read(journeyProvider).solvedCount, equals(0));

      // Simulate wrong move and retry
      notifier.tryMove('a7', 'a6'); // wrong move
      await Future.delayed(const Duration(milliseconds: 50));
      await notifier.retryPuzzle();

      expect(container.read(puzzleProvider).isRetry, isTrue);
      expect(container.read(puzzleProvider).state, equals(PuzzleState.playing));

      // Now solve it on retry: player move g8 -> f6
      notifier.tryMove('g8', 'f6');

      // Wait for completion
      await Future.delayed(const Duration(milliseconds: 100));

      final journeyState = container.read(journeyProvider);
      expect(journeyState.currentLevel, equals(2));
      expect(journeyState.solvedCount, equals(1));
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
    testWidgets('Renders Bot Arena in the upper viewport', (tester) async {
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

      expect(find.text('Bot Arena'), findsOneWidget);
      expect(find.text('Daily Puzzle'), findsOneWidget);
      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Analyze Game'), findsOneWidget);
    });
  });
}
