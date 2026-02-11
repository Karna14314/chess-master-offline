import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

class PGNHandler {
  static GameState? parsePgn(String pgn) {
    try {
      final game = chess.Chess();
      if (!game.load_pgn(pgn)) return null;

      final moves = <ChessMove>[];
      for (final state in game.history) {
        moves.add(ChessMove.fromChessMove(state.move, game));
      }

      return GameState.fromFen(game.fen).copyWith(moveHistory: moves);
    } catch (e) {
      return null;
    }
  }

  static String exportPgn(GameState gameState) {
    final game = chess.Chess.fromFEN(gameState.fen);
    return game.pgn() ?? '';
  }
}
