import 'package:chess/chess.dart' as chess;

void main() {
  final board = chess.Chess();
  board.move('e4');

  // Verify copy exists
  try {
    final board2 = board.copy();
    print('board.copy() exists.');

    // Verify history preservation
    // board2 should have history containing e4
    final history = board2.history;
    print('board2 history length: ${history.length}');

    // undo on board2
    final undoResult = board2.undo();
    print('board2 undo result: $undoResult');
    print('board2 FEN after undo: ${board2.fen}');

    // board1 should be unaffected
    print('board1 FEN (should be after e4): ${board.fen}');

  } catch(e) {
    print('Error calling copy: $e');
  }
}
