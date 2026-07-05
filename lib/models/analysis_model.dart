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

/// Model for move analysis data
class MoveAnalysis {
  final int moveIndex;
  final String san; // Standard Algebraic Notation
  final String fen; // Position after the move
  final double evalBefore; // Evaluation before the move (white-relative)
  final double evalAfter; // Evaluation after the move (white-relative)
  final String? bestMove; // Best move in this position (UCI format)
  final String? bestMoveSan; // Best move in SAN format
  final MoveClassification classification;
  final List<EngineLine> engineLines;
  final bool isWhiteMove;
  final double centipawnLoss; // CPL for this move
  final double accuracy; // Per-move accuracy 0.0–100.0

  const MoveAnalysis({
    required this.moveIndex,
    required this.san,
    required this.fen,
    required this.evalBefore,
    required this.evalAfter,
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
  });

  factory GameAnalysis.empty() {
    return const GameAnalysis(moves: [], averageAccuracy: 0.0);
  }

  /// Calculate accuracy from moves using CPL-based model.
  /// Uses per-move accuracy derived from centipawn loss rather than
  /// fixed per-classification scores.
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
    double totalAccuracy = 0;
    double totalCpl = 0;

    for (final move in moves) {
      totalAccuracy += move.accuracy;
      totalCpl += move.centipawnLoss;

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
    return GameAnalysis(
      moves: moves,
      averageAccuracy: totalAccuracy / count,
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
    );
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
    // If eval goes from non-mate to mate for the player's side, it's a blunder.
    // If eval goes from mate to non-mate, it's excellent (escaped mate).
    final loss = computeCentipawnLoss(
      evalBefore: evalBefore,
      evalAfter: evalAfter,
      isWhiteMove: isWhiteMove,
    );
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

  // Significant improvement (opponent blundered or brilliant find)
  if (cpl <= EvalConstants.thresholdBrilliantCp) {
    return MoveClassification.excellent;
  }

  return EvalConstants.classifyCpl(cpl);
}
