import 'dart:math';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/models/chess_models.dart';

/// A lightweight chess engine written in Dart
class LightweightEngineService {
  static final LightweightEngineService _instance =
      LightweightEngineService._();
  static LightweightEngineService get instance => _instance;

  LightweightEngineService._();

  // Piece values (Centipawns)
  static const int pawnValue = 100;
  static const int knightValue = 320;
  static const int bishopValue = 330;
  static const int rookValue = 500;
  static const int queenValue = 900;
  static const int kingValue = 20000;

  // PSTs (from white's perspective, a8..h1 i.e. 0..63)
  // Higher is better.
  static const List<int> pawnPst = [
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

  static const List<int> knightPst = [
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

  static const List<int> bishopPst = [
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

  // Transposition Table (Simple Map)
  final Map<String, int> _transpositionTable = {};

  // Simple Opening Book
  final Map<String, String> _openingBook = {
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1': 'e2e4',
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1': 'e7e5',
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2': 'g1f3',
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': 'b8c6',
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3':
        'f1b5', // Ruy Lopez
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1': 'd7d5',
    'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2':
        'c2c4', // Queen's Gambit
  };

  Future<BestMoveResult> getBestMove(String fen, int depth) async {
    // 1. Check Opening Book
    if (_openingBook.containsKey(fen)) {
      return BestMoveResult(bestMove: _openingBook[fen]!, evaluation: 0);
    }

    final board = chess.Chess.fromFEN(fen);

    // Cap depth to ensure responsiveness (Dart is slower than C++)
    final effectiveDepth = min(depth, 4);

    // Iterative Deepening (Simplified: just run at effective depth)

    String? bestMove;
    int bestValue = -999999999;

    final moves = board.moves({'verbose': true});
    if (moves.isEmpty) return BestMoveResult(bestMove: '', evaluation: 0);

    // Simple Move Ordering: Captures first
    moves.sort((a, b) {
      final mapA = a as Map;
      final mapB = b as Map;
      if (mapA['captured'] != null && mapB['captured'] == null) return -1;
      if (mapA['captured'] == null && mapB['captured'] != null) return 1;
      return 0;
    });

    for (final move in moves) {
      final mapMove = move as Map;
      board.move(mapMove);
      // Negamax: value is - (value for opponent)
      int value = -_negaMax(board, effectiveDepth - 1, -1000000000, 1000000000);
      board.undo();

      if (value > bestValue) {
        bestValue = value;
        bestMove = _mapMoveToUci(mapMove);
      }
    }

    return BestMoveResult(bestMove: bestMove ?? '', evaluation: bestValue);
  }

  int _negaMax(chess.Chess board, int depth, int alpha, int beta) {
    if (depth == 0) {
      return _evaluate(board);
    }

    // Check Game Over
    if (board.game_over) {
      if (board.in_checkmate) {
        // Prefer shorter mates: larger score for closer mate
        return -1000000 + (100 - depth); // e.g. -999900
      }
      return 0; // Stalemate / Draw
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
      int score = -_negaMax(board, depth - 1, -beta, -alpha);
      board.undo();

      if (score >= beta) return beta; // Pruning
      if (score > value) value = score;
      if (score > alpha) alpha = score;
    }

    return value;
  }

  int _evaluate(chess.Chess board) {
    int whiteScore = 0;
    int blackScore = 0;

    // Material and Position
    for (int r = 0; r < 8; r++) {
      // 0..7 (Rank 8..1)
      for (int c = 0; c < 8; c++) {
        // 0..7 (File a..h)
        final rankIndex = 8 - r;
        final fileChar = String.fromCharCode('a'.codeUnitAt(0) + c);
        final square = '$fileChar$rankIndex';

        final piece = board.get(square);
        if (piece == null) continue;

        int material = 0;
        int pst = 0;
        final int sqIdx = r * 8 + c; // 0..63

        switch (piece.type) {
          case chess.PieceType.PAWN:
            material = pawnValue;
            pst = pawnPst[sqIdx];
            break;
          case chess.PieceType.KNIGHT:
            material = knightValue;
            pst = knightPst[sqIdx];
            break;
          case chess.PieceType.BISHOP:
            material = bishopValue;
            pst = bishopPst[sqIdx];
            break;
          case chess.PieceType.ROOK:
            material = rookValue;
            break;
          case chess.PieceType.QUEEN:
            material = queenValue;
            break;
          case chess.PieceType.KING:
            material = kingValue;
            // King Safety / Endgame logic (simplified)
            // PST could be added here
            break;
        }

        if (piece.color == chess.Color.WHITE) {
          whiteScore += material + pst;
        } else {
          // Flip for black (mirror vertically)
          // Index: (7-r)*8 + c
          final mirroredIdx = (7 - r) * 8 + c;
          int blackPst = 0;
          switch (piece.type) {
            case chess.PieceType.PAWN:
              blackPst = pawnPst[mirroredIdx];
              break;
            case chess.PieceType.KNIGHT:
              blackPst = knightPst[mirroredIdx];
              break;
            case chess.PieceType.BISHOP:
              blackPst = bishopPst[mirroredIdx];
              break;
            default:
              break;
          }
          blackScore += material + blackPst;
        }
      }
    }

    int eval = whiteScore - blackScore;

    // Mop-up Evaluation (Endgame)
    // If we have winning advantage, push enemy king to edge
    if (eval > 500) {
      // White winning -> push Black King to edge
      // Distance from center
      // ... (logic skipped for brevity/complexity balance in lightweight)
    } else if (eval < -500) {
      // Black winning
    }

    return board.turn == chess.Color.WHITE ? eval : -eval;
  }

  String _mapMoveToUci(Map move) {
    String uci = '${move['from']}${move['to']}';
    if (move['promotion'] != null) {
      uci += move['promotion'];
    }
    return uci;
  }
}
