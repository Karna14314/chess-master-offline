/// Unified chess models for the application
library chess_models;

/// Engine line for analysis
class EngineLine {
  final int rank; // 1, 2, 3 for multipv
  final double evaluation; // Evaluation in pawns
  final int depth;
  final List<String> moves; // UCI format moves
  final List<String>? sanMoves; // SAN format moves
  final bool isMate;
  final int? mateIn;

  const EngineLine({
    required this.rank,
    required this.evaluation,
    required this.depth,
    required this.moves,
    this.sanMoves,
    this.isMate = false,
    this.mateIn,
  });

  /// Get display string for evaluation
  String get evalDisplay {
    if (isMate && mateIn != null) {
      return mateIn! > 0 ? 'M$mateIn' : '-M${mateIn!.abs()}';
    }
    final sign = evaluation >= 0 ? '+' : '';
    return '$sign${evaluation.toStringAsFixed(2)}';
  }

  /// Get formatted evaluation string (alias for evalDisplay to match some usages)
  String get formattedEval => evalDisplay;

  /// Get first few moves as a string
  String getMovePreview({int count = 5}) {
    final movesToShow = sanMoves ?? moves;
    if (movesToShow.isEmpty) return '';
    return movesToShow.take(count).join(' ');
  }

  /// Get evaluation in pawns (compatibility helper)
  double get evalInPawns => evaluation;
}

/// Result of a best move search
class BestMoveResult {
  final String bestMove;
  final String? ponderMove;
  final int? evaluation; // In centipawns
  final int? mateIn;

  BestMoveResult({
    required this.bestMove,
    this.ponderMove,
    this.evaluation,
    this.mateIn,
  });

  /// Parse UCI move format (e.g., "e2e4") to from/to squares
  (String from, String to, String? promotion) get parsedMove {
    if (bestMove.length < 4) return ('', '', null);

    final from = bestMove.substring(0, 2);
    final to = bestMove.substring(2, 4);
    final promotion = bestMove.length > 4 ? bestMove.substring(4, 5) : null;

    return (from, to, promotion);
  }

  bool get isValid => bestMove.isNotEmpty && bestMove.length >= 4;
}

/// Result of position analysis
class AnalysisResult {
  final int evaluation; // In centipawns
  final int? mateIn;
  final List<EngineLine> lines;
  final int depth;

  AnalysisResult({
    required this.evaluation,
    this.mateIn,
    required this.lines,
    required this.depth,
  });

  /// Get evaluation in pawns (centipawns / 100)
  double get evalInPawns => evaluation / 100.0;

  /// Get formatted evaluation string
  String get formattedEval {
    if (mateIn != null) {
      return mateIn! > 0 ? 'M$mateIn' : '-M${mateIn!.abs()}';
    }
    final sign = evaluation >= 0 ? '+' : '';
    return '$sign${evalInPawns.toStringAsFixed(1)}';
  }
}

/// Engine status enum
enum EngineStatus { initializing, ready, failed, usingFallback, disposed }
