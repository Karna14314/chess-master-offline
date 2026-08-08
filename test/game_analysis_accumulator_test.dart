import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/analysis_model.dart';

/// The incremental accumulator must be numerically identical to the full
/// recomputation — the perf pass may change speed, never displayed numbers.
void main() {
  MoveAnalysis move(int i, MoveClassification c, bool white, double acc,
      double cpl, double winAfter) {
    return MoveAnalysis(
      moveIndex: i,
      san: 'm$i',
      fen: '...',
      evalBefore: 0.1 * i,
      evalAfter: 0.1 * i + 0.05,
      winPercentAfter: winAfter,
      classification: c,
      isWhiteMove: white,
      centipawnLoss: cpl,
      accuracy: acc,
    );
  }

  List<MoveAnalysis> sampleGame(int plies) {
    const classes = [
      MoveClassification.best,
      MoveClassification.excellent,
      MoveClassification.good,
      MoveClassification.inaccuracy,
      MoveClassification.mistake,
      MoveClassification.blunder,
      MoveClassification.great,
      MoveClassification.brilliant,
      MoveClassification.miss,
      MoveClassification.book,
    ];
    return List.generate(plies, (i) {
      return move(
        i,
        classes[i % classes.length],
        i.isEven,
        100.0 - (i % 40),
        (i * 7) % 300,
        50.0 + ((i * 13) % 50) - 25,
      );
    });
  }

  void expectSame(GameAnalysis a, GameAnalysis b, String reason) {
    expect(a.averageAccuracy, closeTo(b.averageAccuracy, 1e-9), reason: reason);
    expect(a.averageCpl, closeTo(b.averageCpl, 1e-9), reason: reason);
    expect(a.whiteAccuracy, closeTo(b.whiteAccuracy, 1e-9), reason: reason);
    expect(a.blackAccuracy, closeTo(b.blackAccuracy, 1e-9), reason: reason);
    expect(a.openingAccuracy, closeTo(b.openingAccuracy, 1e-9), reason: reason);
    expect(a.middlegameAccuracy, closeTo(b.middlegameAccuracy, 1e-9),
        reason: reason);
    expect(a.endgameAccuracy, closeTo(b.endgameAccuracy, 1e-9), reason: reason);
    expect(a.finalEval, closeTo(b.finalEval, 1e-9), reason: reason);
    expect(a.blunders, b.blunders, reason: reason);
    expect(a.misses, b.misses, reason: reason);
    expect(a.mistakes, b.mistakes, reason: reason);
    expect(a.inaccuracies, b.inaccuracies, reason: reason);
    expect(a.goodMoves, b.goodMoves, reason: reason);
    expect(a.greatMoves, b.greatMoves, reason: reason);
    expect(a.excellentMoves, b.excellentMoves, reason: reason);
    expect(a.brilliantMoves, b.brilliantMoves, reason: reason);
    expect(a.bestMoves, b.bestMoves, reason: reason);
    expect(a.bookMoves, b.bookMoves, reason: reason);
    expect(a.moves.length, b.moves.length, reason: reason);
  }

  test('empty accumulator matches empty analysis', () {
    final acc = GameAnalysisAccumulator();
    expectSame(acc.build(), GameAnalysis.fromMoves([]), 'empty');
  });

  test('accumulator matches fromMoves at every prefix length', () {
    final game = sampleGame(40);
    final acc = GameAnalysisAccumulator();

    for (int i = 0; i < game.length; i++) {
      acc.add(game[i]);
      final prefix = game.sublist(0, i + 1);
      expectSame(acc.build(), GameAnalysis.fromMoves(prefix), 'prefix ${i + 1}');
    }
  });

  test('matches for a short game (phase boundaries collapse to opening)', () {
    final game = sampleGame(6);
    final acc = GameAnalysisAccumulator();
    for (final m in game) {
      acc.add(m);
    }
    expectSame(acc.build(), GameAnalysis.fromMoves(game), '6 plies');
  });

  test('matches for a long game', () {
    final game = sampleGame(120);
    final acc = GameAnalysisAccumulator();
    for (final m in game) {
      acc.add(m);
    }
    expectSame(acc.build(), GameAnalysis.fromMoves(game), '120 plies');
  });

  test('single white ply leaves black accuracy at zero', () {
    final acc = GameAnalysisAccumulator()
      ..add(move(0, MoveClassification.best, true, 90, 0, 55));
    final built = acc.build();
    expectSame(built, GameAnalysis.fromMoves(acc.moves), 'single ply');
    expect(built.blackAccuracy, 0.0);
  });

  test('evaluations series is preserved through the accumulator', () {
    final game = sampleGame(10);
    final acc = GameAnalysisAccumulator();
    for (final m in game) {
      acc.add(m);
    }
    expect(acc.build().evaluations, GameAnalysis.fromMoves(game).evaluations);
  });
}
