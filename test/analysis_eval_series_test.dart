import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/analysis_model.dart';

/// Regression tests for the eval-series semantics behind the eval graph.
///
/// `evaluations` is indexed by POSITION (index i == after i plies), so it has
/// plies + 1 entries and index 0 is the starting position. It must be built
/// from the actually-reached evals, not the counterfactual best-line evals.
void main() {
  MoveAnalysis move({
    required int index,
    required double evalBefore,
    required double evalAfter,
    double? actualEvalBeforeMove,
    required bool isWhiteMove,
  }) {
    return MoveAnalysis(
      moveIndex: index,
      san: 'm$index',
      fen: '...',
      evalBefore: evalBefore,
      evalAfter: evalAfter,
      actualEvalBeforeMove: actualEvalBeforeMove,
      classification: MoveClassification.best,
      isWhiteMove: isWhiteMove,
      centipawnLoss: 0,
      accuracy: 100,
    );
  }

  group('MoveAnalysis.actualEvalBeforeMove', () {
    test('defaults to evalBefore when not supplied', () {
      final m = move(
        index: 0,
        evalBefore: 0.3,
        evalAfter: 0.1,
        isWhiteMove: true,
      );
      expect(m.actualEvalBeforeMove, equals(0.3));
    });

    test('keeps the best-line evalBefore separate from the actual eval', () {
      // White blundered on the previous ply: the position actually reached is
      // worth -2.0 even though the engine's best line was +0.5.
      final m = move(
        index: 1,
        evalBefore: 0.5,
        evalAfter: -2.1,
        actualEvalBeforeMove: -2.0,
        isWhiteMove: false,
      );
      expect(m.evalBefore, equals(0.5), reason: 'CPL baseline is untouched');
      expect(m.actualEvalBeforeMove, equals(-2.0));
    });
  });

  group('GameAnalysis.evaluations', () {
    test('has plies + 1 entries and starts at the actual start eval', () {
      final moves = [
        move(
          index: 0,
          evalBefore: 0.2,
          evalAfter: 0.1,
          actualEvalBeforeMove: 0.2,
          isWhiteMove: true,
        ),
        move(
          index: 1,
          evalBefore: 0.4,
          evalAfter: -1.5,
          actualEvalBeforeMove: 0.1,
          isWhiteMove: false,
        ),
        move(
          index: 2,
          evalBefore: -1.2,
          evalAfter: -1.4,
          actualEvalBeforeMove: -1.5,
          isWhiteMove: true,
        ),
      ];
      final ga = GameAnalysis.fromMoves(moves);

      expect(ga.evaluations.length, equals(moves.length + 1));
      expect(ga.evaluations.first, equals(0.2));
      expect(ga.evaluations, equals([0.2, 0.1, -1.5, -1.4]));
    });

    test('series is continuous: evaluations[i+1] == move i evalAfter', () {
      final moves = [
        move(
          index: 0,
          evalBefore: 0.2,
          evalAfter: 0.1,
          actualEvalBeforeMove: 0.2,
          isWhiteMove: true,
        ),
        move(
          index: 1,
          evalBefore: 0.9,
          evalAfter: -3.0,
          actualEvalBeforeMove: 0.1,
          isWhiteMove: false,
        ),
      ];
      final ga = GameAnalysis.fromMoves(moves);

      for (int i = 0; i < moves.length; i++) {
        expect(
          ga.evaluations[i + 1],
          equals(moves[i].evalAfter),
          reason: 'position after ply $i',
        );
      }
    });

    test('does not use the counterfactual best-line eval for the graph', () {
      // Ply 1's engine best eval (0.9) must NOT appear in the series; the
      // actually reached 0.1 must be what the curve passes through.
      final moves = [
        move(
          index: 0,
          evalBefore: 0.2,
          evalAfter: 0.1,
          actualEvalBeforeMove: 0.2,
          isWhiteMove: true,
        ),
        move(
          index: 1,
          evalBefore: 0.9,
          evalAfter: -3.0,
          actualEvalBeforeMove: 0.1,
          isWhiteMove: false,
        ),
      ];
      final ga = GameAnalysis.fromMoves(moves);
      expect(ga.evaluations.contains(0.9), isFalse);
    });
  });

  group('graph x <-> ply mapping', () {
    // The widget maps ply -> x as (ply + 1) and back as (x - 1), where
    // ply == -1 is the start position at x == 0.
    int plyToX(int ply) => ply + 1;
    int xToPly(int x) => x - 1;

    test('start position (ply -1) maps to x 0', () {
      expect(plyToX(-1), equals(0));
      expect(xToPly(0), equals(-1));
    });

    test('round-trips for every ply of a 3-ply game', () {
      for (int ply = -1; ply < 3; ply++) {
        expect(xToPly(plyToX(ply)), equals(ply));
      }
    });

    test('last ply maps to the last series index', () {
      const plies = 3;
      final seriesLength = plies + 1;
      expect(plyToX(plies - 1), equals(seriesLength - 1));
    });
  });
}
