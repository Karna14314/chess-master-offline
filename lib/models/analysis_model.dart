import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';

/// Model for move analysis data
class MoveAnalysis {
  final int moveIndex;
  final String san; // Standard Algebraic Notation
  final String fen; // Position after the move
  final double evalBefore; // Evaluation before the move
  final double evalAfter; // Evaluation after the move
  final String? bestMove; // Best move in this position (UCI format)
  final String? bestMoveSan; // Best move in SAN format
  final MoveClassification classification;
  final List<EngineLine> engineLines;
  final bool isWhiteMove;

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
  });

  /// Calculate evaluation loss
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
  final int blunders;
  final int mistakes;
  final int inaccuracies;
  final int excellentMoves;
  final int bookMoves;
  final double finalEval;

  const GameAnalysis({
    required this.moves,
    required this.averageAccuracy,
    this.blunders = 0,
    this.mistakes = 0,
    this.inaccuracies = 0,
    this.excellentMoves = 0,
    this.bookMoves = 0,
    this.finalEval = 0.0,
  });

  factory GameAnalysis.empty() {
    return const GameAnalysis(moves: [], averageAccuracy: 0.0);
  }

  /// Calculate accuracy from moves
  factory GameAnalysis.fromMoves(List<MoveAnalysis> moves) {
    if (moves.isEmpty) return GameAnalysis.empty();

    int blunders = 0;
    int mistakes = 0;
    int inaccuracies = 0;
    int excellentMoves = 0;
    int bookMoves = 0;
    double totalAccuracy = 0;

    for (final move in moves) {
      switch (move.classification) {
        case MoveClassification.blunder:
          blunders++;
          totalAccuracy += 20;
          break;
        case MoveClassification.mistake:
          mistakes++;
          totalAccuracy += 50;
          break;
        case MoveClassification.inaccuracy:
          inaccuracies++;
          totalAccuracy += 75;
          break;
        case MoveClassification.good:
          totalAccuracy += 90;
          break;
        case MoveClassification.excellent:
        case MoveClassification.brilliant:
          excellentMoves++;
          totalAccuracy += 100;
          break;
        case MoveClassification.best:
          excellentMoves++;
          totalAccuracy += 100;
          break;
        case MoveClassification.book:
          bookMoves++;
          totalAccuracy += 100;
          break;
      }
    }

    return GameAnalysis(
      moves: moves,
      averageAccuracy: moves.isNotEmpty ? totalAccuracy / moves.length : 0,
      blunders: blunders,
      mistakes: mistakes,
      inaccuracies: inaccuracies,
      excellentMoves: excellentMoves,
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

/// Helper to classify moves based on eval change
MoveClassification classifyMove({
  required double evalBefore,
  required double evalAfter,
  required bool isWhiteMove,
  required String? bestMove,
  required String actualMove,
}) {
  // If it was the best move
  if (bestMove != null && actualMove.toLowerCase() == bestMove.toLowerCase()) {
    return MoveClassification.best;
  }

  // Calculate eval loss from player's perspective
  double evalLoss;
  if (isWhiteMove) {
    evalLoss = evalBefore - evalAfter;
  } else {
    evalLoss = evalAfter - evalBefore;
  }

  // Classify based on centipawn loss
  // Positive evalLoss means the move was worse than optimal
  if (evalLoss >= 3.0) {
    return MoveClassification.blunder;
  } else if (evalLoss >= 1.5) {
    return MoveClassification.mistake;
  } else if (evalLoss >= 0.5) {
    return MoveClassification.inaccuracy;
  } else if (evalLoss <= -0.3) {
    // Move was better than expected (opponent blundered or brilliant find)
    return MoveClassification.excellent;
  } else {
    return MoveClassification.good;
  }
}
