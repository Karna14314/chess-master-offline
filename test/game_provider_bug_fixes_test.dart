import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('GameProvider Auto-Queen Bug Fix Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('tryMove rejects promotion if promotion string is null', () {
      final notifier = container.read(gameProvider.notifier);

      // Setup a game with a pawn about to promote
      // White pawn on a7
      notifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: const DifficultyLevel(
          name: 'Test',
          level: 1,
          elo: 800,
          depth: 1,
          thinkTimeMs: 100,
        ),
        timeControl: const TimeControl(name: 'Test', minutes: 10, increment: 0),
        gameMode: GameMode.localMultiplayer,
        startingFen: '8/P7/8/8/8/8/8/K1k5 w - - 0 1',
      );

      // Verify the pawn is on a7
      final piece = notifier.state.board.get('a7');
      expect(piece, isNotNull);
      expect(piece?.type.name.toLowerCase(), equals('p'));

      // Try to move a7 to a8 without a promotion character
      // This is the auto-queen bug fix verification
      final success = notifier.tryMove('a7', 'a8');

      // The move should be rejected because promotion is null
      expect(success, isFalse);

      // Verify pawn is still on a7
      expect(notifier.state.board.get('a7'), isNotNull);

      // Try again WITH a promotion character
      final successWithPromotion = notifier.tryMove('a7', 'a8', promotion: 'q');

      // This should succeed
      expect(successWithPromotion, isTrue);
    });
  });
}
