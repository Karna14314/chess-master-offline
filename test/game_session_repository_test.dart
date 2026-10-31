import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/constants/app_constants.dart';

void main() {
  group('GameSession Result Status Tests', () {
    test('In-progress game has null result and is not completed', () {
      final inProgress = GameSession.create(
        gameMode: GameMode.bot,
      );

      expect(inProgress.result, isNull);
      expect(inProgress.isCompleted, isFalse);
    });

    test('Finished games (resigned/checkmate/timeout/draw) have non-null result and are completed', () {
      final baseGame = GameSession.create(
        gameMode: GameMode.bot,
      );

      final checkmate = baseGame.copyWith(
        result: GameResult.whiteWins,
        resultReason: 'Checkmate',
      );

      final resigned = baseGame.copyWith(
        result: GameResult.blackWins,
        resultReason: 'Resigned',
      );

      final draw = baseGame.copyWith(
        result: GameResult.draw,
        resultReason: 'Threefold Repetition',
      );

      expect(checkmate.result, isNotNull);
      expect(checkmate.isCompleted, isTrue);

      expect(resigned.result, isNotNull);
      expect(resigned.isCompleted, isTrue);

      expect(draw.result, isNotNull);
      expect(draw.isCompleted, isTrue);
    });
  });
}
