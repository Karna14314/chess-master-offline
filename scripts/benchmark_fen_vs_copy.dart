import 'package:chess/chess.dart' as chess;

void main() {
  print('Running benchmark: chess.Chess.fromFEN(fen) vs game.copy()');

  final game = chess.Chess();
  // Create a game state with some history/moves to be realistic
  game.move({'from': 'e2', 'to': 'e4'});
  game.move({'from': 'e7', 'to': 'e5'});
  game.move({'from': 'g1', 'to': 'f3'});
  game.move({'from': 'b8', 'to': 'c6'});
  game.move({'from': 'f1', 'to': 'c4'});
  game.move({'from': 'f8', 'to': 'c5'});

  const iterations = 50000;

  print('Testing $iterations iterations...');

  // Benchmark 1: Current approach (fromFEN)
  // This simulates retrieving FEN (which generates string) and parsing it
  final stopwatchFen = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    // Current code does: final board = chess.Chess.fromFEN(state.fen);
    // state.fen calls board.fen which generates the string.
    chess.Chess.fromFEN(game.fen);
  }
  stopwatchFen.stop();
  print('Method 1 (fromFEN): ${stopwatchFen.elapsedMilliseconds} ms');
  print('  Avg per op: ${(stopwatchFen.elapsedMicroseconds / iterations).toStringAsFixed(2)} us');

  // Benchmark 2: Optimized approach (copy)
  final stopwatchCopy = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    game.copy();
  }
  stopwatchCopy.stop();
  print('Method 2 (copy): ${stopwatchCopy.elapsedMilliseconds} ms');
  print('  Avg per op: ${(stopwatchCopy.elapsedMicroseconds / iterations).toStringAsFixed(2)} us');

  final ratio = stopwatchFen.elapsedMicroseconds / stopwatchCopy.elapsedMicroseconds;
  print('Improvement: ${ratio.toStringAsFixed(2)}x faster');

  final savingsPerOp = (stopwatchFen.elapsedMicroseconds - stopwatchCopy.elapsedMicroseconds) / iterations;
  print('Time saved per operation: ${savingsPerOp.toStringAsFixed(2)} us');
}
