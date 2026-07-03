import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/position_evaluator.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';

/// Service for basic position evaluation without a heavy engine
class BasicEvaluatorService {
  static final BasicEvaluatorService _instance = BasicEvaluatorService._();
  static BasicEvaluatorService get instance => _instance;

  BasicEvaluatorService._();

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
    return PositionEvaluator.evaluate(board);
  }
}
