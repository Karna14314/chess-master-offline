import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

class PGNHandler {
  static GameState? parsePgn(String pgn) {
    try {
      // 1. Load PGN into a temporary game to validate and get moves
      final tempGame = chess.Chess();
      if (!tempGame.load_pgn(pgn)) return null;

      // 2. Get SAN moves
      final sanMoves = tempGame.getHistory();

      // 3. Replay moves on a fresh board to build full history with FENs
      final game = chess.Chess();
      final moves = <ChessMove>[];

      for (final san in sanMoves) {
        game.move(san);

        // Get the last move object
        final history = game.getHistory({'verbose': true});
        final lastMoveMap = history.last as Map;

        // We can use the last move from game.history (State) for ChessMove construction,
        // as game is now in the state right after this move.
        // Or we can use the map values.
        // ChessMove.fromChessMove expects a Move object.
        // game.history.last.move is the Move object.

        final lastState = game.history.last;
        final move = (lastState as dynamic).move;

        moves.add(ChessMove.fromChessMove(move, game, san: san));
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
