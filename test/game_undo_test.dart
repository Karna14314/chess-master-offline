import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('undoMove should restore board state correctly', () {
    final container = ProviderContainer();
    final gameNotifier = container.read(gameProvider.notifier);

    // Start new game
    gameNotifier.startNewGame(
      playerColor: PlayerColor.white,
      difficulty: AppConstants.difficultyLevels[0],
      timeControl: AppConstants.timeControls[0],
      gameMode: GameMode.localMultiplayer, // Easier to control both sides
    );

    var gameState = container.read(gameProvider);
    final initialFen = gameState.fen;

    // Make a move: e2 to e4
    // We need to use tryMove or _makeMove directly. tryMove is public.
    // e2 is white pawn.
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

    // This expectation is expected to fail with the bug
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
  });
}
