import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';

void main() {
  test('GameNotifier captures correctly', () {
    final container = ProviderContainer();
    final notifier = container.read(gameProvider.notifier);

    // Start game
    notifier.startNewGame(
      playerColor: PlayerColor.white,
      difficulty: AppConstants.difficultyLevels[0],
      timeControl: AppConstants.timeControls[0],
      gameMode: GameMode.localMultiplayer, // So we can play both sides easily
      useTimer: false,
    );

    // Setup: e4 d5 exd5
    // White moves e2-e4
    var success = notifier.tryMove('e2', 'e4');
    expect(success, true, reason: 'e2-e4 should be valid');

    // Black moves d7-d5
    success = notifier.tryMove('d7', 'd5');
    expect(success, true, reason: 'd7-d5 should be valid');

    // White captures d5
    success = notifier.tryMove('e4', 'd5');
    expect(success, true, reason: 'e4-d5 (capture) should be valid');

    final state = container.read(gameProvider);
    expect(state.moveHistory.length, 3);

    final lastMove = state.moveHistory.last;
    expect(lastMove.isCapture, true);
    expect(lastMove.capturedPiece, 'p'); // 'p' for Pawn
  });
}
