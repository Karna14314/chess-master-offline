import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/game_model.dart';

void main() {
  test('ChessMove instantiation', () {
    const move = ChessMove(
      from: 'e2',
      to: 'e4',
      san: 'e4',
      isCapture: true,
      capturedPiece: 'p',
      isCheck: false,
      isCheckmate: false,
      isCastle: false,
      fen: '...',
    );

    expect(move.isCapture, true);
    expect(move.capturedPiece, 'p');

    final json = move.toJson();
    expect(json['capturedPiece'], 'p');

    final fromJson = ChessMove.fromJson(json);
    expect(fromJson.capturedPiece, 'p');
  });
}
