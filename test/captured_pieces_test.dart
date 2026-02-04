import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/utils/pgn_handler.dart';

void main() {
  group('Captured Pieces Tests', () {
    test('ChessMove stores captured piece', () {
      final game = chess.Chess();
      game.move({'from': 'e2', 'to': 'e4'});
      game.move({'from': 'd7', 'to': 'd5'});

      // Capture
      game.move({'from': 'e4', 'to': 'd5'});

      // Check last move in history
      final lastState = game.history.last;
      final move = (lastState as dynamic).move;

      // Pass 'san' explicitly because game state is post-move
      final chessMove = ChessMove.fromChessMove(move, game, san: 'exd5');

      expect(chessMove.isCapture, isTrue);
      expect(chessMove.capturedPiece, equals('p'));
    });

    test('PGNHandler correctly parses captured pieces', () {
      final game = chess.Chess();
      game.move({'from': 'e2', 'to': 'e4'});
      game.move({'from': 'd7', 'to': 'd5'});
      game.move({'from': 'e4', 'to': 'd5'});

      final pgn = game.pgn();
      // PGNHandler.parsePgn needs the PGN string
      final gameState = PGNHandler.parsePgn(pgn);

      expect(gameState, isNotNull);
      expect(gameState!.moveHistory.length, equals(3));

      final lastMove = gameState.moveHistory.last;
      expect(lastMove.isCapture, isTrue);
      expect(lastMove.capturedPiece, equals('p'));
    });

    test('Calculate material advantage logic', () {
       // Simulate move history with valid FEN parts for turn checking
       final history = <ChessMove>[
          // 1. e4 (Next: Black 'b')
          const ChessMove(from: 'e2', to: 'e4', san: 'e4', isCapture: false, isCheck: false, isCheckmate: false, isCastle: false, fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1'),
          // 1... d5 (Next: White 'w')
          const ChessMove(from: 'd7', to: 'd5', san: 'd5', isCapture: false, isCheck: false, isCheckmate: false, isCastle: false, fen: 'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2'),
          // 2. exd5 (White captures Pawn) (Next: Black 'b')
          const ChessMove(from: 'e4', to: 'd5', san: 'exd5', capturedPiece: 'p', isCapture: true, isCheck: false, isCheckmate: false, isCastle: false, fen: 'rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 2'),
       ];

       final whiteCaptured = <String>[];
       final blackCaptured = <String>[];

       for (int i = 0; i < history.length; i++) {
         final move = history[i];
         if (move.capturedPiece != null) {
           final fenParts = move.fen.split(' ');
           final isWhiteMove = fenParts.length > 1 && fenParts[1] == 'b';

           if (isWhiteMove) {
             // White moved
             whiteCaptured.add('b${move.capturedPiece}');
           } else {
             blackCaptured.add('w${move.capturedPiece}');
           }
         }
       }

       expect(whiteCaptured, contains('bp')); // White captured Black Pawn
       expect(blackCaptured, isEmpty);

       // Material values
       int getValue(String piece) {
         final type = piece.substring(1).toLowerCase();
         switch (type) {
           case 'p': return 1;
           default: return 0;
         }
       }

       int whiteScore = whiteCaptured.fold(0, (sum, p) => sum + getValue(p));
       int blackScore = blackCaptured.fold(0, (sum, p) => sum + getValue(p));

       expect(whiteScore, 1);
       expect(blackScore, 0);
       expect(whiteScore - blackScore, 1);
    });
  });
}
