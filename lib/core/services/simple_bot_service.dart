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
  /// [blunderRate] - Probability of making humanized mistakes (0.0 to 1.0)
  /// [useOpeningBook] - Whether to consult deterministic opening book
  /// [positionHistory] - FEN keys (first 4 fields) of the real game so far,
  ///   used for repetition / anti-loop penalties. Cheap Zobrist substitute.
  /// [openingStyle] - Bot personality style (Italian, Solid Fortress, ...).
  /// [elo] - Bot ELO, controls book variety + mistake window.
  Future<SimpleBotResult> getBestMove({
    required String fen,
    int depth = 3,
    int timeLimitMs = 900,
    double blunderRate = 0.0,
    bool useOpeningBook = true,
    List<String>? positionHistory,
    String? openingStyle,
    int? elo,
    Random? random,
  }) async {
    // Weak bots (<=500) play shallower: depth 2 keeps them visibly weaker
    // than 700+ bots beyond what blunder sampling alone achieves.
    final resolvedElo = elo ?? _eloFromBlunder(blunderRate);
    final depthCap = resolvedElo <= 500 ? 2 : 4;
    final effectiveDepth = min(depth, depthCap);
    final cancelId = _cancelToken;
    // Random is not isolate-transferable: forward a seed instead so callers
    // can still get reproducible sampling via the `random` parameter.
    final seed = random?.nextInt(1 << 32);
    final historyKeys = (positionHistory ?? const <String>[])
        .map(_fenBookKey)
        .toList();
    if (useOpeningBook) {
      final bookResult = _tryOpeningBook(
        fen,
        elo: elo,
        openingStyle: openingStyle,
        blunderRate: blunderRate,
        random: random,
      );
      if (bookResult != null) return bookResult;
    }

    return Isolate.run(
      () => _getBestMoveSync(
        fen,
        effectiveDepth,
        cancelId,
        timeLimitMs,
        blunderRate,
        historyKeys,
        elo,
        seed,
      ),
    );
  }

  /// Weighted multi-line opening book: FEN-key -> candidate UCIs with weights.
  /// Covers 8-10 plies so bots develop (pawns center, knights, bishops,
  /// castle) instead of knight-shuffling after move 2.
  SimpleBotResult? _tryOpeningBook(
    String fen, {
    int? elo,
    String? openingStyle,
    double blunderRate = 0.0,
    Random? random,
  }) {
    final key = _fenBookKey(fen);
    var candidates = _openingBook[key];
    if (candidates == null || candidates.isEmpty) return null;

    // Personality filter: Italian/Spanish/Queen Gambit bots prefer their lines
    // when multiple replies exist; low-ELO Random bots keep full variety.
    final style = (openingStyle ?? '').toLowerCase();
    if (style.contains('italian')) {
      final italian = candidates
          .where((c) => _italianMoves.contains(c.move))
          .toList();
      if (italian.isNotEmpty) candidates = italian;
    } else if (style.contains('spanish') || style.contains('ruy')) {
      final spanish = candidates
          .where((c) => _spanishMoves.contains(c.move))
          .toList();
      if (spanish.isNotEmpty) candidates = spanish;
    }

    // ELO variety: 400-500 samples everything incl. offbeat; 650+ only
    // main developing replies; 850+ already filtered by personality above.
    // Deterministic default (tests / no elo): top weight wins (e4, e5).
    final hasVariety = elo != null || random != null;
    final rng = random ?? Random();
    String bookMove;
    if (!hasVariety) {
      bookMove = candidates.reduce((a, b) => a.weight >= b.weight ? a : b).move;
    } else {
      if ((elo ?? 800) >= 650) {
        final main = candidates.where((c) => !c.offbeat).toList();
        if (main.isNotEmpty) candidates = main;
      }
      final total = candidates.fold<int>(0, (s, c) => s + c.weight);
      var roll = rng.nextInt(total <= 0 ? 1 : total);
      bookMove = candidates.first.move;
      for (final c in candidates) {
        roll -= c.weight;
        if (roll < 0) {
          bookMove = c.move;
          break;
        }
      }
    }

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

  static const Set<String> _italianMoves = {
    'f1c4',
    'f8c5',
    'g1f3',
    'g8f6',
    'b1c3',
    'b8c6',
  };
  static const Set<String> _spanishMoves = {'f1b5', 'a7a6', 'g1f3', 'b8c6'};

  static const Map<String, List<BookMove>> _openingBook = {
    // Initial position: claim the center with variety.
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -': [
      BookMove('e2e4', 40),
      BookMove('d2d4', 30),
      BookMove('g1f3', 15),
      BookMove('c2c4', 10),
      BookMove('g2g3', 3, offbeat: true),
      BookMove('b2b3', 2, offbeat: true),
    ],
    // Common first moves by White.
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -': [
      BookMove('e7e5', 35),
      BookMove('c7c5', 25),
      BookMove('e7e6', 15),
      BookMove('c7c6', 10),
      BookMove('d7d5', 10),
      BookMove('g8f6', 5),
    ],
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq -': [
      BookMove('d7d5', 35),
      BookMove('g8f6', 30),
      BookMove('e7e6', 20),
      BookMove('c7c5', 10),
      BookMove('d7d6', 5, offbeat: true),
    ],
    'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq -': [
      BookMove('e7e5', 50),
      BookMove('c7c5', 25),
      BookMove('g8f6', 15),
      BookMove('e7e6', 10),
    ],
    'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq -': [
      BookMove('d7d5', 40),
      BookMove('g8f6', 30),
      BookMove('d7d6', 20),
      BookMove('e7e5', 10),
    ],
    // Simple second moves: develop naturally after central replies.
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -': [
      BookMove('g1f3', 40),
      BookMove('b1c3', 25),
      BookMove('f1c4', 15),
      BookMove('d2d4', 10),
      BookMove('f1b5', 10),
    ],
    'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq -': [
      BookMove('c2c4', 40),
      BookMove('g1f3', 30),
      BookMove('b1c3', 15),
      BookMove('e2e3', 10),
      BookMove('c1f4', 5, offbeat: true),
    ],
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -': [
      BookMove('g1f3', 45),
      BookMove('b1c3', 25),
      BookMove('d2d4', 20),
      BookMove('f1c4', 10),
    ],
    // Italian / Spanish development + castling ideas.
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq -': [
      BookMove('f1c4', 45),
      BookMove('f1b5', 30),
      BookMove('d2d4', 15),
      BookMove('b1c3', 10),
    ],
    'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq -': [
      BookMove('e1g1', 55),
      BookMove('d2d3', 20),
      BookMove('c2c3', 15),
      BookMove('b1c3', 10),
    ],
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -': [
      BookMove('b8c6', 40),
      BookMove('g8f6', 30),
      BookMove('f8c5', 15),
      BookMove('d7d6', 15),
    ],
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -': [
      BookMove('g8f6', 40),
      BookMove('f8c5', 30),
      BookMove('d7d6', 20),
      BookMove('f8e7', 10),
    ],
  };

  /// Synchronous computation — runs inside an isolate.
  /// Uses iterative deepening with negamax alpha-beta and PV tracking.
  SimpleBotResult _getBestMoveSync(
    String fen,
    int depth,
    int cancelId,
    int timeLimitMs, [
    double blunderRate = 0.0,
    List<String> historyKeys = const [],
    int? elo,
    int? seed,
  ]) {
    // Sync cancel token — isolates have their own static copy starting at 0
    _cancelToken = cancelId;
    final searchTimer = Stopwatch()..start();
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

    // --- Iterative Deepening with scored root moves ---
    final isWhiteToMove = board.turn == chess.Color.WHITE;
    List<({String move, int score, List<String> pv})> scored = [];

    for (int idDepth = 1; idDepth <= depth; idDepth++) {
      if (_cancelToken != cancelId) break;
      if (_isTimedOut(searchTimer, timeLimitMs)) break;

      final rootResult = _searchRoot(
        board,
        idDepth,
        searchTimer,
        timeLimitMs,
        historyKeys,
      );

      if (_cancelToken != cancelId) break;
      if (_isTimedOut(searchTimer, timeLimitMs) && scored.isNotEmpty) break;
      if (rootResult.isNotEmpty) scored = rootResult;
    }

    if (scored.isEmpty) {
      final fallback = _moveToStr(moves[0] as Map);
      return SimpleBotResult(bestMove: fallback, evaluation: 0);
    }

    // Hard-ban immediate 2-fold: drop moves recreating the last position
    // unless everything loses heavily or we are evading check.
    final lastKey = historyKeys.isEmpty ? '' : historyKeys.last;
    if (lastKey.isNotEmpty && !board.in_check && scored.length > 1) {
      final filtered = <({String move, int score, List<String> pv})>[];
      for (final s in scored) {
        if (_moveLeadsToKey(board, s.move, lastKey)) {
          // Keep only if it is clearly best (tactical necessity).
          if (s.score >= scored.first.score - 50) {
            // Ban: would repeat last position for no gain.
            continue;
          }
        }
        filtered.add(s);
      }
      if (filtered.isNotEmpty) scored = filtered;
    }

    final chosen = _sampleByElo(
      scored,
      elo ?? _eloFromBlunder(blunderRate),
      blunderRate,
      seed == null ? Random() : Random(seed),
    );
    var bestMove = chosen.move;
    var bestEval = chosen.score;
    var bestPv = chosen.pv;

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
      final uci = _moveToStr(m);
      board.move(m);
      final rawEval =
          _evaluatePosition(board) + _developmentBonus(board, m, uci);
      board.undo();

      final eval = isWhiteToMove ? rawEval : -rawEval;

      if (eval > bestEval) {
        bestEval = eval;
        bestMove = uci;
      }
    }

    return SimpleBotResult(bestMove: bestMove, evaluation: bestEval);
  }

  /// Root search — returns ALL root moves scored (for ELO sampling).
  /// Keeps killer/history across iterations (decay only) to reduce oscillation.
  List<({String move, int score, List<String> pv})> _searchRoot(
    chess.Chess board,
    int depth,
    Stopwatch searchTimer,
    int timeLimitMs,
    List<String> historyKeys,
  ) {
    final moves = board.moves({'verbose': true});
    // Decay (not clear) history so shuffles are not re-rewarded every move.
    _history.updateAll((k, v) => (v * 0.8).round());

    _orderMoves(moves, null, 0, board);

    final scored = <({String move, int score, List<String> pv})>[];
    for (final move in moves) {
      if (_isTimedOut(searchTimer, timeLimitMs)) break;
      final m = move as Map;
      final uci = _moveToStr(m);
      board.move(m);
      final result = _negamax(
        board,
        depth - 1,
        -999999,
        999999,
        1,
        searchTimer,
        timeLimitMs,
      );
      // Layer human-like bonuses on top of search (side-to-move relative).
      var eval = -result.score;
      eval += _developmentBonus(board, m, uci);
      eval += _repetitionScore(board, historyKeys);
      eval += _antiLoopScore(m, uci, historyKeys);
      final pv = [uci, ...result.pv];
      board.undo();

      scored.add((move: uci, score: eval, pv: pv));

      // Record killer for quiet best-raising moves (no per-search clear).
      if (m['captured'] == null && m['promotion'] == null) {
        final ply = 0;
        if (_killers[ply][0] != uci) {
          _killers[ply][1] = _killers[ply][0];
          _killers[ply][0] = uci;
        }
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Development / castling / center bonus (side-to-move relative, centipawns).
  /// Fixes knight-shuffling: developing + castling + occupying center outscores
  /// going Nf3-g1 or Ra1-b1-a1 at depth 1-3.
  int _developmentBonus(chess.Chess board, Map m, String uci) {
    var bonus = 0;
    final piece = m['piece']?.toString().toLowerCase() ?? '';
    final isKnight = piece.contains('knight') || piece == 'n';
    final isBishop = piece.contains('bishop') || piece == 'b';
    final to = m['to'] as String? ?? (uci.length >= 4 ? uci.substring(2, 4) : '');
    final from = m['from'] as String? ?? uci.substring(0, 2);
    final moveNo = board.move_number;

    // Develop minors off the back rank early.
    if ((isKnight || isBishop) && moveNo <= 14) {
      final backRank = board.turn == chess.Color.WHITE ? '1' : '8';
      if (from.endsWith(backRank) && !to.endsWith(backRank)) bonus += 28;
    }
    // e/d center pawn pushes from start.
    if ((uci == 'e2e4' || uci == 'd2d4' || uci == 'e7e5' || uci == 'd7d5')) {
      bonus += 30;
    }
    if (uci == 'c2c4' || uci == 'c7c5' || uci == 'e2e3' || uci == 'e7e6') {
      bonus += 12;
    }
    // Castling is good; losing the right without castling is bad.
    if (uci == 'e1g1' || uci == 'e1c1' || uci == 'e8g8' || uci == 'e8c8') {
      bonus += 45;
    }
    // Penalize early queen sorties (Wayward Queen stays only for Aaron via book).
    final isQueen = piece.contains('queen') || piece == 'q';
    if (isQueen && moveNo < 8) bonus -= 35;
    // Penalize knight retreat to its origin square (Nf3-g1, Nb1-a3-c2-b1 loops).
    if (isKnight && _isOwnBackRankOrigin(from, to, board.turn)) bonus -= 25;
    return board.turn == chess.Color.WHITE ? bonus : -bonus;
  }

  bool _isOwnBackRankOrigin(String from, String to, chess.Color turn) {
    // Knight returned to b1/g1 (white) or b8/g8 (black) after leaving.
    if (turn == chess.Color.WHITE) {
      return (to == 'b1' || to == 'g1') && from != to;
    }
    return (to == 'b8' || to == 'g8') && from != to;
  }

  /// Repetition score: avoid draw when ahead, seek when behind.
  int _repetitionScore(chess.Chess board, List<String> historyKeys) {
    if (historyKeys.isEmpty) return 0;
    final key = _fenBookKey(board.fen);
    var count = 0;
    for (final h in historyKeys) {
      if (h == key) count++;
    }
    if (count >= 2) return board.turn == chess.Color.WHITE ? -10000 : 10000;
    if (count == 1) {
      final staticEval = _sideToMoveEval(board);
      if (staticEval > 100) return -150; // ahead: avoid 2-fold
      if (staticEval < -100) return 100; // behind: seek 2-fold
      return -60;
    }
    return 0;
  }

  /// Anti-loop: penalize immediate back-and-forth (A-B-A) with same piece.
  int _antiLoopScore(Map m, String uci, List<String> historyKeys) {
    if (historyKeys.length < 2) return 0;
    if (m['captured'] != null || m['promotion'] != null) return 0;
    // Heuristic: rook/knight shuffle between two squares scores -60.
    // Full A-B-A-B tracking needs move history; approximate via killer table:
    // if this UCI is already killer[0] at ply 0 two searches running, it is
    // being replayed — penalize lightly so a developing alternative wins ties.
    if (_killers[0][0] == uci || _killers[0][1] == uci) return -25;
    return 0;
  }

  bool _moveLeadsToKey(chess.Chess board, String uci, String key) {
    try {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promo = uci.length > 4 ? uci.substring(4, 5) : null;
      board.move({'from': from, 'to': to, if (promo != null) 'promotion': promo});
      final after = _fenBookKey(board.fen);
      board.undo();
      return after == key;
    } catch (_) {
      return false;
    }
  }

  int _eloFromBlunder(double blunderRate) {
    if (blunderRate >= 0.4) return 400;
    if (blunderRate >= 0.3) return 500;
    if (blunderRate >= 0.2) return 700;
    if (blunderRate >= 0.12) return 950;
    if (blunderRate > 0.0) return 1100;
    return 1200;
  }

  /// ELO-scaled sampling over scored root moves (never uniform-random legal).
  /// Deterministic when blunderRate == 0 and no elo given (unit tests).
  ({String move, int score, List<String> pv}) _sampleByElo(
    List<({String move, int score, List<String> pv})> scored,
    int elo,
    double blunderRate,
    Random rng,
  ) {
    if (blunderRate == 0.0) return scored.first;
    final int topN, window;
    final double temp, blunderProb;
    if (elo <= 450) {
      topN = 9;
      window = 280;
      temp = 1.1;
      blunderProb = 0.25;
    } else if (elo <= 550) {
      topN = 6;
      window = 200;
      temp = 0.9;
      blunderProb = 0.20;
    } else if (elo <= 750) {
      topN = 5;
      window = 150;
      temp = 0.7;
      blunderProb = 0.15;
    } else if (elo <= 950) {
      topN = 4;
      window = 120;
      temp = 0.5;
      blunderProb = 0.10;
    } else if (elo <= 1100) {
      topN = 3;
      window = 80;
      temp = 0.3;
      blunderProb = 0.07;
    } else {
      topN = 2;
      window = 50;
      temp = 0.15;
      blunderProb = 0.04;
    }
    final best = scored.first.score;
    final pool =
        scored.where((s) => best - s.score <= window).take(topN).toList();
    if (pool.length <= 1) return scored.first;

    // Occasional human lapse: uniform inside pool (never outside window).
    final p = blunderRate > 0 ? blunderRate.clamp(0.0, 1.0) : blunderProb;
    if (rng.nextDouble() < p && pool.length > 1) {
      return pool[1 + rng.nextInt(pool.length - 1)];
    }
    // Softmax by score/temperature.
    final weights = pool.map((s) {
      final d = (s.score - best).toDouble(); // <= 0
      return exp(d / (temp * 100.0));
    }).toList();
    var total = weights.fold<double>(0, (a, b) => a + b);
    var roll = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return pool[i];
    }
    return pool.first;
  }

  /// Pure negamax with alpha-beta pruning and move ordering.
  /// [ply] is the search depth from the root (used for killer table).
  ({int score, List<String> pv}) _negamax(
    chess.Chess board,
    int depth,
    int alpha,
    int beta,
    int ply,
    Stopwatch searchTimer,
    int timeLimitMs,
  ) {
    if (_isTimedOut(searchTimer, timeLimitMs)) {
      return (score: _sideToMoveEval(board), pv: const []);
    }

    if (depth == 0) {
      return _quiescence(board, alpha, beta, 0, searchTimer, timeLimitMs);
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
      final result = _negamax(
        board,
        depth - 1,
        -beta,
        -bestScore,
        ply + 1,
        searchTimer,
        timeLimitMs,
      );
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
    Stopwatch searchTimer,
    int timeLimitMs,
  ) {
    if (_isTimedOut(searchTimer, timeLimitMs)) {
      return (score: _sideToMoveEval(board), pv: const []);
    }

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

    if (qDepth >= 4) return (score: standPat, pv: const []);

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
      final result = _quiescence(
        board,
        -beta,
        -bestScore,
        qDepth + 1,
        searchTimer,
        timeLimitMs,
      );
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
    final pieceText = piece.toString().toLowerCase();
    if (pieceText.endsWith('pawn') || pieceText == 'p') return 100;
    if (pieceText.endsWith('knight') || pieceText == 'n') return 320;
    if (pieceText.endsWith('bishop') || pieceText == 'b') return 330;
    if (pieceText.endsWith('rook') || pieceText == 'r') return 500;
    if (pieceText.endsWith('queen') || pieceText == 'q') return 900;
    return 0;
  }

  bool _isTimedOut(Stopwatch stopwatch, int timeLimitMs) {
    return stopwatch.elapsedMilliseconds >= timeLimitMs;
  }

  int _sideToMoveEval(chess.Chess board) {
    final eval = _evaluatePositionFast(board);
    return board.turn == chess.Color.WHITE ? eval : -eval;
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

/// Weighted opening-book candidate.
class BookMove {
  final String move;
  final int weight;
  final bool offbeat;
  const BookMove(this.move, this.weight, {this.offbeat = false});
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
