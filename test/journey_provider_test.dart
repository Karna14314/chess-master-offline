import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/journey_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('JourneyNotifier & JourneyProvider Tests', () {
    test('Initial Journey state starts at Level 1 with 0 solved count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(journeyProvider);
      expect(state.currentLevel, equals(1));
      expect(state.solvedCount, equals(0));
      expect(state.completionPercent, equals(0.0));
      expect(state.remainingCount, equals(kTotalJourneyLevels));
    });

    test('completeCurrentLevel increments level and solved count and unlocks milestone', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(journeyProvider.notifier);

      // Solve 9 levels
      for (int i = 0; i < 9; i++) {
        await notifier.completeCurrentLevel();
      }

      var state = container.read(journeyProvider);
      expect(state.currentLevel, equals(10));
      expect(state.solvedCount, equals(9));
      expect(state.unlockedMilestones, isEmpty);

      // 10th solved level unlocks 10-milestone
      final unlocked = await notifier.completeCurrentLevel();
      state = container.read(journeyProvider);

      expect(unlocked, equals(10));
      expect(state.currentLevel, equals(11));
      expect(state.solvedCount, equals(10));
      expect(state.completionPercent, equals(1.0));
      expect(state.unlockedMilestones, contains(10));
      expect(state.newlyUnlockedMilestone, equals(10));

      notifier.clearNewlyUnlockedMilestone();
      state = container.read(journeyProvider);
      expect(state.newlyUnlockedMilestone, isNull);
    });

    test('getPuzzleForLevel correctly returns mapped puzzle from sorted list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(journeyProvider.notifier);

      final mockPuzzles = List<Puzzle>.generate(
        1000,
        (i) => Puzzle(
          id: i + 1,
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: ['e2e4', 'e7e5'],
          rating: 600 + i * 2,
          themes: ['mate'],
          searchableThemes: ['mate'],
          popularity: 100,
        ),
      );

      final puzzleL1 = notifier.getPuzzleForLevel(1, mockPuzzles);
      final puzzleL500 = notifier.getPuzzleForLevel(500, mockPuzzles);

      expect(puzzleL1, isNotNull);
      expect(puzzleL1!.id, equals(1));
      expect(puzzleL1.rating, equals(600));

      expect(puzzleL500, isNotNull);
      expect(puzzleL500!.id, equals(500));
      expect(puzzleL500.rating, equals(1598));
    });
  });
}
