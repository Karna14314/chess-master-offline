import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/analysis_model.dart';

void main() {
  group('Analysis Configuration Constants', () {
    test(
      'batchAnalysisDepth is set to 14 for accurate tactical assessment',
      () {
        expect(AppConstants.batchAnalysisDepth, equals(14));
      },
    );

    test('batchAnalysisMultiPv is set to 2 for Great move detection', () {
      expect(AppConstants.batchAnalysisMultiPv, equals(2));
    });

    test('Opening pves are skipped for efficiency', () {
      expect(AppConstants.skipOpeningPlies, greaterThan(0));
    });
  });

  group('MoveClassification', () {
    test('book classification exists for opening book moves', () {
      expect(MoveClassification.book.name, equals('Book'));
    });
  });

  group('AnalysisModel', () {
    test('MoveAnalysis contains centipawnLoss as positive value', () {
      final move = MoveAnalysis(
        moveIndex: 0,
        san: 'e4',
        fen: 'start',
        evalBefore: 0.1,
        evalAfter: 0.05,
        actualEvalBeforeMove: 0.0,
        winPercentBefore: 50.0,
        winPercentAfter: 49.0,
        bestMove: 'e2e4',
        classification: MoveClassification.best,
        isWhiteMove: true,
        centipawnLoss: 5.0,
        accuracy: 99.0,
        isMateBefore: false,
        isMateAfter: false,
      );

      expect(move.centipawnLoss, equals(5.0));
      expect(move.bestMove, equals('e2e4'));
      expect(move.classification, equals(MoveClassification.best));
    });

    test('GameAnalysisAccumulator tracks book moves correctly', () {
      final accumulator = GameAnalysisAccumulator();

      accumulator.add(
        MoveAnalysis(
          moveIndex: 0,
          san: 'e4',
          fen: 'start',
          evalBefore: 0.0,
          evalAfter: 0.0,
          actualEvalBeforeMove: 0.0,
          winPercentBefore: 50.0,
          winPercentAfter: 50.0,
          bestMove: 'e2e4',
          classification: MoveClassification.book,
          isWhiteMove: true,
          centipawnLoss: 0.0,
          accuracy: 100.0,
          isMateBefore: false,
          isMateAfter: false,
        ),
      );

      expect(accumulator.length, equals(1));
      expect(
        accumulator.moves.first.classification,
        equals(MoveClassification.book),
      );
    });
  });
}
