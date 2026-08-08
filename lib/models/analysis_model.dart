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
  /// Engine BEST-move evaluation for the position before this move
  /// (white-relative, pawns). This is the counterfactual "what the position was
  /// worth with perfect play" value and is the CPL baseline — it is NOT the
  /// evaluation of the position that was actually reached. Use
  /// [actualEvalBeforeMove] for graphs and before/after display.
  final double evalBefore;
  final double evalAfter; // Evaluation after the move (white-relative, pawns)

  /// Evaluation of the position ACTUALLY reached before this move was played,
  /// i.e. [evalAfter] of the previous ply (white-relative, pawns). For the
  /// first ply this equals [evalBefore]. Used for the eval graph and the
  /// before/after series so they follow the real game, not the best line.
  final double actualEvalBeforeMove;
  final double winPercentBefore; // Win% before the move (Lichess formula)
  final double winPercentAfter; // Win% after the move (Lichess formula)
  final String? bestMove; // Best move in this position (UCI format)
  final String? bestMoveSan; // Best move in SAN format
  final MoveClassification classification;
  final List<EngineLine> engineLines;
  final bool isWhiteMove;
  final double centipawnLoss; // CPL for this move
  final double accuracy; // Per-move accuracy 0.0–100.0 (Win%-based)
  final bool isMateBefore; // True if evalBefore represents a forced mate
  final bool isMateAfter; // True if evalAfter represents a forced mate

  const MoveAnalysis({
    required this.moveIndex,
    required this.san,
    required this.fen,
    required this.evalBefore,
    required this.evalAfter,
    double? actualEvalBeforeMove,
    this.winPercentBefore = 50.0,
    this.winPercentAfter = 50.0,
    this.bestMove,
    this.bestMoveSan,
    required this.classification,
    this.engineLines = const [],
    required this.isWhiteMove,
    required this.centipawnLoss,
    required this.accuracy,
    this.isMateBefore = false,
    this.isMateAfter = false,
  }) : actualEvalBeforeMove = actualEvalBeforeMove ?? evalBefore;

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

  /// Get all evaluations for graphing.
  ///
  /// Index i == the position after i plies, so index 0 is the starting position
  /// and index n is the position after move n. This uses the ACTUALLY reached
  /// evaluations (`actualEvalBeforeMove` for the start, then each `evalAfter`)
  /// rather than the counterfactual best-line `evalBefore`, so the curve
  /// follows the real game and is continuous between plies.
  List<double> get evaluations {
    if (moves.isEmpty) return [0.0];
    List<double> evals = [moves.first.actualEvalBeforeMove];
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
/// [isMateBefore]/[isMateAfter] indicate whether the position is a forced mate
/// (Stockfish reported "score mate N" without "score cp"). Mate positions are
/// classified separately using mate-specific logic.
MoveClassification classifyMove({
  required double evalBefore,
  required double evalAfter,
  required bool isWhiteMove,
  required String? bestMove,
  required String actualMove,
  bool isMateBefore = false,
  bool isMateAfter = false,
}) {
  // Convert evaluation pawns to centipawns
  final cpBefore = evalBefore * 100.0;
  final cpAfter = evalAfter * 100.0;

  // Lichess Win% for player making the move
  final winBeforeRaw = EvalConstants.centipawnsToWinPercent(cpBefore);
  final winAfterRaw = EvalConstants.centipawnsToWinPercent(cpAfter);

  final playerWinBefore = isWhiteMove ? winBeforeRaw : (100.0 - winBeforeRaw);
  final playerWinAfter = isWhiteMove ? winAfterRaw : (100.0 - winAfterRaw);

  // Win probability loss (0.0 to 100.0 %)
  final rawWinDiff = playerWinBefore - playerWinAfter;
  final winDiff = rawWinDiff < 0 ? 0.0 : rawWinDiff;

  // ── Mate handling ──
  if (isMateBefore || isMateAfter) {
    if (bestMove != null &&
        actualMove.toLowerCase() == bestMove.toLowerCase()) {
      return MoveClassification.best;
    }

    final hadMate = isMateBefore && (isWhiteMove ? evalBefore > 0 : evalBefore < 0);
    final lostMate = isMateAfter && (isWhiteMove ? evalAfter < 0 : evalAfter > 0);

    if (hadMate && lostMate) {
      return MoveClassification.miss;
    }

    if (winDiff >= 25.0) {
      return MoveClassification.blunder;
    }
    return MoveClassification.best;
  }

  // ── Best move match ──
  final isBestMoveMatch = bestMove != null &&
      actualMove.toLowerCase() == bestMove.toLowerCase();

  if (isBestMoveMatch) {
    return MoveClassification.best;
  }

  // Missed Win / Miss (had >3.0 pawns advantage and lost >25% win prob)
  if (playerWinBefore >= 80.0 && winDiff >= 25.0) {
    return MoveClassification.miss;
  }

  // ── Lichess Win-Probability Loss Thresholds ──
  // Tightened from original (1/4/8/15/25) to produce meaningful distribution.
  // These match Lichess's classification boundaries.
  if (winDiff <= 2.0) {
    return MoveClassification.best;
  } else if (winDiff <= 5.0) {
    return MoveClassification.excellent;
  } else if (winDiff <= 10.0) {
    return MoveClassification.good;
  } else if (winDiff <= 20.0) {
    return MoveClassification.inaccuracy;
  } else if (winDiff <= 40.0) {
    return MoveClassification.mistake;
  } else {
    return MoveClassification.blunder;
  }
}

/// Maximum CPL a move may cost and still qualify as Brilliant or Great.
/// Both labels describe moves that hold the evaluation, so this stays tight.
const double brilliantGreatMaxCpl = 20.0;

/// Minimum material (in centipawns, negative) the static exchange evaluation
/// must show for a sound move to count as a sacrifice. -100 is a clean pawn.
const double brilliantMinSacrificeCp = -100.0;

/// How much worse the engine's second-best line must be for the played move to
/// count as the only good move (Great).
const double greatOnlyMoveMarginCp = 30.0;

/// Minimum player Win% before the move for a Miss to be possible.
const double missMinWinPercentBefore = 80.0;

/// Minimum Win% drop for a winning position to count as a Miss.
const double missMinWinPercentDrop = 25.0;

/// Classify a move based on centipawn loss (CPL) relative to the engine's best move.
/// This is how Lichess and Chess.com classify moves — by comparing the evaluation
/// of the player's move against the evaluation of the engine's best move from the
/// same position.
///
/// [centipawnLoss] is always positive (or zero) and represents how many centipawns
/// worse the player's move was compared to the best move.
///
/// Thresholds (aligned with Lichess/Chess.com):
///   - CPL ≤ 10 cp: Best
///   - CPL ≤ 20 cp: Excellent
///   - CPL ≤ 50 cp: Good
///   - CPL ≤ 100 cp: Inaccuracy
///   - CPL ≤ 200 cp: Mistake
///   - CPL > 200 cp: Blunder
///
/// Optional signals refine a sound move (CPL ≤ [brilliantGreatMaxCpl]) into
/// Brilliant or Great, and let a non-mate move be flagged as a Miss:
///   - [seeCentipawns]: static exchange evaluation of the played move. A
///     negative value means material was given up; combined with a low CPL
///     that is a sound sacrifice → Brilliant.
///   - [secondBestCentipawnLoss]: how much worse the engine's SECOND line is
///     than its best. When the next-best alternative is materially worse the
///     move played was effectively the only good one → Great.
///   - [playerWinPercentBefore]/[winPercentDiff]: a winning position that was
///     substantially thrown away → Miss (mirrors the Win%-based rule).
MoveClassification classifyMoveCpl({
  required double centipawnLoss,
  required String? bestMove,
  required String actualMove,
  bool isMateBefore = false,
  bool isMateAfter = false,
  double? seeCentipawns,
  double? secondBestCentipawnLoss,
  double? playerWinPercentBefore,
  double? winPercentDiff,
}) {
  // ── Mate handling ──
  if (isMateBefore || isMateAfter) {
    if (bestMove != null &&
        actualMove.toLowerCase() == bestMove.toLowerCase()) {
      return MoveClassification.best;
    }

    final hadMate = isMateBefore;
    final lostMate = isMateAfter;

    if (hadMate && lostMate) {
      return MoveClassification.miss;
    }

    if (centipawnLoss >= 200.0) {
      return MoveClassification.blunder;
    }
    return MoveClassification.best;
  }

  final isBestMoveMatch =
      bestMove != null && actualMove.toLowerCase() == bestMove.toLowerCase();

  // ── Brilliant: a sound sacrifice ──
  // Material is given up by static exchange, yet the evaluation barely moves,
  // so the sacrifice is justified by the resulting position.
  if (centipawnLoss <= brilliantGreatMaxCpl &&
      seeCentipawns != null &&
      seeCentipawns <= brilliantMinSacrificeCp) {
    return MoveClassification.brilliant;
  }

  // ── Great: effectively the only good move ──
  // The move holds the evaluation while every other engine line is clearly
  // worse, i.e. there was no comparable alternative.
  if (centipawnLoss <= brilliantGreatMaxCpl &&
      secondBestCentipawnLoss != null &&
      secondBestCentipawnLoss >= greatOnlyMoveMarginCp) {
    return MoveClassification.great;
  }

  // ── Best move match ──
  if (isBestMoveMatch) {
    return MoveClassification.best;
  }

  // ── Miss: a winning position substantially thrown away ──
  if (playerWinPercentBefore != null &&
      winPercentDiff != null &&
      playerWinPercentBefore >= missMinWinPercentBefore &&
      winPercentDiff >= missMinWinPercentDrop) {
    return MoveClassification.miss;
  }

  // ── CPL Thresholds ──
  if (centipawnLoss <= 10.0) {
    return MoveClassification.best;
  } else if (centipawnLoss <= 20.0) {
    return MoveClassification.excellent;
  } else if (centipawnLoss <= 50.0) {
    return MoveClassification.good;
  } else if (centipawnLoss <= 100.0) {
    return MoveClassification.inaccuracy;
  } else if (centipawnLoss <= 200.0) {
    return MoveClassification.mistake;
  } else {
    return MoveClassification.blunder;
  }
}
