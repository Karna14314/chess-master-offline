import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';

/// Service for basic position evaluation without a heavy engine
class BasicEvaluatorService {
  static final BasicEvaluatorService _instance = BasicEvaluatorService._();
  static BasicEvaluatorService get instance => _instance;

  BasicEvaluatorService._();

  // Piece values (Centipawns)
  static const int pawnValue = 100;
  static const int knightValue = 320;
  static const int bishopValue = 330;
  static const int rookValue = 500;
  static const int queenValue = 900;
  static const int kingValue = 20000;

  // PSTs (from white's perspective, a8..h1 i.e. 0..63)
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

  /// Evaluate the position and return centipawns
  int evaluate(String fen) {
    final board = chess.Chess.fromFEN(fen);
    return _evaluateBoard(board);
  }

  /// Analyze position and return analysis result
  Future<AnalysisResult> analyze(String fen) async {
    final eval = evaluate(fen);

    // Get best move from lightweight engine to show at least one line
    String bestMove = '';
    try {
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 1,
      );
      bestMove = result.bestMove;
    } catch (e) {
      // Ignore
    }

    final lines = <EngineLine>[];
    if (bestMove.isNotEmpty) {
      // We don't have the full PV (sequence of moves), just the best move
      // But we can try to make a dummy sequence
      lines.add(
        EngineLine(
          rank: 1,
          evaluation: eval / 100.0,
          depth: 1,
          moves: [bestMove], // Minimal PV
        ),
      );
    }

    return AnalysisResult(evaluation: eval, lines: lines, depth: 1);
  }

  int _evaluateBoard(chess.Chess board) {
    if (board.in_checkmate) {
      return board.turn == chess.Color.WHITE ? -20000 : 20000;
    }
    if (board.in_draw) {
      return 0;
    }

    int whiteScore = 0;
    int blackScore = 0;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final rankIndex = 8 - r;
        final fileChar = String.fromCharCode('a'.codeUnitAt(0) + c);
        final square = '$fileChar$rankIndex';

        final piece = board.get(square);
        if (piece == null) continue;

        int material = 0;
        int pst = 0;
        final int sqIdx = r * 8 + c;

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
            break;
        }

        if (piece.color == chess.Color.WHITE) {
          whiteScore += material + pst;
        } else {
          // Mirror for black
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

    // Return relative evaluation for white
    // Stockfish returns centipawns relative to side to move usually,
    // but here we return relative to White?
    // Stockfish "score cp" is usually from the engine's perspective (side to move)
    // BUT standard UCI protocol says "score cp <x>" is from the engine's point of view.
    // However, most GUIs expect white-relative or side-relative.
    // Stockfish outputs side-relative evaluation.
    // If it's black's turn and score is +100, it means black is winning.
    // My UI expects:
    // "Positive evalLoss means the move was worse than optimal"
    // "evalBefore - evalAfter"
    // Usually eval is stored as White-relative in UI models for graphing.
    // Let's check AnalysisProvider again.
    // "result.evalInPawns".

    final eval = whiteScore - blackScore;

    // If I return white-relative score, I should check how AnalysisProvider handles it.
    // AnalysisProvider:
    // "final isWhiteMove = board.turn == chess.Color.WHITE;"
    // "evalLoss = isWhiteMove ? evalBefore - evalAfter : evalAfter - evalBefore;"
    // This implies eval is White-relative. (If white moves and eval drops from 1.0 to 0.5, loss is 0.5. If black moves and eval goes from 0.5 to 1.0 (black improved white's position?? No).
    // If eval is white relative: +1.0 (White winning). Black moves. +1.0 -> +0.5 (Black improved his position).
    // Black wants to minimize the score.
    // evalAfter - evalBefore = 0.5 - 1.0 = -0.5.
    // "evalLoss = evalAfter - evalBefore" => -0.5.
    // "Positive evalLoss means the move was worse". -0.5 is better. Correct.
    // So Eval must be White-relative.

    return eval;
  }
}
