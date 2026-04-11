import 'dart:isolate';
import 'dart:math';
import 'package:chess/chess.dart' as chess;

/// Lightweight chess bot using bitboards and minimax with alpha-beta pruning
/// Designed to be fast and memory-efficient (~1MB)
class SimpleBotService {
  static SimpleBotService? _instance;

  static SimpleBotService get instance {
    _instance ??= SimpleBotService._();
    return _instance!;
  }

  SimpleBotService._();

  // Piece values (centipawns)
  static const int pawnValue = 100;
  static const int knightValue = 320;
  static const int bishopValue = 330;
  static const int rookValue = 500;
  static const int queenValue = 900;
  static const int kingValue = 20000;

  // Position tables for piece-square evaluation
  // Pawns - encourage center control and advancement
  static const List<int> pawnTable = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    50,
    50,
    50,
    50,
    50,
    50,
    50,
    50,
    10,
    10,
    20,
    30,
    30,
    20,
    10,
    10,
    5,
    5,
    10,
    25,
    25,
    10,
    5,
    5,
    0,
    0,
    0,
    20,
    20,
    0,
    0,
    0,
    5,
    -5,
    -10,
    0,
    0,
    -10,
    -5,
    5,
    5,
    10,
    10,
    -20,
    -20,
    10,
    10,
    5,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  // Knights - prefer center
  static const List<int> knightTable = [
    -50,
    -40,
    -30,
    -30,
    -30,
    -30,
    -40,
    -50,
    -40,
    -20,
    0,
    0,
    0,
    0,
    -20,
    -40,
    -30,
    0,
    10,
    15,
    15,
    10,
    0,
    -30,
    -30,
    5,
    15,
    20,
    20,
    15,
    5,
    -30,
    -30,
    0,
    15,
    20,
    20,
    15,
    0,
    -30,
    -30,
    5,
    10,
    15,
    15,
    10,
    5,
    -30,
    -40,
    -20,
    0,
    5,
    5,
    0,
    -20,
    -40,
    -50,
    -40,
    -30,
    -30,
    -30,
    -30,
    -40,
    -50,
  ];

  // Bishops - prefer center and long diagonals
  static const List<int> bishopTable = [
    -20,
    -10,
    -10,
    -10,
    -10,
    -10,
    -10,
    -20,
    -10,
    0,
    0,
    0,
    0,
    0,
    0,
    -10,
    -10,
    0,
    5,
    10,
    10,
    5,
    0,
    -10,
    -10,
    5,
    5,
    10,
    10,
    5,
    5,
    -10,
    -10,
    0,
    10,
    10,
    10,
    10,
    0,
    -10,
    -10,
    10,
    10,
    10,
    10,
    10,
    10,
    -10,
    -10,
    5,
    0,
    0,
    0,
    0,
    5,
    -10,
    -20,
    -10,
    -10,
    -10,
    -10,
    -10,
    -10,
    -20,
  ];

  // Rooks - prefer 7th rank and open files
  static const List<int> rookTable = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    5,
    10,
    10,
    10,
    10,
    10,
    10,
    5,
    -5,
    0,
    0,
    0,
    0,
    0,
    0,
    -5,
    -5,
    0,
    0,
    0,
    0,
    0,
    0,
    -5,
    -5,
    0,
    0,
    0,
    0,
    0,
    0,
    -5,
    -5,
    0,
    0,
    0,
    0,
    0,
    0,
    -5,
    -5,
    0,
    0,
    0,
    0,
    0,
    0,
    -5,
    0,
    0,
    0,
    5,
    5,
    0,
    0,
    0,
  ];

  // Queen - slight center preference
  static const List<int> queenTable = [
    -20,
    -10,
    -10,
    -5,
    -5,
    -10,
    -10,
    -20,
    -10,
    0,
    0,
    0,
    0,
    0,
    0,
    -10,
    -10,
    0,
    5,
    5,
    5,
    5,
    0,
    -10,
    -5,
    0,
    5,
    5,
    5,
    5,
    0,
    -5,
    0,
    0,
    5,
    5,
    5,
    5,
    0,
    -5,
    -10,
    5,
    5,
    5,
    5,
    5,
    0,
    -10,
    -10,
    0,
    5,
    0,
    0,
    0,
    0,
    -10,
    -20,
    -10,
    -10,
    -5,
    -5,
    -10,
    -10,
    -20,
  ];

  // King middlegame - stay safe
  static const List<int> kingMiddleGameTable = [
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -20,
    -30,
    -30,
    -40,
    -40,
    -30,
    -30,
    -20,
    -10,
    -20,
    -20,
    -20,
    -20,
    -20,
    -20,
    -10,
    20,
    20,
    0,
    0,
    0,
    0,
    20,
    20,
    20,
    30,
    10,
    0,
    0,
    10,
    30,
    20,
  ];

  /// Get best move for the current position
  /// [fen] - Position in FEN notation
  /// [depth] - Search depth (1-4 recommended for fallback engine)
  Future<SimpleBotResult> getBestMove({
    required String fen,
    int depth = 3,
  }) async {
    // Cap depth at 3 for fallback engine to ensure ANR-safe response (<5s)
    final effectiveDepth = min(depth, 3);

    // Run compute-heavy work in separate isolate to prevent main thread blocking
    return Isolate.run(() => _getBestMoveSync(fen, effectiveDepth));
  }

  /// Synchronous computation - depth capped to prevent ANR
  SimpleBotResult _getBestMoveSync(String fen, int depth) {
    final board = chess.Chess.fromFEN(fen);

    // Get all legal moves
    final moves = board.moves({'verbose': true});
    if (moves.isEmpty) {
      return SimpleBotResult(bestMove: '', evaluation: 0);
    }

    // For very low depth, just pick a random legal move
    if (depth <= 1) {
      final randomMove = moves[Random().nextInt(moves.length)] as Map;
      final from = randomMove['from'] as String;
      final to = randomMove['to'] as String;
      final promotion = randomMove['promotion']?.toString();
      return SimpleBotResult(
        bestMove: '$from$to${promotion ?? ''}',
        evaluation: 0,
      );
    }

    // Run minimax with alpha-beta pruning
    String? bestMove;
    int bestEval = -999999;
    final isMaximizing = board.turn == chess.Color.WHITE;

    for (final move in moves) {
      final m = move as Map;
      final moveStr = '${m['from']}${m['to']}${m['promotion'] ?? ''}';

      // Make move
      board.move(m);

      // Evaluate position
      final eval = _minimax(board, depth - 1, -999999, 999999, !isMaximizing);

      // Undo move
      board.undo();

      // Update best move
      if (isMaximizing) {
        if (eval > bestEval) {
          bestEval = eval;
          bestMove = moveStr;
        }
      } else {
        if (eval < bestEval || bestMove == null) {
          bestEval = eval;
          bestMove = moveStr;
        }
      }
    }

    return SimpleBotResult(bestMove: bestMove ?? '', evaluation: bestEval);
  }

  /// Minimax algorithm with alpha-beta pruning
  int _minimax(
    chess.Chess board,
    int depth,
    int alpha,
    int beta,
    bool isMaximizing,
  ) {
    // Terminal conditions
    if (depth == 0) {
      return _evaluatePosition(board);
    }

    if (board.in_checkmate) {
      return isMaximizing ? -999999 : 999999;
    }

    if (board.in_stalemate || board.in_draw) {
      return 0;
    }

    final moves = board.moves({'verbose': true});
    if (moves.isEmpty)
      return 0; // Should be handled by game_over but safety check

    // Move Ordering
    moves.sort((a, b) {
      final mapA = a as Map;
      final mapB = b as Map;
      if (mapA['captured'] != null && mapB['captured'] == null) return -1;
      if (mapA['captured'] == null && mapB['captured'] != null) return 1;
      return 0;
    });

    int value = -1000000000;

    for (final move in moves) {
      board.move(move as Map);
      int score = -_minimax(board, depth - 1, -beta, -alpha, !isMaximizing);
      board.undo();

      if (score >= beta) return beta; // Pruning
      if (score > value) value = score;
      if (score > alpha) alpha = score;
    }

    return value;
  }

  /// Evaluate the current board position (material + piece-square tables + king safety)
  int _evaluatePosition(chess.Chess board) {
    int score = 0;

    // Material and position evaluation
    for (int rank = 0; rank < 8; rank++) {
      final baseIndex = rank * 16;
      for (int file = 0; file < 8; file++) {
        final index = baseIndex + file;
        final piece = board.board[index];

        if (piece != null) {
          final isWhite = piece.color == chess.Color.WHITE;
          final multiplier = isWhite ? 1 : -1;

          // Material value
          int materialValue = 0;
          int positionValue = 0;

          switch (piece.type) {
            case chess.PieceType.PAWN:
              materialValue = pawnValue;
              positionValue = _getPositionValue(pawnTable, rank, file, isWhite);
              break;
            case chess.PieceType.KNIGHT:
              materialValue = knightValue;
              positionValue = _getPositionValue(
                knightTable,
                rank,
                file,
                isWhite,
              );
              break;
            case chess.PieceType.BISHOP:
              materialValue = bishopValue;
              positionValue = _getPositionValue(
                bishopTable,
                rank,
                file,
                isWhite,
              );
              break;
            case chess.PieceType.ROOK:
              materialValue = rookValue;
              positionValue = _getPositionValue(rookTable, rank, file, isWhite);
              break;
            case chess.PieceType.QUEEN:
              materialValue = queenValue;
              positionValue = _getPositionValue(
                queenTable,
                rank,
                file,
                isWhite,
              );
              break;
            case chess.PieceType.KING:
              materialValue = kingValue;
              positionValue = _getPositionValue(
                kingMiddleGameTable,
                rank,
                file,
                isWhite,
              );
              break;
          }

          score += multiplier * (materialValue + positionValue);
        }
      }
    }

    // King safety bonus
    score += _evaluateKingSafety(board, chess.Color.WHITE);
    score -= _evaluateKingSafety(board, chess.Color.BLACK);

    return score;
  }

  /// Get position value from piece-square table
  int _getPositionValue(List<int> table, int rank, int file, bool isWhite) {
    // For black pieces, flip the table vertically
    final tableIndex = isWhite ? (7 - rank) * 8 + file : rank * 8 + file;
    return table[tableIndex];
  }

  /// Evaluate king safety (pawn shield)
  int _evaluateKingSafety(chess.Chess board, chess.Color color) {
    int safety = 0;

    // Find king position
    String? kingSquare;
    for (int rank = 0; rank < 8; rank++) {
      final baseIndex = rank * 16;
      for (int file = 0; file < 8; file++) {
        final index = baseIndex + file;
        final piece = board.board[index];
        if (piece?.type == chess.PieceType.KING && piece?.color == color) {
          kingSquare = _indexToSquare(rank * 8 + file);
          break;
        }
      }
      if (kingSquare != null) break;
    }

    if (kingSquare == null) return 0;

    // Check for pawn shield
    final isWhite = color == chess.Color.WHITE;
    final kingFile = kingSquare.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final kingRank = int.parse(kingSquare[1]);

    // Check pawns in front of king
    final shieldRank = isWhite ? kingRank + 1 : kingRank - 1;
    if (shieldRank >= 1 && shieldRank <= 8) {
      final rankIndex = 8 - shieldRank;
      final baseIndex = rankIndex * 16;
      for (int fileOffset = -1; fileOffset <= 1; fileOffset++) {
        final checkFile = kingFile + fileOffset;
        if (checkFile >= 0 && checkFile < 8) {
          final piece = board.board[baseIndex + checkFile];
          if (piece?.type == chess.PieceType.PAWN && piece?.color == color) {
            safety += 10;
          }
        }
      }
    }

    return safety;
  }

  /// Convert board index to algebraic square notation
  String _indexToSquare(int index) {
    final file = index % 8;
    final rank = 8 - (index ~/ 8);
    return '${String.fromCharCode('a'.codeUnitAt(0) + file)}$rank';
  }
}

/// Result from simple bot calculation
class SimpleBotResult {
  final String bestMove;
  final int evaluation;

  SimpleBotResult({required this.bestMove, required this.evaluation});

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
