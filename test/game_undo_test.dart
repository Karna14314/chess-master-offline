import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test(
    'undoMove should restore board state correctly in local multiplayer (single move)',
    () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Start new game
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.localMultiplayer,
      );

      var gameState = container.read(gameProvider);
      final initialFen = gameState.fen;

      // Make a move: e2 to e4
      final moveSuccess = gameNotifier.tryMove('e2', 'e4');
      expect(moveSuccess, true, reason: 'Move e2-e4 should be legal');

      gameState = container.read(gameProvider);
      expect(
        gameState.fen,
        isNot(equals(initialFen)),
        reason: 'FEN should change after move',
      );
      expect(gameState.moveHistory.length, 1);

      // Undo the move
      gameNotifier.undoMove();

      gameState = container.read(gameProvider);

      expect(
        gameState.fen,
        equals(initialFen),
        reason: 'FEN should match initial FEN after undo',
      );
      expect(
        gameState.moveHistory.length,
        0,
        reason: 'History should be empty after undo',
      );

      container.dispose();
    },
  );

  test(
    'undoMove should restore board state correctly in local multiplayer (two moves)',
    () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Start new game
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.localMultiplayer,
      );

      var gameState = container.read(gameProvider);

      // Move 1: e2-e4
      gameNotifier.tryMove('e2', 'e4');
      final afterFirstMoveFen = container.read(gameProvider).fen;

      // Move 2: e7-e5
      gameNotifier.tryMove('e7', 'e5');

      gameState = container.read(gameProvider);
      expect(gameState.moveHistory.length, 2);

      // Undo the move (should undo e7-e5 only)
      gameNotifier.undoMove();

      gameState = container.read(gameProvider);

      // Should be at state after e2-e4
      expect(
        gameState.fen,
        equals(afterFirstMoveFen),
        reason: 'FEN should match e2-e4 state',
      );
      expect(
        gameState.moveHistory.length,
        1,
        reason: 'History should have 1 move',
      );

      container.dispose();
    },
  );

  test(
    'undoMove should restore board state correctly in bot mode (undo both player and bot moves)',
    () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Start new game vs Bot (White player)
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );

      var gameState = container.read(gameProvider);
      final initialFen = gameState.fen;

      // Make a move: e2 to e4
      gameNotifier.tryMove('e2', 'e4');

      // Simulate bot move: e7 to e5
      gameNotifier.applyBotMove('e7', 'e5');

      gameState = container.read(gameProvider);
      expect(gameState.moveHistory.length, 2);
      expect(
        gameState.isPlayerTurn,
        true,
        reason: 'Should be player turn after bot move',
      );

      // Undo the move
      gameNotifier.undoMove();

      gameState = container.read(gameProvider);

      expect(
        gameState.fen,
        equals(initialFen),
        reason: 'FEN should match initial FEN after undo (undo both moves)',
      );
      expect(
        gameState.moveHistory.length,
        0,
        reason: 'History should be empty after undo',
      );

      container.dispose();
    },
  );

  test(
    'undoMove should restore board state correctly in bot mode (undo while bot thinking)',
    () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Start new game vs Bot (White player)
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );

      var gameState = container.read(gameProvider);
      final initialFen = gameState.fen;

      // Make a move: e2 to e4
      gameNotifier.tryMove('e2', 'e4');

      // Bot has NOT moved yet.
      // It is Bot's turn.

      gameState = container.read(gameProvider);
      expect(gameState.moveHistory.length, 1);
      expect(gameState.isPlayerTurn, false, reason: 'Should be bot turn');

      // Undo the move
      gameNotifier.undoMove();

      gameState = container.read(gameProvider);

      expect(
        gameState.fen,
        equals(initialFen),
        reason: 'FEN should match initial FEN after undo',
      );
      expect(
        gameState.moveHistory.length,
        0,
        reason: 'History should be empty after undo',
      );

      container.dispose();
    },
  );
}
