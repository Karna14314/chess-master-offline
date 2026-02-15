import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

class PGNHandler {
  static GameState? parsePgn(String pgn) {
    try {
      final game = chess.Chess();
      if (!game.load_pgn(pgn)) {
        return null;
      }

      final moves = <ChessMove>[];
      // game.history returns List<State>
      for (final state in game.history) {
        if (state.move != null) {
          moves.add(ChessMove.fromChessMove(state.move, game));
        }
      }

      return GameState.fromFen(game.fen).copyWith(moveHistory: moves);
    } catch (e) {
      return null;
    }
  }

  static String exportPgn(GameState gameState) {
    // Replay moves to generate valid PGN
    final game = chess.Chess();

    for (final move in gameState.moveHistory) {
      final moveMap = {'from': move.from, 'to': move.to};
      if (move.promotion != null) {
        moveMap['promotion'] = move.promotion!;
      }
      game.move(moveMap);
    }

    return game.pgn();
  }
}
