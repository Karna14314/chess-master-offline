import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Board Display Validation Tests', () {
    test('should validate correct starting position', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Start a new game
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );

      // Validate starting position
      expect(gameNotifier.validateStartingPosition(), true);
      expect(gameNotifier.validateAllPiecesPlaced(), true);
      expect(gameNotifier.validatePiecePlacements(), true);
      expect(gameNotifier.validateBoardDisplay(), true);

      container.dispose();
    });

    test('should validate all 32 pieces are placed correctly', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );

      // Check specific piece placements

      // White pieces
      expect(gameNotifier.getPieceAt('a1'), 'wR'); // White rook
      expect(gameNotifier.getPieceAt('b1'), 'wN'); // White knight
      expect(gameNotifier.getPieceAt('c1'), 'wB'); // White bishop
      expect(gameNotifier.getPieceAt('d1'), 'wQ'); // White queen
      expect(gameNotifier.getPieceAt('e1'), 'wK'); // White king
      expect(gameNotifier.getPieceAt('f1'), 'wB'); // White bishop
      expect(gameNotifier.getPieceAt('g1'), 'wN'); // White knight
      expect(gameNotifier.getPieceAt('h1'), 'wR'); // White rook

      // White pawns
      for (String file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        expect(gameNotifier.getPieceAt('${file}2'), 'wP');
      }

      // Black pieces
      expect(gameNotifier.getPieceAt('a8'), 'bR'); // Black rook
      expect(gameNotifier.getPieceAt('b8'), 'bN'); // Black knight
      expect(gameNotifier.getPieceAt('c8'), 'bB'); // Black bishop
      expect(gameNotifier.getPieceAt('d8'), 'bQ'); // Black queen
      expect(gameNotifier.getPieceAt('e8'), 'bK'); // Black king
      expect(gameNotifier.getPieceAt('f8'), 'bB'); // Black bishop
      expect(gameNotifier.getPieceAt('g8'), 'bN'); // Black knight
      expect(gameNotifier.getPieceAt('h8'), 'bR'); // Black rook

      // Black pawns
      for (String file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        expect(gameNotifier.getPieceAt('${file}7'), 'bP');
      }

      // Empty squares
      for (int rank = 3; rank <= 6; rank++) {
        for (String file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
          expect(gameNotifier.getPieceAt('$file$rank'), null);
        }
      }

      container.dispose();
    });

    test('should invalidate board display after moves', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode:
            GameMode.localMultiplayer, // Use local multiplayer to avoid engine
      );

      // Initially valid
      expect(gameNotifier.validateBoardDisplay(), true);

      // Make a move
      gameNotifier.selectSquare('e2');
      gameNotifier.selectSquare('e4');

      // Should no longer be starting position
      expect(gameNotifier.validateStartingPosition(), false);
      expect(gameNotifier.validateBoardDisplay(), false);

      // But should still have valid piece count (no captures yet)
      expect(gameNotifier.validateAllPiecesPlaced(), true);

      container.dispose();
    });

    test('should validate board display for different game modes', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Test bot mode
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );
      expect(gameNotifier.validateBoardDisplay(), true);

      // Test local multiplayer mode
      gameNotifier.startNewGame(
        playerColor: PlayerColor.black,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.localMultiplayer,
      );
      expect(gameNotifier.validateBoardDisplay(), true);

      // Test analysis mode
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.analysis,
      );
      expect(gameNotifier.validateBoardDisplay(), true);

      container.dispose();
    });
  });
}
