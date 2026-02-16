import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

class PGNHandler {
  static GameState? parsePgn(String pgn) {
    try {
      final game = chess.Chess();
      game.load_pgn(pgn);

      final moves = <ChessMove>[];
      final history = game.getHistory({'verbose': true});
      for (final move in history) {
        final m = move as Map;
        moves.add(
          ChessMove(
            from: m['from'] as String,
            to: m['to'] as String,
            san: m['san'] as String,
            promotion: m['promotion']?.toString(),
            capturedPiece: m['captured']?.toString(),
            isCapture: m['captured'] != null,
            isCheck: m['flags']?.toString().contains('+') ?? false,
            isCheckmate: m['flags']?.toString().contains('#') ?? false,
            isCastle:
                m['flags']?.toString().contains('k') ??
                false || m['flags']?.toString().contains('q') ??
                false,
            fen: game.fen,
          ),
        );
      }

      return GameState.fromFen(game.fen).copyWith(moveHistory: moves);
    } catch (e) {
      return null;
    }
  }

  static String exportPgn(GameState gameState) {
    final game = chess.Chess.fromFEN(gameState.fen);
    return game.pgn;
  }
}
