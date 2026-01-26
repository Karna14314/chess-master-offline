import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

class PGNHandler {
  static GameState? parsePgn(String pgn) {
    try {
      final game = chess.Chess.fromPgn(pgn);
      if (game == null) return null;

      final moves = <ChessMove>[];
      for (final move in game.history) {
        moves.add(ChessMove.fromChessMove(move, game));
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
