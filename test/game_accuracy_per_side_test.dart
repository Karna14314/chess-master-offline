import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/analysis_model.dart';

/// Tests for the per-side accuracy fields surfaced by the Report tab header.
void main() {
  MoveAnalysis move({
    required int index,
    required bool isWhiteMove,
    required double accuracy,
    double winPercentAfter = 50.0,
    MoveClassification classification = MoveClassification.best,
  }) {
    return MoveAnalysis(
      moveIndex: index,
      san: 'm$index',
      fen: '...',
      evalBefore: 0.0,
      evalAfter: 0.0,
      winPercentAfter: winPercentAfter,
      classification: classification,
      isWhiteMove: isWhiteMove,
      centipawnLoss: 0,
      accuracy: accuracy,
    );
  }

  test('empty analysis reports zero for both sides', () {
    final ga = GameAnalysis.fromMoves([]);
    expect(ga.whiteAccuracy, equals(0.0));
    expect(ga.blackAccuracy, equals(0.0));
  });

  test('a side with no moves reports zero', () {
    final ga = GameAnalysis.fromMoves([
      move(index: 0, isWhiteMove: true, accuracy: 90),
    ]);
    expect(ga.whiteAccuracy, greaterThan(0));
    expect(ga.blackAccuracy, equals(0.0));
  });

  test('sides are scored independently', () {
    // White plays accurately, black poorly.
    final ga = GameAnalysis.fromMoves([
      move(index: 0, isWhiteMove: true, accuracy: 99),
      move(index: 1, isWhiteMove: false, accuracy: 40),
      move(index: 2, isWhiteMove: true, accuracy: 97),
      move(index: 3, isWhiteMove: false, accuracy: 35),
    ]);

    expect(ga.whiteAccuracy, greaterThan(ga.blackAccuracy));
    expect(ga.whiteAccuracy, greaterThan(90));
    expect(ga.blackAccuracy, lessThan(60));
  });

  test('per-side values stay within 0-100', () {
    final ga = GameAnalysis.fromMoves([
      move(index: 0, isWhiteMove: true, accuracy: 100),
      move(index: 1, isWhiteMove: false, accuracy: 0),
    ]);

    expect(ga.whiteAccuracy, inInclusiveRange(0, 100));
    expect(ga.blackAccuracy, inInclusiveRange(0, 100));
  });

  test('single-side game matches that side only', () {
    final ga = GameAnalysis.fromMoves([
      move(index: 0, isWhiteMove: true, accuracy: 88),
    ]);
    expect(ga.whiteAccuracy, closeTo(88, 0.001));
  });
}
