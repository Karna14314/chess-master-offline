import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/constants/app_constants.dart';

class PGNHandler {
  static GameSession? parsePgn(String pgn) {
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
                (m['flags']?.toString().contains('k') ?? false) ||
                (m['flags']?.toString().contains('q') ?? false),
            fen: game.fen,
          ),
        );
      }

      return GameSession.create(
        gameMode: GameMode.localMultiplayer,
        startingFen: game.fen,
      ).copyWith(moveHistory: moves);
    } catch (e) {
      return null;
    }
  }

  static String exportPgn(dynamic gameState) {
    if (gameState is GameSession) {
      return gameState.pgn;
    }
    final game = chess.Chess.fromFEN(gameState.fen);
    return game.pgn();
  }
}
