import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';

/// Compute centipawn loss (CPL) from evaluation before and after a move.
/// Returns a positive value when the move was worse than the position before,
/// zero or negative when the move maintained or improved the position.
/// Units: centipawns (100 cp = 1 pawn).
double computeCentipawnLoss({
  required double evalBefore,
  required double evalAfter,
  required bool isWhiteMove,
}) {
  return EvalConstants.computeCpl(
    evalBefore: evalBefore,
    evalAfter: evalAfter,
    isWhiteMove: isWhiteMove,
  );
}

/// Compute accuracy percentage from centipawn loss.
/// Uses standard chess-platform formula: 100 × exp(-0.003 × CPL).
/// Returns 0.0–100.0.
double computeAccuracy({
  required double evalBefore,
  required double evalAfter,
  required bool isWhiteMove,
}) {
  final cpl = computeCentipawnLoss(
    evalBefore: evalBefore,
    evalAfter: evalAfter,
    isWhiteMove: isWhiteMove,
  );
  return EvalConstants.accuracyFromCpl(cpl);
}

/// Compute move accuracy using the Lichess Win%-based model.
/// This is more accurate than CPL-based because it accounts for the fact
/// that the same centipawn loss has different impact in different positions.
double computeWinPercentAccuracy({
  required double evalBeforePawns,
  required double evalAfterPawns,
  required bool isWhiteMove,
}) {
  final winBefore = EvalConstants.centipawnsToWinPercent(evalBeforePawns * 100);
  final winAfter = EvalConstants.centipawnsToWinPercent(evalAfterPawns * 100);

  double winDiff;
  if (isWhiteMove) {
    winDiff = winBefore - winAfter;
  } else {
    winDiff = (100 - winBefore) - (100 - winAfter);
  }

  return EvalConstants.accuracyFromWinPercentDiff(winDiff);
}

/// Model for move analysis data
class MoveAnalysis {
  final int moveIndex;
  final String san; // Standard Algebraic Notation
  final String fen; // Position after the move
  final double evalBefore; // Evaluation before the move (white-relative, pawns)
  final double evalAfter; // Evaluation after the move (white-relative, pawns)
  final double winPercentBefore; // Win% before the move (Lichess formula)
  final double winPercentAfter; // Win% after the move (Lichess formula)
  final String? bestMove; // Best move in this position (UCI format)
  final String? bestMoveSan; // Best move in SAN format
  final MoveClassification classification;
  final List<EngineLine> engineLines;
  final bool isWhiteMove;
  final double centipawnLoss; // CPL for this move
  final double accuracy; // Per-move accuracy 0.0–100.0 (Win%-based)

  const MoveAnalysis({
    required this.moveIndex,
    required this.san,
    required this.fen,
    required this.evalBefore,
    required this.evalAfter,
    this.winPercentBefore = 50.0,
    this.winPercentAfter = 50.0,
    this.bestMove,
    this.bestMoveSan,
    required this.classification,
    this.engineLines = const [],
    required this.isWhiteMove,
    required this.centipawnLoss,
    required this.accuracy,
  });

  /// Calculate evaluation loss (in pawns, positive = bad for player)
  double get evalLoss {
    if (isWhiteMove) {
      return evalBefore - evalAfter;
    } else {
      return evalAfter - evalBefore;
    }
  }

  /// Check if this was the best move
  bool get wasBestMove => classification == MoveClassification.best;
}

/// Game phase classification
enum GamePhase { opening, middlegame, endgame }

/// Full game analysis result
class GameAnalysis {
  final List<MoveAnalysis> moves;
  final double averageAccuracy;
  final double averageCpl;
  final int blunders;
  final int misses;
  final int mistakes;
  final int inaccuracies;
  final int goodMoves;
  final int greatMoves;
  final int excellentMoves;
  final int brilliantMoves;
  final int bestMoves;
  final int bookMoves;
  final double finalEval;
  final double openingAccuracy;
  final double middlegameAccuracy;
  final double endgameAccuracy;

  const GameAnalysis({
    required this.moves,
    required this.averageAccuracy,
    this.averageCpl = 0,
    this.blunders = 0,
    this.misses = 0,
    this.mistakes = 0,
    this.inaccuracies = 0,
    this.goodMoves = 0,
    this.greatMoves = 0,
    this.excellentMoves = 0,
    this.brilliantMoves = 0,
    this.bestMoves = 0,
    this.bookMoves = 0,
    this.finalEval = 0.0,
    this.openingAccuracy = 0.0,
    this.middlegameAccuracy = 0.0,
    this.endgameAccuracy = 0.0,
  });

  factory GameAnalysis.empty() {
    return const GameAnalysis(moves: [], averageAccuracy: 0.0);
  }

  factory GameAnalysis.fromMoves(List<MoveAnalysis> moves) {
    if (moves.isEmpty) return GameAnalysis.empty();

    int blunders = 0;
    int misses = 0;
    int mistakes = 0;
    int inaccuracies = 0;
    int goodMoves = 0;
    int greatMoves = 0;
    int excellentMoves = 0;
    int brilliantMoves = 0;
    int bestMoves = 0;
    int bookMoves = 0;
    double totalCpl = 0;

    final moveAccuracies = <double>[];
    final winPercents = <double>[];

    for (final move in moves) {
      totalCpl += move.centipawnLoss;
      moveAccuracies.add(move.accuracy);

      final playerWinPercent = move.isWhiteMove
          ? move.winPercentAfter
          : 100 - move.winPercentAfter;
      winPercents.add(playerWinPercent);

      switch (move.classification) {
        case MoveClassification.blunder:
          blunders++;
          break;
        case MoveClassification.miss:
          misses++;
          break;
        case MoveClassification.mistake:
          mistakes++;
          break;
        case MoveClassification.inaccuracy:
          inaccuracies++;
          break;
        case MoveClassification.good:
          goodMoves++;
          break;
        case MoveClassification.great:
          greatMoves++;
          break;
        case MoveClassification.excellent:
          excellentMoves++;
          break;
        case MoveClassification.brilliant:
          brilliantMoves++;
          break;
        case MoveClassification.best:
        case MoveClassification.forced:
        case MoveClassification.onlyMove:
          bestMoves++;
          break;
        case MoveClassification.book:
          bookMoves++;
          break;
      }
    }

    final count = moves.length;
    final winBasedAccuracy = EvalConstants.gameAccuracy(moveAccuracies, winPercents);

    final openingMoves = <MoveAnalysis>[];
    final middleMoves = <MoveAnalysis>[];
    final endMoves = <MoveAnalysis>[];

    for (int i = 0; i < moves.length; i++) {
      final phase = _phaseForMove(i, moves.length);
      switch (phase) {
        case GamePhase.opening:
          openingMoves.add(moves[i]);
          break;
        case GamePhase.middlegame:
          middleMoves.add(moves[i]);
          break;
        case GamePhase.endgame:
          endMoves.add(moves[i]);
          break;
      }
    }

    return GameAnalysis(
      moves: moves,
      averageAccuracy: winBasedAccuracy,
      averageCpl: totalCpl / count,
      blunders: blunders,
      misses: misses,
      mistakes: mistakes,
      inaccuracies: inaccuracies,
      goodMoves: goodMoves,
      greatMoves: greatMoves,
      excellentMoves: excellentMoves,
      brilliantMoves: brilliantMoves,
      bestMoves: bestMoves,
      bookMoves: bookMoves,
      finalEval: moves.isNotEmpty ? moves.last.evalAfter : 0.0,
      openingAccuracy: openingMoves.isEmpty ? 0.0 :
        openingMoves.map((m) => m.accuracy).reduce((a, b) => a + b) / openingMoves.length,
      middlegameAccuracy: middleMoves.isEmpty ? 0.0 :
        middleMoves.map((m) => m.accuracy).reduce((a, b) => a + b) / middleMoves.length,
      endgameAccuracy: endMoves.isEmpty ? 0.0 :
        endMoves.map((m) => m.accuracy).reduce((a, b) => a + b) / endMoves.length,
    );
  }

  static GamePhase _phaseForMove(int moveIndex, int totalMoves) {
    if (totalMoves <= 10) return GamePhase.opening;
    if (moveIndex < totalMoves * 0.15) return GamePhase.opening;
    if (moveIndex > totalMoves * 0.75) return GamePhase.endgame;
    return GamePhase.middlegame;
  }

  /// Get all evaluations for graphing
  List<double> get evaluations {
    if (moves.isEmpty) return [0.0];
    List<double> evals = [moves.first.evalBefore];
    for (final move in moves) {
      evals.add(move.evalAfter);
    }
    return evals;
  }
}

/// Classify a move based on evaluation change, best move comparison, and mate/draw context.
///
/// Evaluation is always white-relative (positive = good for white).
///
/// Classification thresholds are defined in [EvalConstants] (in centipawns):
///   - CPL ≤ 5 cp: Best
///   - CPL ≤ 20 cp: Excellent
///   - CPL ≤ 50 cp: Good
///   - CPL ≤ 100 cp: Inaccuracy
///   - CPL ≤ 200 cp: Mistake
///   - CPL > 200 cp: Blunder
///
/// Improvement (CPL < 0 by more than 50cp): Excellent
/// Mate scores (abs > 1000) are handled separately.
MoveClassification classifyMove({
  required double evalBefore,
  required double evalAfter,
  required bool isWhiteMove,
  required String? bestMove,
  required String actualMove,
}) {
  // ── Mate handling ──
  final isMateScore =
      evalBefore.abs() > EvalConstants.mateThreshold ||
      evalAfter.abs() > EvalConstants.mateThreshold;

  if (isMateScore) {
    if (bestMove != null &&
        actualMove.toLowerCase() == bestMove.toLowerCase()) {
      return MoveClassification.best;
    }
    final loss = computeCentipawnLoss(
      evalBefore: evalBefore,
      evalAfter: evalAfter,
      isWhiteMove: isWhiteMove,
    );

    // Check for missed mate
    bool hadMate =
        (isWhiteMove ? evalBefore : -evalBefore) > EvalConstants.mateThreshold;
    bool lostMate =
        (isWhiteMove ? evalAfter : -evalAfter) < EvalConstants.mateThreshold;

    if (hadMate && lostMate) {
      return MoveClassification.miss;
    }

    if (loss >= EvalConstants.thresholdBlunderCp) {
      return MoveClassification.blunder;
    }
    if (loss <= EvalConstants.thresholdBrilliantCp) {
      return MoveClassification.excellent;
    }
    return MoveClassification.best;
  }

  // ── Best move match ──
  if (bestMove != null && actualMove.toLowerCase() == bestMove.toLowerCase()) {
    return MoveClassification.best;
  }

  // ── CPL-based classification ──
  final cpl = computeCentipawnLoss(
    evalBefore: evalBefore,
    evalAfter: evalAfter,
    isWhiteMove: isWhiteMove,
  );

  // Missed Win / Miss
  // If we had a significant advantage (>3 pawns) and lost a lot of it (loss > 200cp)
  // but it's not a blunder because we might still be equal or winning, it's a "Miss".
  // Actually, standard miss is losing an advantage > 3.0 down to < 1.0 or similar.
  // We approximate: if we were winning (eval > 3 pawns) and CPL > 200.
  double playerEvalBefore = isWhiteMove ? evalBefore : -evalBefore;
  if (playerEvalBefore >= 3.0 && cpl >= 200) {
    return MoveClassification.miss;
  }

  // Significant improvement (opponent blundered or brilliant find)
  // We can classify it as brilliant if it involved a sacrifice, but without a full engine
  // tree we just use CPL < -50 as a placeholder for Great/Brilliant
  if (cpl <= -100) {
    return MoveClassification.brilliant; // Large improvement
  }
  if (cpl <= EvalConstants.thresholdBrilliantCp) {
    return MoveClassification.great;
  }

  return EvalConstants.classifyCpl(cpl);
}
