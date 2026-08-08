import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/static_exchange_evaluator.dart';
import 'package:chess_master/models/analysis_model.dart';

/// Tests for the previously unreachable classifications: Brilliant, Great and
/// the non-mate Miss case, plus the SEE helper that powers Brilliant.
void main() {
  group('StaticExchangeEvaluator', () {
    test('free capture of an undefended pawn wins material', () {
      // White rook on a1, black pawn on a7, nothing defends it.
      final board = chess.Chess.fromFEN('4k3/p7/8/8/8/8/8/R3K3 w - - 0 1');
      expect(
        StaticExchangeEvaluator.evaluate(board, 'a1', 'a7'),
        equals(100),
      );
    });

    test('capturing a defended pawn with a rook loses material', () {
      // Black pawn on a7 defended by the king on b8: Rxa7 wins 100 then loses
      // the rook (500) → clearly negative.
      final board = chess.Chess.fromFEN('1k6/p7/8/8/8/8/8/R3K3 w - - 0 1');
      final see = StaticExchangeEvaluator.evaluate(board, 'a1', 'a7');
      expect(see, lessThan(0));
      expect(see, equals(100 - 500));
    });

    test('quiet move into an attacked square is a sacrifice', () {
      // White rook steps to a7 where the black king can take it for free.
      final board = chess.Chess.fromFEN('1k6/8/8/8/8/8/8/R3K3 w - - 0 1');
      expect(
        StaticExchangeEvaluator.evaluate(board, 'a1', 'a7'),
        equals(-500),
      );
    });

    test('quiet safe move is materially neutral', () {
      final board = chess.Chess.fromFEN('4k3/8/8/8/8/8/8/R3K3 w - - 0 1');
      expect(
        StaticExchangeEvaluator.evaluate(board, 'a1', 'a5'),
        equals(0),
      );
    });

    test('board is left unmodified', () {
      const fen = '1k6/p7/8/8/8/8/8/R3K3 w - - 0 1';
      final board = chess.Chess.fromFEN(fen);
      StaticExchangeEvaluator.evaluate(board, 'a1', 'a7');
      expect(board.fen, equals(fen));
    });
  });

  group('classifyMoveCpl — Brilliant', () {
    test('sound sacrifice (material lost, eval held) is Brilliant', () {
      final c = classifyMoveCpl(
        centipawnLoss: 5,
        bestMove: 'a1a8',
        actualMove: 'c4f7',
        seeCentipawns: -330,
      );
      expect(c, equals(MoveClassification.brilliant));
    });

    test('unsound sacrifice (material lost, eval collapses) is not Brilliant',
        () {
      final c = classifyMoveCpl(
        centipawnLoss: 450,
        bestMove: 'a1a8',
        actualMove: 'c4f7',
        seeCentipawns: -330,
      );
      expect(c, equals(MoveClassification.blunder));
    });

    test('good move that risks no material is not Brilliant', () {
      final c = classifyMoveCpl(
        centipawnLoss: 5,
        bestMove: 'a1a8',
        actualMove: 'g1f3',
        seeCentipawns: 0,
      );
      expect(c, isNot(MoveClassification.brilliant));
    });

    test('a sacrifice smaller than the threshold is not Brilliant', () {
      final c = classifyMoveCpl(
        centipawnLoss: 5,
        bestMove: 'a1a8',
        actualMove: 'g1f3',
        seeCentipawns: -20,
      );
      expect(c, isNot(MoveClassification.brilliant));
    });
  });

  group('classifyMoveCpl — Great', () {
    test('only move within tolerance is Great', () {
      final c = classifyMoveCpl(
        centipawnLoss: 4,
        bestMove: 'a1a8',
        actualMove: 'b2b4',
        secondBestCentipawnLoss: 150,
      );
      expect(c, equals(MoveClassification.great));
    });

    test('move with a comparable alternative is not Great', () {
      final c = classifyMoveCpl(
        centipawnLoss: 4,
        bestMove: 'a1a8',
        actualMove: 'b2b4',
        secondBestCentipawnLoss: 5,
      );
      expect(c, equals(MoveClassification.best));
    });

    test('Brilliant takes precedence over Great', () {
      final c = classifyMoveCpl(
        centipawnLoss: 4,
        bestMove: 'a1a8',
        actualMove: 'c4f7',
        seeCentipawns: -300,
        secondBestCentipawnLoss: 150,
      );
      expect(c, equals(MoveClassification.brilliant));
    });
  });

  group('classifyMoveCpl — Miss (non-mate)', () {
    test('throwing away a winning position is a Miss', () {
      final c = classifyMoveCpl(
        centipawnLoss: 120,
        bestMove: 'a1a8',
        actualMove: 'h2h3',
        playerWinPercentBefore: 92,
        winPercentDiff: 40,
      );
      expect(c, equals(MoveClassification.miss));
    });

    test('same drop from a balanced position is graded on CPL instead', () {
      final c = classifyMoveCpl(
        centipawnLoss: 120,
        bestMove: 'a1a8',
        actualMove: 'h2h3',
        playerWinPercentBefore: 50,
        winPercentDiff: 40,
      );
      expect(c, equals(MoveClassification.mistake));
    });

    test('small drop from a winning position is not a Miss', () {
      final c = classifyMoveCpl(
        centipawnLoss: 60,
        bestMove: 'a1a8',
        actualMove: 'h2h3',
        playerWinPercentBefore: 92,
        winPercentDiff: 4,
      );
      // Graded on CPL (60cp) instead of being promoted to Miss.
      expect(c, equals(MoveClassification.inaccuracy));
    });
  });

  group('classifyMoveCpl — existing behaviour is preserved', () {
    test('thresholds without the optional signals are unchanged', () {
      MoveClassification classify(double cpl) => classifyMoveCpl(
            centipawnLoss: cpl,
            bestMove: 'a1a8',
            actualMove: 'h2h3',
          );

      expect(classify(0), equals(MoveClassification.best));
      expect(classify(10), equals(MoveClassification.best));
      expect(classify(20), equals(MoveClassification.excellent));
      expect(classify(50), equals(MoveClassification.good));
      expect(classify(100), equals(MoveClassification.inaccuracy));
      expect(classify(200), equals(MoveClassification.mistake));
      expect(classify(201), equals(MoveClassification.blunder));
    });

    test('playing the engine best move still reports Best', () {
      final c = classifyMoveCpl(
        centipawnLoss: 0,
        bestMove: 'e2e4',
        actualMove: 'e2e4',
        secondBestCentipawnLoss: 5,
      );
      expect(c, equals(MoveClassification.best));
    });

    test('mate handling is unaffected by the new signals', () {
      final c = classifyMoveCpl(
        centipawnLoss: 0,
        bestMove: 'e2e4',
        actualMove: 'h2h3',
        isMateBefore: true,
        isMateAfter: true,
        seeCentipawns: -900,
      );
      expect(c, equals(MoveClassification.miss));
    });
  });
}
