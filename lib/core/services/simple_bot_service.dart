import 'dart:isolate';
import 'dart:math';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/services/position_evaluator.dart';

/// Lightweight chess bot using negamax with alpha-beta pruning,
/// iterative deepening, principal variation tracking,
/// quiescence search, and MVV-LVA move ordering.
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

  // Killer move table: 2 killers per ply, up to 32 ply
  static final List<List<String?>> _killers = List.generate(
    32,
    (_) => [null, null],
  );

  // History heuristic: Map<from*64 + to, score>
  static final Map<int, int> _history = {};

  /// Get best move for the current position
  /// [fen] - Position in FEN notation
  /// [depth] - Search depth (1-6 recommended for fallback engine)
  Future<SimpleBotResult> getBestMove({
    required String fen,
    int depth = 3,
  }) async {
    final effectiveDepth = min(depth, 4);
    final cancelId = _cancelToken;
    final bookResult = _tryOpeningBook(fen);
    if (bookResult != null) return bookResult;

    return Isolate.run(() => _getBestMoveSync(fen, effectiveDepth, cancelId));
  }

  /// Small deterministic opening book for the fallback engine.
  ///
  /// This keeps SimpleBot from spending expensive search time in the first
  /// few plies and avoids unnatural repeated knight-only openings when
  /// Stockfish is unavailable.
  SimpleBotResult? _tryOpeningBook(String fen) {
    final key = _fenBookKey(fen);
    final bookMove = _openingBook[key];
    if (bookMove == null) return null;

    try {
      final board = chess.Chess.fromFEN(fen);
      final legalMoves = board.moves({'verbose': true});
      Map? selectedMove;
      for (final move in legalMoves) {
        final moveMap = move as Map;
        if (_moveToStr(moveMap) == bookMove) {
          selectedMove = moveMap;
          break;
        }
      }
      if (selectedMove == null) return null;

      board.move(selectedMove);
      final evaluation = _evaluatePosition(board);
      return SimpleBotResult(
        bestMove: bookMove,
        evaluation: evaluation,
        principalVariation: [bookMove],
      );
    } catch (_) {
      return null;
    }
  }

  String _fenBookKey(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) return fen.trim();
    return parts.take(4).join(' ');
  }

  static const Map<String, String> _openingBook = {
    // Initial position: claim the center.
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -': 'e2e4',

    // Common first moves by White.
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -': 'e7e5',
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq -': 'd7d5',
    'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq -': 'e7e5',
    'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq -': 'd7d5',

    // Simple second moves: develop naturally after central replies.
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -': 'g1f3',
    'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq -': 'c2c4',
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -': 'g1f3',
  };

  /// Synchronous computation — runs inside an isolate.
  /// Uses iterative deepening with negamax alpha-beta and PV tracking.
  SimpleBotResult _getBestMoveSync(String fen, int depth, int cancelId) {
    // Sync cancel token — isolates have their own static copy starting at 0
    _cancelToken = cancelId;
    final board = chess.Chess.fromFEN(fen);

    if (board.in_checkmate) {
      final sideToMoveScore = -999999 + depth;
      final adjustedEval =
          board.turn == chess.Color.BLACK ? -sideToMoveScore : sideToMoveScore;
      return SimpleBotResult(bestMove: '', evaluation: adjustedEval);
    }
    if (board.in_stalemate || board.in_draw) {
      return SimpleBotResult(bestMove: '', evaluation: 0);
    }

    final moves = board.moves({'verbose': true});
    if (moves.isEmpty) {
      return SimpleBotResult(bestMove: '', evaluation: 0);
    }

    if (depth <= 0) {
      final singlePlyResult = _pickBestSinglePly(board, moves);
      final adjustedEval =
          board.turn == chess.Color.WHITE
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

    if (!isWhiteToMove && depth > 0) bestEval = -bestEval;

    return SimpleBotResult(
      bestMove: bestMove,
      evaluation: bestEval,
      principalVariation: bestPv,
    );
  }

  /// Evaluate each move at depth 1 and return the best.
  SimpleBotResult _pickBestSinglePly(chess.Chess board, List moves) {
    String bestMove = '';
    final isWhiteToMove = board.turn == chess.Color.WHITE;
    int bestEval = -999999;

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      final rawEval = _evaluatePosition(board);
      board.undo();

      final eval = isWhiteToMove ? rawEval : -rawEval;

      if (eval > bestEval) {
        bestEval = eval;
        bestMove = _moveToStr(m);
      }
    }

    return SimpleBotResult(bestMove: bestMove, evaluation: bestEval);
  }

  /// Root search — tries each root move and calls negamax for deeper search.
  ({String bestMove, int eval, List<String> pv}) _searchRoot(
    chess.Chess board,
    int depth,
  ) {
    final moves = board.moves({'verbose': true});
    // Clear killer/history tables for new search
    for (int i = 0; i < _killers.length; i++) {
      _killers[i] = [null, null];
    }
    _history.clear();

    String bestMove = '';
    int bestEval = -999999;
    List<String> bestPv = [];

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      final result = _negamax(board, depth - 1, -999999, 999999, 1);
      board.undo();

      final eval = -result.score;

      if (eval > bestEval) {
        bestEval = eval;
        bestMove = _moveToStr(m);
        bestPv = [bestMove, ...result.pv];
      }
    }

    return (bestMove: bestMove, eval: bestEval, pv: bestPv);
  }

  /// Pure negamax with alpha-beta pruning and move ordering.
  /// [ply] is the search depth from the root (used for killer table).
  ({int score, List<String> pv}) _negamax(
    chess.Chess board,
    int depth,
    int alpha,
    int beta,
    int ply,
  ) {
    if (depth == 0) {
      return _quiescence(board, alpha, beta, 0);
    }

    if (board.in_checkmate) {
      return (score: -999999 + depth, pv: const []);
    }

    if (board.in_stalemate || board.in_draw) {
      return (score: 0, pv: const []);
    }

    final moves = board.moves({'verbose': true});
    if (moves.isEmpty) return (score: 0, pv: const []);

    _orderMoves(moves, null, ply, board);

    int bestScore = alpha;
    List<String> bestPv = const [];

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      final result = _negamax(board, depth - 1, -beta, -bestScore, ply + 1);
      board.undo();

      final score = -result.score;

      if (score >= beta) {
        // Record killer move (non-capture only)
        if (m['captured'] == null && m['promotion'] == null) {
          final uci = _moveToStr(m);
          if (_killers[ply][0] != uci) {
            _killers[ply][1] = _killers[ply][0];
            _killers[ply][0] = uci;
          }
        }
        return (score: beta, pv: const []);
      }

      if (score > bestScore) {
        bestScore = score;
        bestPv = [_moveToStr(m), ...result.pv];
      }
    }

    return (score: bestScore, pv: bestPv);
  }

  /// Quiescence search — extends search at leaf nodes to resolve tactical
  /// sequences. Uses stand-pat evaluation and searches captures + promotions.
  /// Alpha-beta pruned with delta pruning for efficiency.
  ({int score, List<String> pv}) _quiescence(
    chess.Chess board,
    int alpha,
    int beta,
    int qDepth,
  ) {
    // Stand-pat evaluation (side-to-move relative)
    int standPat = _evaluatePositionFast(board);
    if (board.turn == chess.Color.BLACK) standPat = -standPat;

    if (standPat >= beta) return (score: beta, pv: const []);
    if (standPat > alpha) alpha = standPat;

    if (board.in_checkmate) {
      return (score: -999999 + qDepth, pv: const []);
    }
    if (board.in_stalemate || board.in_draw) {
      return (score: 0, pv: const []);
    }

    // Delta pruning: if stand-pat + queen value can't reach alpha, stop
    if (standPat + 900 < alpha) return (score: alpha, pv: const []);

    if (qDepth >= 6) return (score: standPat, pv: const []);

    final allMoves = board.moves({'verbose': true});
    if (allMoves.isEmpty) return (score: standPat, pv: const []);

    // In check: search ALL moves to resolve the check
    // Otherwise: search only captures and promotions
    final moves =
        board.in_check
            ? allMoves
            : allMoves.where((m) {
              final map = m as Map;
              return map['captured'] != null || map['promotion'] != null;
            }).toList();

    if (moves.isEmpty) return (score: standPat, pv: const []);

    _orderMoves(moves, null, qDepth, board);

    int bestScore = alpha;
    List<String> bestPv = const [];

    for (final move in moves) {
      final m = move as Map;
      board.move(m);
      final result = _quiescence(board, -beta, -bestScore, qDepth + 1);
      board.undo();

      final score = -result.score;

      if (score >= beta) {
        return (score: beta, pv: const []);
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

  /// Order moves using MVV-LVA, PV move priority, killer heuristic,
  /// and history heuristic. Best moves first for maximum alpha-beta pruning.
  void _orderMoves(List moves, String? pvMove, int ply, chess.Chess board) {
    moves.sort((a, b) {
      final mapA = a as Map;
      final mapB = b as Map;
      final sa = _moveScore(mapA, pvMove, ply);
      final sb = _moveScore(mapB, pvMove, ply);
      return sb - sa;
    });
  }

  /// Score a single move for ordering. Higher = better (searched first).
  /// Priority tiers:
  ///   1,000,000+  → PV move (from previous ID iteration)
  ///     500,000+  → Winning capture (MVV-LVA > 0)
  ///     400,000+  → Equal capture (MVV-LVA == 0)
  ///     300,000+  → Promotion
  ///     200,000+  → Killer move 0
  ///     190,000+  → Killer move 1
  ///     100,000+  → History heuristic bonus
  ///           0+  → Quiet moves
  ///           Negative → Losing capture
  int _moveScore(Map m, String? pvMove, int ply) {
    final uci = _moveToStr(m);

    // Tier 1: PV move
    if (pvMove != null && uci == pvMove) return 1000000;

    // Tier 2: MVV-LVA for captures
    // m['captured'] and m['piece'] are PieceType enums from the chess library
    final captured = m['captured'];
    if (captured != null) {
      final victimVal = _pieceValue(captured);
      final attacker = m['piece'];
      final attackerVal = _pieceValue(attacker);
      final mvvLva = victimVal * 100 - attackerVal;
      if (mvvLva > 0) return 500000 + mvvLva;
      if (mvvLva == 0) return 400000;
      return mvvLva; // losing capture (negative)
    }

    // Tier 3: Promotion
    if (m['promotion'] != null) return 300000;

    // Tier 4: Killer moves
    for (int k = 0; k < 2; k++) {
      if (_killers[ply][k] == uci) return 200000 - k * 10000;
    }

    // Tier 5: History heuristic
    final histKey = _historyKey(m);
    final histScore = _history[histKey] ?? 0;
    if (histScore > 0) return 100000 + histScore;

    return 0;
  }

  /// Generate a unique key for the history table from a move map.
  int _historyKey(Map m) {
    final from = m['from'] as String;
    final to = m['to'] as String;
    return (from.codeUnitAt(0) - 97) +
        (from.codeUnitAt(1) - 49) * 8 +
        ((to.codeUnitAt(0) - 97) + (to.codeUnitAt(1) - 49) * 8) * 64;
  }

  /// Map a PieceType or dynamic value to centipawn value for MVV-LVA.
  int _pieceValue(dynamic piece) {
    if (piece == null) return 0;
    if (piece is chess.PieceType) {
      switch (piece) {
        case chess.PieceType.PAWN:
          return 100;
        case chess.PieceType.KNIGHT:
          return 320;
        case chess.PieceType.BISHOP:
          return 330;
        case chess.PieceType.ROOK:
          return 500;
        case chess.PieceType.QUEEN:
          return 900;
        default:
          return 0;
      }
    }
    return 0;
  }

  /// Static evaluation of the board position (full evaluation with mobility).
  /// Returns white-relative centipawn score.
  int _evaluatePosition(chess.Chess board) {
    return PositionEvaluator.evaluate(board);
  }

  /// Fast evaluation for quiescence search (skips mobility to avoid redundant
  /// move generation). Returns white-relative centipawn score.
  int _evaluatePositionFast(chess.Chess board) {
    return PositionEvaluator.evaluate(board, skipMobility: true);
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
