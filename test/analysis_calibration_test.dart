import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';

void main() {
  group('Analysis Calibration Tests (Lichess Model)', () {
    test('Winning simplification (+8.00 to +5.50) is NOT classified as Blunder', () {
      // White is winning by +8 pawns (800 cp) and simplifies to +5.5 pawns (550 cp).
      // Raw CPL is 250 cp, which would have been a blunder under raw CPL!
      final winBefore = EvalConstants.centipawnsToWinPercent(800);
      final winAfter = EvalConstants.centipawnsToWinPercent(550);
      final winDiff = winBefore - winAfter;

      final classification = classifyMoveCpl(
        centipawnLoss: 250.0, // Would be a blunder under raw CPL (>200)
        bestMove: 'e2e4',
        actualMove: 'd2d4',
        playerWinPercentBefore: winBefore,
        winPercentDiff: winDiff,
      );

      // Under Lichess win% thresholds, winDiff is ~6.6%, so it is Good/Inaccuracy, NEVER a Blunder or Mistake!
      expect(classification, isNot(equals(MoveClassification.blunder)));
      expect(classification, isNot(equals(MoveClassification.mistake)));
    });

    test('Losing position drop (-8.00 to -11.00) is NOT classified as Blunder', () {
      // In a completely lost position, shifting from -8 to -11 changes win% by 0.05%
      final winBefore = 100.0 - EvalConstants.centipawnsToWinPercent(-800);
      final winAfter = 100.0 - EvalConstants.centipawnsToWinPercent(-1100);
      final winDiff = (winBefore - winAfter).abs();

      final classification = classifyMoveCpl(
        centipawnLoss: 300.0,
        bestMove: 'e8e7',
        actualMove: 'e8d8',
        playerWinPercentBefore: winBefore,
        winPercentDiff: winDiff,
      );

      expect(classification, isNot(equals(MoveClassification.blunder)));
    });

    test('Improving move (negative raw loss clamped to 0) yields Best Move', () {
      final classification = classifyMoveCpl(
        centipawnLoss: 0.0,
        bestMove: 'g1f3',
        actualMove: 'd2d4',
        winPercentDiff: 0.0,
      );

      expect(classification, equals(MoveClassification.best));
    });

    test('Book move receives Book classification', () {
      final classification = classifyMoveCpl(
        centipawnLoss: 45.0,
        bestMove: 'g1f3',
        actualMove: 'e2e4',
        isBookMove: true,
      );

      expect(classification, equals(MoveClassification.book));
    });

    test('Real blunder in close game is correctly caught as Blunder', () {
      // Equal position +0.10 dropping to -3.50 (losing 360 cp)
      final winBefore = EvalConstants.centipawnsToWinPercent(10);
      final winAfter = EvalConstants.centipawnsToWinPercent(-350);
      final winDiff = winBefore - winAfter;

      // winDiff is ~29.3%, which is > 20% (Lichess Blunder threshold)
      expect(winDiff, greaterThan(20.0));

      final classification = classifyMoveCpl(
        centipawnLoss: 360.0,
        bestMove: 'e2e4',
        actualMove: 'g2g4',
        playerWinPercentBefore: winBefore,
        winPercentDiff: winDiff,
      );

      expect(classification, equals(MoveClassification.blunder));
    });

    test('Missed win is classified as Miss', () {
      // Had 85% win rate, made a move that dropped 35% win rate
      final classification = classifyMoveCpl(
        centipawnLoss: 250.0,
        bestMove: 'd1d8',
        actualMove: 'a1b1',
        playerWinPercentBefore: 85.0,
        winPercentDiff: 35.0,
      );

      expect(classification, equals(MoveClassification.miss));
    });

    test('Sound sacrifice with negative SEE is classified as Brilliant', () {
      final classification = classifyMoveCpl(
        centipawnLoss: 15.0,
        bestMove: 'e4e5',
        actualMove: 'd4d5',
        seeCentipawns: -300.0, // Gave up a piece
        winPercentDiff: 1.0,   // But held the win rate
      );

      expect(classification, equals(MoveClassification.brilliant));
    });

    test('Checkmate move is classified as Best Move, never Blunder', () {
      final classification = classifyMoveCpl(
        centipawnLoss: 0.0,
        bestMove: 'd1h5',
        actualMove: 'd1h5',
        isCheckmate: true,
      );

      expect(classification, equals(MoveClassification.best));
    });

    test('Sacrifice checkmate is classified as Brilliant', () {
      final classification = classifyMoveCpl(
        centipawnLoss: 0.0,
        bestMove: 'd1h5',
        actualMove: 'd1h5',
        isCheckmate: true,
        seeCentipawns: -900.0, // Queen sacrifice checkmate
      );

      expect(classification, equals(MoveClassification.brilliant));
    });

    test('Maintaining mate is not falsely classified as Miss', () {
      final classification = classifyMoveCpl(
        centipawnLoss: 0.0,
        bestMove: 'e1g1',
        actualMove: 'e1g1',
        isMateBefore: true,
        isMateAfter: true, // Still mate after move
      );

      expect(classification, isNot(equals(MoveClassification.miss)));
      expect(classification, equals(MoveClassification.best));
    });
  });
}
