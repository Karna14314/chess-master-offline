import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/opening_book_service.dart';

void main() {
  test('classifyMove detects book moves', () {
    final startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -';
    final move = 'e2e4'; // Standard opening

    final classification = classifyMove(
      evalBefore: 0.0,
      evalAfter: 0.0,
      isWhiteMove: true,
      bestMove: null,
      actualMove: move,
      fenBefore: startFen,
    );

    expect(classification, equals(MoveClassification.book));
  });

  test('classifyMove detects best moves when not in book', () {
    final classification = classifyMove(
      evalBefore: 0.0,
      evalAfter: 0.0,
      isWhiteMove: true,
      bestMove: 'e2e4',
      actualMove: 'e2e4',
      fenBefore: '8/8/8/8/8/8/8/8 w - - 0 1', // Empty board, not in book
    );

    expect(classification, equals(MoveClassification.best));
  });

  test('classifyMove detects mistakes', () {
    final classification = classifyMove(
      evalBefore: 1.0, // +1.0 (White advantage)
      evalAfter: 0.0,  // 0.0 (Equal)
      isWhiteMove: true,
      bestMove: 'e2e4',
      actualMove: 'a2a3', // Bad move
      fenBefore: '8/8/8/8/8/8/8/8 w - - 0 1', // Not in book
    );

    // Loss is 1.0 -> Mistake
    expect(classification, equals(MoveClassification.mistake));
  });
}
