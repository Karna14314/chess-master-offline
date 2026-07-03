import 'dart:isolate';
import 'dart:math';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/services/position_evaluator.dart';

/// Lightweight chess bot using negamax with alpha-beta pruning,
/// iterative deepening, and principal variation tracking.
/// Designed to be fast and memory-efficient (~1MB).
class SimpleBotService {
  static SimpleBotService? _instance;

  static SimpleBotService get instance {
    _instance ??= SimpleBotService._();
    return _instance!;
  }

  SimpleBotService._();

  static int _cancelToken = 0;

  /// Cancel any ongoing search. All active `getBestMove` calls will
  /// return the best result found so far from the completed iterations.
  static void cancelSearch() {
    _cancelToken++;
  }

  // Piece values (centipawns)
  static const int pawnValue = 100;
  static const int knightValue = 320;
  static const int bishopValue = 330;
  static const int rookValue = 500;
  static const int queenValue = 900;
  static const int kingValue = 20000;

  /// Get best move for the current position
  /// [fen] - Position in FEN notation
  /// [depth] - Search depth (1-4 recommended for fallback engine)
  Future<SimpleBotResult> getBestMove({
    required String fen,
    int depth = 3,
  }) async {
    final effectiveDepth = min(depth, 3);
    final cancelId = _cancelToken;

    return Isolate.run(() => _getBestMoveSync(fen, effectiveDepth, cancelId));
  }

  /// Synchronous computation — runs inside an isolate.
  /// Uses iterative deepening with negamax alpha-beta and PV tracking.
  SimpleBotResult _getBestMoveSync(
    String fen,
    int depth,
    int cancelId,
  ) {
    final board = chess.Chess.fromFEN(fen);

    // Terminal condition checks BEFORE move generation for empty results.
    if (board.in_checkmate) {
      // The side to move is checkmated. In pure negamax, the checkmated
      // side gets a very negative score: -(999999 - depth) = -999999 + depth.
      // Convert to white-relative for the public API:
      //   Black checkmated → +999999 - depth (very positive for white)
      //   White checkmated → -999999 + depth (very negative for white)
      final sideToMoveScore = -999999 + depth;
      final adjustedEval = board.turn == chess.Color.BLACK
          ? -sideToMoveScore
          : sideToMoveScore;
      return SimpleBotResult(bestMove: '', evaluation: adjustedEval);
    }
    if (board.in_stalemate || board.in_draw) {
      return SimpleBotResult(bestMove: '', evaluation: 0);
    }

    final moves = board.moves({'verbose': true});
    if (moves.isEmpty) {
      return SimpleBotResult(bestMove: '', evaluation: 0);
    }

    // At depth 0 or 1, pick the best single-ply move
    if (depth <= 0) {
      final singlePlyResult = _pickBestSinglePly(board, moves);
      // Convert to white-relative
      final adjustedEval = board.turn == chess.Color.WHITE
          ? singlePlyResult.evaluation
          : -singlePlyResult.evaluation;
      return SimpleBotResult(
        bestMove: singlePlyResult.bestMove,
        evaluation: adjustedEval,
        principalVariation: singlePlyResult.principalVariation,
      );
    }

    // --- Iterative Deepening ---
    String bestMove = moves.isNotEmpty ? _moveToStr(moves[0] as Map) : '';
    int bestEval = 0;
    List<String> bestPv = [];
    final isWhiteToMove = board.turn == chess.Color.WHITE;

    for (int idDepth = 1; idDepth <= depth; idDepth++) {
      if (_cancelToken != cancelId) break;

      final rootResult = _searchRoot(board, idDepth);

      if (_cancelToken != cancelId) break;

      bestMove = rootResult.bestMove;
      bestEval = rootResult.eval;
      bestPv = rootResult.pv;
    }

    // _searchRoot and _pickBestSinglePly return scores from the
    // current side-to-move's perspective. SimpleBotResult.evaluation
    // must be white-relative (positive = good for white).
    if (!isWhiteToMove && depth > 0) bestEval = -bestEval;

    return SimpleBotResult(
      bestMove: bestMove,
      evaluation: bestEval,
      principalVariation: bestPv,
    );
  }

  /// Evaluate each move at depth 1 and return the best.
  /// Evaluation is returned from the current side-to-move's perspective.
  SimpleBotResult _pickBestSinglePly(chess.Chess board, List moves) {
    String bestMove = '';
    final isWhiteToMove = board.turn == chess.Color.WHITE;
    int bestEval = -999999;

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      // After the move, it's the opponent's turn. _evaluatePosition returns
      // white-relative scores. Convert to the ORIGINAL side's perspective.
      final rawEval = _evaluatePosition(board);
      board.undo();

      // Convert to the perspective of the player who made the move:
      //   White moving  → wants high white-relative score
      //   Black moving  → wants low white-relative score  (= negated)
      final eval = isWhiteToMove ? rawEval : -rawEval;

      if (eval > bestEval) {
        bestEval = eval;
        bestMove = _moveToStr(m);
      }
    }

    return SimpleBotResult(bestMove: bestMove, evaluation: bestEval);
  }

  /// Root search — tries each root move and calls negamax for deeper search.
  /// Returns best move, evaluation, and principal variation.
  ({String bestMove, int eval, List<String> pv}) _searchRoot(
    chess.Chess board,
    int depth,
  ) {
    final moves = board.moves({'verbose': true});
    _sortMoves(moves, null);

    String bestMove = '';
    int bestEval = -999999;
    List<String> bestPv = [];

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      final result = _negamax(board, depth - 1, -999999, 999999);
      board.undo();

      // result.score is from opponent's perspective; negate for ours
      final eval = -result.score;

      if (eval > bestEval) {
        bestEval = eval;
        bestMove = _moveToStr(m);
        bestPv = [bestMove, ...result.pv];
      }
    }

    return (bestMove: bestMove, eval: bestEval, pv: bestPv);
  }

  /// Pure negamax with alpha-beta pruning. Returns score from current
  /// side-to-move's perspective plus principal variation.
  ({int score, List<String> pv}) _negamax(
    chess.Chess board,
    int depth,
    int alpha,
    int beta,
  ) {
    if (depth == 0) {
      // _evaluatePosition returns white-relative scores. Pure negamax requires
      // scores from the side-to-move's perspective, so we flip for black.
      int eval = _evaluatePosition(board);
      if (board.turn == chess.Color.BLACK) eval = -eval;
      return (score: eval, pv: const []);
    }

    if (board.in_checkmate) {
      // Current side is checkmated — terrible; prefer sooner mates
      return (score: -999999 + depth, pv: const []);
    }

    if (board.in_stalemate || board.in_draw) {
      return (score: 0, pv: const []);
    }

    final moves = board.moves({'verbose': true});
    if (moves.isEmpty) return (score: 0, pv: const []);

    _sortMoves(moves, null);

    int bestScore = alpha;
    List<String> bestPv = const [];

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      final result = _negamax(board, depth - 1, -beta, -bestScore);
      board.undo();

      final score = -result.score;

      if (score >= beta) {
        return (score: beta, pv: const []); // Prune
      }

      if (score > bestScore) {
        bestScore = score;
        bestPv = [_moveToStr(m), ...result.pv];
      }
    }

    return (score: bestScore, pv: bestPv);
  }

  /// Convert a verbose move map to UCI string (e.g., "e2e4", "a7a8q").
  String _moveToStr(Map m) {
    return '${m['from']}${m['to']}${m['promotion'] ?? ''}';
  }

  /// Simple move ordering: captures before non-captures.
  void _sortMoves(List moves, String? prioritizeMove) {
    moves.sort((a, b) {
      final mapA = a as Map;
      final mapB = b as Map;
      if (mapA['captured'] != null && mapB['captured'] == null) return -1;
      if (mapA['captured'] == null && mapB['captured'] != null) return 1;
      return 0;
    });
  }

  /// Static evaluation of the board position.
  /// Returns white-relative centipawn score (positive = good for white).
  /// Callers in negamax must convert to side-to-move relative when needed.
  int _evaluatePosition(chess.Chess board) {
    return PositionEvaluator.evaluate(board);
  }
}

/// Result from simple bot calculation
class SimpleBotResult {
  final String bestMove;
  final int evaluation;
  final List<String> principalVariation;

  SimpleBotResult({
    required this.bestMove,
    required this.evaluation,
    this.principalVariation = const [],
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
