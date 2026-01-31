import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess/chess.dart' as chess;

void main() {
  test('Captured pieces logic', () {
    // Simulate moves:
    // 1. e4 d5
    // 2. exd5 (White captures Black Pawn 'p')
    // 3. Qxd5 (Black captures White Pawn 'P')

    // We can just construct ChessMoves manually with capturedPiece set
    final moves = [
      ChessMove(
        from: 'e2', to: 'e4', san: 'e4',
        isCapture: false, isCheck: false, isCheckmate: false, isCastle: false, fen: '...'
      ), // White move 0
      ChessMove(
        from: 'd7', to: 'd5', san: 'd5',
        isCapture: false, isCheck: false, isCheckmate: false, isCastle: false, fen: '...'
      ), // Black move 1
      ChessMove(
        from: 'e4', to: 'd5', san: 'exd5',
        capturedPiece: 'p', // Captures Black Pawn
        isCapture: true, isCheck: false, isCheckmate: false, isCastle: false, fen: '...'
      ), // White move 2
      ChessMove(
        from: 'd8', to: 'd5', san: 'Qxd5',
        capturedPiece: 'p', // Captures White Pawn
        isCapture: true, isCheck: false, isCheckmate: false, isCastle: false, fen: '...'
      ), // Black move 3
    ];

    final whiteCaptures = <String>[];
    final blackCaptures = <String>[];

    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      if (move.capturedPiece != null) {
        if (i % 2 == 0) {
          // White captured a black piece
          whiteCaptures.add('b${move.capturedPiece!.toUpperCase()}');
        } else {
          // Black captured a white piece
          blackCaptures.add('w${move.capturedPiece!.toUpperCase()}');
        }
      }
    }

    expect(whiteCaptures, contains('bP'));
    expect(blackCaptures, contains('wP'));

    // Test sorting logic
    // Add more captures
    // White captures: Rook, Bishop.
    // Order added: P, R, B.
    // Sorted Order expected: P, B, R.
    whiteCaptures.clear();
    whiteCaptures.add('bR'); // 4
    whiteCaptures.add('bB'); // 3
    whiteCaptures.add('bP'); // 1

     int getPieceValue(String pieceCode) {
      final type = pieceCode.substring(1);
      switch (type) {
        case 'P': return 1;
        case 'N': return 2;
        case 'B': return 3;
        case 'R': return 4;
        case 'Q': return 5;
        default: return 0;
      }
    }

    whiteCaptures.sort((a, b) => getPieceValue(a).compareTo(getPieceValue(b)));

    expect(whiteCaptures, ['bP', 'bB', 'bR']);
  });
}
