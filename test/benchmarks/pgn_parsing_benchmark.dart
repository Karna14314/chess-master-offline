import 'package:chess/chess.dart' as chess;
import 'dart:math';

// Original implementation
List<Map<String, dynamic>>? parsePgnToMovesOriginal(String pgn) {
  try {
    final tempBoard = chess.Chess();
    if (!tempBoard.load_pgn(pgn)) return null;

    final history = tempBoard.getHistory();
    if (history.isEmpty) return null;

    final moves = <Map<String, dynamic>>[];
    final replayBoard = chess.Chess();

    for (var h in history) {
      final san = h.toString();
      final success = replayBoard.move(san);
      if (!success) return null;

      final lastVerbose =
          replayBoard.getHistory({'verbose': true}).last as Map;

      // Simulating the construction of ChessMove object by using Map for now
      moves.add({
        'from': lastVerbose['from'] as String,
        'to': lastVerbose['to'] as String,
        'san': san,
        'promotion': lastVerbose['promotion']?.toString(),
        'capturedPiece': lastVerbose['captured']?.toString(),
        'fen': replayBoard.fen,
      });
    }
    return moves;
  } catch (e) {
    return null;
  }
}

// Optimized implementation (proposed)
List<Map<String, dynamic>>? parsePgnToMovesOptimized(String pgn) {
  try {
    final tempBoard = chess.Chess();
    if (!tempBoard.load_pgn(pgn)) return null;

    final history = tempBoard.getHistory();
    if (history.isEmpty) return null;

    final moves = <Map<String, dynamic>>[];
    final replayBoard = chess.Chess();

    for (var h in history) {
      final san = h.toString();
      final success = replayBoard.move(san);
      if (!success) return null;

      final state = replayBoard.history.last;
      final move = state.move;

      moves.add({
        'from': _algebraic(move.from),
        'to': _algebraic(move.to),
        'san': san,
        'promotion': move.promotion?.toString(),
        'capturedPiece': move.captured?.toString(),
        'fen': replayBoard.fen,
      });
    }
    return moves;
  } catch (e) {
    return null;
  }
}

String _algebraic(int i) {
  final f = i & 15;
  final r = i >> 4;
  return '${String.fromCharCode(97 + f)}${8 - r}';
}

void main() {
  // Generate a long game PGN (approximate)
  // We'll use a known long game or just repeat moves if possible (though repetition draw might kick in)
  // Let's use a sample long PGN.
  // Game: 1. e4 e5 2. Nf3 Nc6 ...
  // Actually, we can generate random legal moves for N moves.

  print('Generating game...');
  final game = chess.Chess();
  final random = Random(42);

  // Create a game with 100 moves (200 half-moves)
  while (game.history.length < 200 && !game.game_over) {
    final moves = game.moves();
    if (moves.isEmpty) break;
    final move = moves[random.nextInt(moves.length)];
    game.move(move);
  }

  final pgn = game.pgn();
  print('Game generated with ${game.history.length} half-moves.');

  // Benchmark Original
  final stopwatch = Stopwatch()..start();
  parsePgnToMovesOriginal(pgn);
  final originalTime = stopwatch.elapsedMilliseconds;
  print('Original implementation: ${originalTime}ms');

  // Benchmark Optimized
  stopwatch.reset();
  parsePgnToMovesOptimized(pgn);
  final optimizedTime = stopwatch.elapsedMilliseconds;
  print('Optimized implementation: ${optimizedTime}ms');

  if (originalTime > 0) {
      print('Speedup: ${(originalTime / optimizedTime).toStringAsFixed(2)}x');
  }

  // Verify correctness
  final movesOrig = parsePgnToMovesOriginal(pgn);
  final movesOpt = parsePgnToMovesOptimized(pgn);

  if (movesOrig?.length != movesOpt?.length) {
    print('Mismatch in length!');
    return;
  }

  for (int i = 0; i < movesOrig!.length; i++) {
    final m1 = movesOrig[i];
    final m2 = movesOpt![i];

    if (m1['from'] != m2['from'] || m1['to'] != m2['to'] || m1['capturedPiece'] != m2['capturedPiece']) {
       print('Mismatch at move $i:');
       print('Original: $m1');
       print('Optimized: $m2');
       return;
    }
  }
  print('Verification passed!');
}
