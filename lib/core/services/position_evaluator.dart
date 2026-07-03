import 'package:chess/chess.dart' as chess;

/// Modular, stateless position evaluator consolidating all evaluation heuristics.
/// Returns white-relative centipawn scores (positive = good for white).
/// Called at every negamax leaf node - must be efficient.
class PositionEvaluator {
  PositionEvaluator._();

  // -- Piece values (centipawns) ---
  static const int pawnValue = 100;
  static const int knightValue = 320;
  static const int bishopValue = 330;
  static const int rookValue = 500;
  static const int queenValue = 900;
  static const int kingValue = 20000;

  // -- Heuristic bonuses/penalties (centipawns) ---
  static const int bishopPairBonus = 30;
  static const int passedPawnBonusPerRank = 10;
  static const int isolatedPawnPenalty = 15;
  static const int doubledPawnPenalty = 20;
  static const int backwardPawnPenalty = 10;
  static const int connectedPawnBonus = 5;
  static const int pawnChainBonus = 10;
  static const int pawnIslandPenalty = 5;
  static const int candidatePasserBonus = 15;
  static const int kingPawnShieldBonus = 10;
  static const int kingOpenFilePenalty = 15;
  static const int kingStormFilePenalty = 10;
  static const int rookOpenFileBonus = 15;
  static const int rookSemiOpenFileBonus = 10;
  static const int rookSeventhRankBonus = 25;
  static const int rookConnectedBonus = 10;
  static const int knightOutpostBonus = 25;
  static const int knightRimPenalty = 15;
  static const int knightCentralBonus = 10;
  static const int bishopLongDiagonalBonus = 15;
  static const int bishopTrappedPenalty = 50;
  static const int queenEarlyDevelopmentPenalty = 20;
  static const int centerControlBonus = 10;
  static const int centerOccupationBonus = 15;
  static const int kingEndgameActivityBonus = 20;
  static const int passedPawnEndgameBonus = 10;
  static const int mobilityWeight = 4;
  static const int mobilityMaxPieces = 24;
  // -- PST tables (a1=0, h1=7, a2=8, ..., h8=63) ---
  static const List<int> pawnTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  static const List<int> knightTable = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  static const List<int> bishopTable = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ];

  static const List<int> rookTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ];

  static const List<int> queenTable = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ];

  static const List<int> kingMiddleGameTable = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ];

  static const List<int> kingEndGameTable = [
    -50, -40, -30, -20, -20, -30, -40, -50,
    -30, -20, -10, 0, 0, -10, -20, -30,
    -30, -10, 20, 30, 30, 20, -10, -30,
    -30, -10, 30, 40, 40, 30, -10, -30,
    -30, -10, 30, 40, 40, 30, -10, -30,
    -30, -10, 20, 30, 30, 20, -10, -30,
    -30, -30, 0, 0, 0, 0, -30, -30,
    -50, -30, -30, -30, -30, -30, -30, -50,
  ];
  /// Main evaluation entry point. Returns white-relative centipawn score.
  /// [skipMobility] should be true when called from quiescence search to avoid
  /// redundant move generation (mobility calls board.moves() internally).
  static int evaluate(chess.Chess board, {bool skipMobility = false}) {
    int score = 0;
    score += _evaluateMaterial(board);
    score += _evaluateBishopPair(board);
    score += _evaluatePawnStructure(board);
    score += _evaluateKingSafety(board);
    score += _evaluateRookActivity(board);
    score += _evaluateKnights(board);
    score += _evaluateBishops(board);
    score += _evaluateQueen(board);
    score += _evaluateCenterControl(board);
    score += _evaluateEndgame(board);
    if (!skipMobility) {
      score += _evaluateMobility(board);
    }
    return score;
  }

  // -- Material + PST ---
  static int _evaluateMaterial(chess.Chess board) {
    int score = 0;
    for (int rank = 0; rank < 8; rank++) {
      final baseIndex = rank * 16;
      for (int file = 0; file < 8; file++) {
        final piece = board.board[baseIndex + file];
        if (piece == null) continue;
        final isWhite = piece.color == chess.Color.WHITE;
        final m = isWhite ? 1 : -1;
        int v = 0;
        switch (piece.type) {
          case chess.PieceType.PAWN:
            v = pawnValue + _pst(pawnTable, rank, file, isWhite);
            break;
          case chess.PieceType.KNIGHT:
            v = knightValue + _pst(knightTable, rank, file, isWhite);
            break;
          case chess.PieceType.BISHOP:
            v = bishopValue + _pst(bishopTable, rank, file, isWhite);
            break;
          case chess.PieceType.ROOK:
            v = rookValue + _pst(rookTable, rank, file, isWhite);
            break;
          case chess.PieceType.QUEEN:
            v = queenValue + _pst(queenTable, rank, file, isWhite);
            break;
          case chess.PieceType.KING:
            v = kingValue + _pst(kingMiddleGameTable, rank, file, isWhite);
            break;
        }
        score += m * v;
      }
    }
    return score;
  }

  static int _pst(List<int> table, int rank, int file, bool isWhite) {
    return table[isWhite ? (7 - rank) * 8 + file : rank * 8 + file];
  }

  // -- Bishop pair ---
  static int _evaluateBishopPair(chess.Chess board) {
    int wb = 0, bb = 0;
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p?.type == chess.PieceType.BISHOP) {
          if (p!.color == chess.Color.WHITE) { wb++; } else { bb++; }
        }
      }
    }
    int s = 0;
    if (wb >= 2) s += bishopPairBonus;
    if (bb >= 2) s -= bishopPairBonus;
    return s;
  }
  // -- Pawn structure ---
  static int _evaluatePawnStructure(chess.Chess board) {
    int score = 0;
    final List<int> wFiles = [], bFiles = [];
    final List<List<int>> wRanks = List.generate(8, (_) => []);
    final List<List<int>> bRanks = List.generate(8, (_) => []);

    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p?.type == chess.PieceType.PAWN) {
          if (p!.color == chess.Color.WHITE) {
            wFiles.add(f); wRanks[f].add(r);
          } else {
            bFiles.add(f); bRanks[f].add(r);
          }
        }
      }
    }

    // Passed pawns
    for (int f = 0; f < 8; f++) {
      for (final r in wRanks[f]) {
        if (_isPassed(f, r, true, bRanks)) {
          score += passedPawnBonusPerRank * (7 - r);
        }
      }
    }
    for (int f = 0; f < 8; f++) {
      for (final r in bRanks[f]) {
        if (_isPassed(f, r, false, wRanks)) {
          score -= passedPawnBonusPerRank * r;
        }
      }
    }

    // Isolated pawns
    for (final f in wFiles) { if (!_hasNeighbor(f, wFiles)) score -= isolatedPawnPenalty; }
    for (final f in bFiles) { if (!_hasNeighbor(f, bFiles)) score += isolatedPawnPenalty; }

    // Doubled pawns
    for (int f = 0; f < 8; f++) {
      if (wRanks[f].length > 1) score -= doubledPawnPenalty * (wRanks[f].length - 1);
      if (bRanks[f].length > 1) score += doubledPawnPenalty * (bRanks[f].length - 1);
    }

    // Backward pawns
    for (int f = 0; f < 8; f++) {
      for (final r in wRanks[f]) {
        if (_isBackward(f, r, true, wFiles, wRanks, bRanks)) score -= backwardPawnPenalty;
      }
    }
    for (int f = 0; f < 8; f++) {
      for (final r in bRanks[f]) {
        if (_isBackward(f, r, false, bFiles, bRanks, wRanks)) score += backwardPawnPenalty;
      }
    }

    // Connected pawns
    for (final f in wFiles) {
      if (wRanks[f].isNotEmpty && _hasNeighbor(f, wFiles)) score += connectedPawnBonus;
    }
    for (final f in bFiles) {
      if (bRanks[f].isNotEmpty && _hasNeighbor(f, bFiles)) score -= connectedPawnBonus;
    }

    // Pawn chains
    for (int f = 0; f < 8; f++) {
      for (final r in wRanks[f]) {
        if (_isChain(f, r, true, wRanks)) score += pawnChainBonus;
      }
    }
    for (int f = 0; f < 8; f++) {
      for (final r in bRanks[f]) {
        if (_isChain(f, r, false, bRanks)) score -= pawnChainBonus;
      }
    }

    // Pawn islands
    score -= pawnIslandPenalty * _islands(wFiles);
    score += pawnIslandPenalty * _islands(bFiles);

    // Candidate passers
    for (int f = 0; f < 8; f++) {
      for (final r in wRanks[f]) {
        if (_isCandidate(f, r, true, wRanks, bRanks)) score += candidatePasserBonus;
      }
    }
    for (int f = 0; f < 8; f++) {
      for (final r in bRanks[f]) {
        if (_isCandidate(f, r, false, bRanks, wRanks)) score -= candidatePasserBonus;
      }
    }
    return score;
  }

  static bool _isPassed(int f, int r, bool w, List<List<int>> op) {
    for (int x = (f - 1).clamp(0, 7); x <= (f + 1).clamp(0, 7); x++) {
      for (final pr in op[x]) {
        if (w && pr < r) return false;
        if (!w && pr > r) return false;
      }
    }
    return true;
  }

  static bool _hasNeighbor(int f, List<int> files) {
    if (f > 0 && files.contains(f - 1)) return true;
    if (f < 7 && files.contains(f + 1)) return true;
    return false;
  }

  static bool _isBackward(int f, int r, bool w, List<int> files,
      List<List<int>> own, List<List<int>> op) {
    if (_hasNeighbor(f, files)) return false;
    bool blocked = false;
    for (int x = (f - 1).clamp(0, 7); x <= (f + 1).clamp(0, 7); x++) {
      if (x == f) continue;
      for (final pr in op[x]) {
        if (w && pr > r) { blocked = true; break; }
        if (!w && pr < r) { blocked = true; break; }
      }
      if (blocked) break;
    }
    if (!blocked) return false;
    for (final x in [f - 1, f + 1]) {
      if (x < 0 || x > 7) continue;
      if (own[x].any((pr) => w ? pr > r : pr < r)) return false;
    }
    return true;
  }

  static bool _isChain(int f, int r, bool w, List<List<int>> own) {
    for (final x in [f - 1, f + 1]) {
      if (x < 0 || x > 7) continue;
      if (own[x].any((pr) => w ? pr == r - 1 : pr == r + 1)) return true;
    }
    return false;
  }

  static int _islands(List<int> files) {
    if (files.isEmpty) return 0;
    final u = files.toSet().toList()..sort();
    int n = 1;
    for (int i = 1; i < u.length; i++) {
      if (u[i] > u[i - 1] + 1) n++;
    }
    return n;
  }

  static bool _isCandidate(int f, int r, bool w,
      List<List<int>> own, List<List<int>> op) {
    if (_isPassed(f, r, w, op)) return false;
    int oc = 0, mc = 0;
    for (int x = (f - 1).clamp(0, 7); x <= (f + 1).clamp(0, 7); x++) {
      for (final pr in op[x]) {
        if (w && pr > r) oc++;
        if (!w && pr < r) oc++;
      }
      mc += own[x].length;
    }
    return oc <= mc;
  }
  // -- King safety ---
  static int _evaluateKingSafety(chess.Chess board) {
    return _kingSafety(board, chess.Color.WHITE)
         - _kingSafety(board, chess.Color.BLACK);
  }

  static int _kingSafety(chess.Chess board, chess.Color color) {
    final ks = board.kings[color];
    if (ks < 0) return 0;
    final kf = chess.Chess.file(ks), kr = chess.Chess.rank(ks);
    final w = color == chess.Color.WHITE;
    int s = 0;

    // Pawn shield
    final sr = w ? kr - 1 : kr + 1;
    if (sr >= 0 && sr <= 7) {
      final base = sr * 16;
      for (int o = -1; o <= 1; o++) {
        final cf = kf + o;
        if (cf < 0 || cf > 7) continue;
        final p = board.board[base + cf];
        if (p?.type == chess.PieceType.PAWN && p?.color == color) s += kingPawnShieldBonus;
      }
    }

    // Second-rank shield for castled king
    if ((w && kr == 7) || (!w && kr == 0)) {
      final nr = w ? kr - 2 : kr + 2;
      if (nr >= 0 && nr <= 7) {
        final base = nr * 16;
        for (int o = -1; o <= 1; o++) {
          final cf = kf + o;
          if (cf < 0 || cf > 7) continue;
          final p = board.board[base + cf];
          if (p?.type == chess.PieceType.PAWN && p?.color == color) s += kingPawnShieldBonus ~/ 2;
        }
      }
    }

    // Open files near king
    for (int o = -1; o <= 1; o++) {
      final cf = kf + o;
      if (cf < 0 || cf > 7) continue;
      bool own = false, enemy = false;
      for (int r2 = 0; r2 < 8; r2++) {
        final p = board.board[r2 * 16 + cf];
        if (p?.type == chess.PieceType.PAWN) {
          if (p!.color == color) own = true; else enemy = true;
        }
      }
      if (!own && !enemy) s -= kingOpenFilePenalty;
      else if (!own && enemy) s -= kingStormFilePenalty;
    }

    // King exposure (moved from starting area)
    if ((w && kr < 5) || (!w && kr > 2)) s -= 10;
    return s;
  }

  // -- Rook activity ---
  static int _evaluateRookActivity(chess.Chess board) {
    int score = 0;
    final List<int> wR = [], bR = [];
    final List<bool> wP = List.filled(8, false), bP = List.filled(8, false);

    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p == null) continue;
        if (p.type == chess.PieceType.ROOK) {
          if (p.color == chess.Color.WHITE) wR.add(r * 8 + f);
          else bR.add(r * 8 + f);
        } else if (p.type == chess.PieceType.PAWN) {
          if (p.color == chess.Color.WHITE) wP[f] = true;
          else bP[f] = true;
        }
      }
    }

    for (final sq in wR) {
      final f = sq % 8, r_ = sq ~/ 8;
      if (!wP[f] && !bP[f]) score += rookOpenFileBonus;
      else if (!wP[f] && bP[f]) score += rookSemiOpenFileBonus;
      if (r_ == 6) score += rookSeventhRankBonus;
      if (wR.length >= 2) {
        final o = wR.firstWhere((s) => s != sq, orElse: () => -1);
        if (o >= 0 && (f == o % 8 || r_ == o ~/ 8)) score += rookConnectedBonus;
      }
    }
    for (final sq in bR) {
      final f = sq % 8, r_ = sq ~/ 8;
      if (!bP[f] && !wP[f]) score -= rookOpenFileBonus;
      else if (!bP[f] && wP[f]) score -= rookSemiOpenFileBonus;
      if (r_ == 1) score -= rookSeventhRankBonus;
      if (bR.length >= 2) {
        final o = bR.firstWhere((s) => s != sq, orElse: () => -1);
        if (o >= 0 && (f == o % 8 || r_ == o ~/ 8)) score -= rookConnectedBonus;
      }
    }
    return score;
  }

  // -- Knight evaluation ---
  static int _evaluateKnights(chess.Chess board) {
    int score = 0;
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p?.type != chess.PieceType.KNIGHT) continue;
        final w = p!.color == chess.Color.WHITE;
        int bonus = 0;
        if ((w && r <= 2) || (!w && r >= 5)) {
          if (_isOutpost(f, r, w, board)) bonus += knightOutpostBonus;
        }
        if (f == 0 || f == 7) bonus -= knightRimPenalty;
        if ((f == 3 || f == 4) && (r == 3 || r == 4)) bonus += knightCentralBonus;
        score += w ? bonus : -bonus;
      }
    }
    return score;
  }

  static bool _isOutpost(int f, int r, bool w, chess.Chess board) {
    for (int x = (f - 1).clamp(0, 7); x <= (f + 1).clamp(0, 7); x++) {
      for (int r2 = 0; r2 < 8; r2++) {
        final p = board.board[r2 * 16 + x];
        if (p?.type == chess.PieceType.PAWN && p?.color != (w ? chess.Color.WHITE : chess.Color.BLACK)) {
          if (w && r2 > r) return false;
          if (!w && r2 < r) return false;
        }
      }
    }
    return true;
  }

  // -- Bishop evaluation ---
  static int _evaluateBishops(chess.Chess board) {
    int score = 0;
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p?.type != chess.PieceType.BISHOP) continue;
        final w = p!.color == chess.Color.WHITE;
        int bonus = 0;
        if ((f - r).abs() <= 1) bonus += bishopLongDiagonalBonus;
        score += w ? bonus : -bonus;
      }
    }
    return score;
  }

  // -- Queen evaluation ---
  static int _evaluateQueen(chess.Chess board) {
    int score = 0;
    if (board.move_number < 8) {
      for (int r = 0; r < 8; r++) {
        final base = r * 16;
        for (int f = 0; f < 8; f++) {
          final p = board.board[base + f];
          if (p?.type != chess.PieceType.QUEEN) continue;
          if (p!.color == chess.Color.WHITE && !(r == 7 && f == 3)) {
            score -= queenEarlyDevelopmentPenalty;
          } else if (p.color == chess.Color.BLACK && !(r == 0 && f == 3)) {
            score += queenEarlyDevelopmentPenalty;
          }
        }
      }
    }
    return score;
  }

  // -- Center control ---
  static int _evaluateCenterControl(chess.Chess board) {
    int score = 0;
    const centers = [3, 4];
    const centerRanks = [3, 4];
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p == null || p.type == chess.PieceType.KING) continue;
        final inCenter = centers.contains(f) && centerRanks.contains(r);
        final w = p.color == chess.Color.WHITE;
        if (inCenter) {
          score += w ? centerOccupationBonus : -centerOccupationBonus;
        }
      }
    }
    return score;
  }
  // -- Endgame ---
  static int _evaluateEndgame(chess.Chess board) {
    int wMat = 0, bMat = 0;
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p == null || p.type == chess.PieceType.PAWN || p.type == chess.PieceType.KING) continue;
        if (p.color == chess.Color.WHITE) {
          wMat += _pieceValue(p.type);
        } else {
          bMat += _pieceValue(p.type);
        }
      }
    }

    final isEndgame = wMat <= 1300 && bMat <= 1300;
    if (!isEndgame) return 0;

    int score = 0;

    // King activity bonus
    final wk = board.kings[chess.Color.WHITE];
    final bk = board.kings[chess.Color.BLACK];
    if (wk >= 0) {
      final wkr = chess.Chess.rank(wk), wkf = chess.Chess.file(wk);
      if (wkr >= 2 && wkr <= 5 && wkf >= 2 && wkf <= 5) {
        score += kingEndgameActivityBonus;
      }
    }
    if (bk >= 0) {
      final bkr = chess.Chess.rank(bk), bkf = chess.Chess.file(bk);
      if (bkr >= 2 && bkr <= 5 && bkf >= 2 && bkf <= 5) {
        score -= kingEndgameActivityBonus;
      }
    }

    // Replace middlegame king PST with endgame king PST
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        final p = board.board[base + f];
        if (p?.type == chess.PieceType.KING) {
          final w = p!.color == chess.Color.WHITE;
          score += (_pst(kingEndGameTable, r, f, w) - _pst(kingMiddleGameTable, r, f, w)) * (w ? 1 : -1);
        }
      }
    }

    return score;
  }

  static int _pieceValue(chess.PieceType type) {
    if (type == chess.PieceType.PAWN) return pawnValue;
    if (type == chess.PieceType.KNIGHT) return knightValue;
    if (type == chess.PieceType.BISHOP) return bishopValue;
    if (type == chess.PieceType.ROOK) return rookValue;
    if (type == chess.PieceType.QUEEN) return queenValue;
    return 0;
  }

  // -- Mobility ---
  static int _evaluateMobility(chess.Chess board) {
    if (board.move_number <= 10) return 0;
    int totalPieces = 0;
    for (int r = 0; r < 8; r++) {
      final base = r * 16;
      for (int f = 0; f < 8; f++) {
        if (board.board[base + f] != null) totalPieces++;
      }
    }
    if (totalPieces > mobilityMaxPieces) return 0;

    final moves = board.moves({'verbose': true});
    int moveCount = moves.length;
    if (board.turn == chess.Color.WHITE) {
      return moveCount * mobilityWeight;
    } else {
      return -(moveCount * mobilityWeight);
    }
  }
}