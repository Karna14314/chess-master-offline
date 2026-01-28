import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess/chess.dart' as chess;

void main() {
  test('Benchmark goToMove performance', () async {
    // 1. Setup a game with many moves
    final gameGenerator = chess.Chess();
    final movesSan = <String>[];

    // Generate moves
    for (int i = 0; i < 150; i++) {
      if (gameGenerator.game_over) break;
      final validMoves = gameGenerator.moves();
      if (validMoves.isEmpty) break;

      final moveSan = validMoves[0];
      movesSan.add(moveSan);
      gameGenerator.move(moveSan);
    }

    print('Generated ${movesSan.length} moves for benchmark.');

    // Create ChessMove objects by replaying
    final replayGame = chess.Chess();
    final chessMoves = <ChessMove>[];

    for (final san in movesSan) {
      replayGame.move(san);

      // Get the move object to extract details
      final history = replayGame.history;
      final lastState = history.last;
      final move = lastState.move;

      // Manually create ChessMove to avoid issues with fromChessMove and game state
      chessMoves.add(ChessMove(
        from: move.fromAlgebraic,
        to: move.toAlgebraic,
        san: san,
        promotion: move.promotion?.name,
        isCapture: move.captured != null,
        isCheck: replayGame.in_check,
        isCheckmate: replayGame.in_checkmate,
        isCastle: move.flags & chess.Chess.BITS_KSIDE_CASTLE != 0 ||
          move.flags & chess.Chess.BITS_QSIDE_CASTLE != 0,
        fen: replayGame.fen,
      ));
    }

    final notifier = AnalysisNotifier();
    await notifier.loadGame(moves: chessMoves);

    final stopwatch = Stopwatch()..start();

    // Measure Next Move (Linear forward)
    print('Benchmarking Next Move (Linear forward)...');
    stopwatch.reset();
    for (int i = 0; i < chessMoves.length; i++) {
        await notifier.nextMove();
    }
    final forwardTime = stopwatch.elapsedMilliseconds;
    print('Next Move (0 -> End): ${forwardTime}ms');

    // Measure Previous Move (Linear backward)
    print('Benchmarking Previous Move (Linear backward)...');
    stopwatch.reset();
    for (int i = chessMoves.length - 1; i >= -1; i--) {
        await notifier.previousMove();
    }
    final backwardTime = stopwatch.elapsedMilliseconds;
    print('Previous Move (End -> Start): ${backwardTime}ms');
  });
}
