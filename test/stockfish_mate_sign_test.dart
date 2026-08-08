import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

/// Regression tests for "score mate 0" (already-checkmated position) sign.
///
/// Stockfish scores are relative to the side to move. "mate 0" means the side
/// to move is checkmated right now. The white-relative conversion previously
/// lost the sign (`_toWhiteRelative(0) == 0`), so the eval was always -10000
/// regardless of who was actually mated.
///
/// The native Stockfish DLL is not loadable in the test environment, so the
/// service is driven through `setReadyForTesting` + injected output lines.
void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  late StockfishService service;

  setUp(() {
    service = StockfishService.instance;
    service.resetTestState();
    service.setReadyForTesting(immediateReadyOk: true);
    service.searchTimeoutForTesting = const Duration(seconds: 2);
  });

  tearDown(() async {
    await service.dispose();
  });

  Future<void> waitForListener() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  /// Plays the given UCI moves on a real board and returns the FEN of the
  /// resulting checkmate position (side to move == the mated side).
  String mateFen(List<String> uci) {
    final board = chess.Chess.fromFEN(startFen);
    for (final m in uci) {
      board.move({
        'from': m.substring(0, 2),
        'to': m.substring(2, 4),
      });
    }
    expect(board.in_checkmate, isTrue, reason: uci.join(' '));
    return board.fen;
  }

  group('mateToWhiteRelative', () {
    test('mate 0 with white to move (white just got mated) → negative', () {
      expect(service.mateToWhiteRelative(0, '$startFen'), equals(-1));
      // White to move: white is the mated side → white-relative is negative.
      final fen = mateFen(['f2f3', 'e7e5', 'g2g4', 'd8h4']); // Fool's mate
      expect(fen.split(' ')[1], 'w');
      expect(service.mateToWhiteRelative(0, fen), equals(-1));
    });

    test('mate 0 with black to move (black just got mated) → positive', () {
      final fen = mateFen(
        ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ); // Scholar's mate
      expect(fen.split(' ')[1], 'b');
      expect(service.mateToWhiteRelative(0, fen), equals(1));
    });

    test('non-zero mate signs still flip for black side to move', () {
      // White to move, "mate 3" → white mates in 3 → white-relative positive.
      expect(service.mateToWhiteRelative(3, startFen), equals(3));

      // Black to move, "mate 3" → black mates in 3 → white-relative negative.
      final blackToMove = mateFen(
        ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      );
      expect(blackToMove.split(' ')[1], 'b');
      expect(service.mateToWhiteRelative(3, blackToMove), equals(-3));
    });
  });

  group('parse "score mate 0" through analyzePosition', () {
    test('white is mated (Fool is mate) → eval strongly negative', () async {
      final fen = mateFen(['f2f3', 'e7e5', 'g2g4', 'd8h4']);

      final future = service.analyzePosition(fen: fen, depth: 5);
      await waitForListener();
      service.emitEngineLineForTesting('info depth 5 score mate 0 pv f1h3');
      service.emitEngineLineForTesting('bestmove (none)');

      final result = await future.timeout(const Duration(seconds: 5));
      final line = result.lines.first;
      expect(line.isMate, isTrue);
      expect(line.mateIn, isNegative, reason: 'white is the mated side');
      // mate -1 → -10000 + 10 = -9990 centipawns → -99.9 pawns.
      expect(line.evaluation, closeTo(-99.9, 0.1));
      expect(result.evaluation, closeTo(-9990, 10));
    });

    test('black is mated (Scholar is mate) → eval strongly positive',
        () async {
      final fen = mateFen(
        ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      );

      final future = service.analyzePosition(fen: fen, depth: 5);
      await waitForListener();
      service.emitEngineLineForTesting('info depth 5 score mate 0 pv f1h3');
      service.emitEngineLineForTesting('bestmove (none)');

      final result = await future.timeout(const Duration(seconds: 5));
      final line = result.lines.first;
      expect(line.isMate, isTrue);
      expect(line.mateIn, isPositive, reason: 'black is the mated side');
      expect(line.evaluation, closeTo(99.9, 0.1));
      expect(result.evaluation, closeTo(9990, 10));
    });
  });

  group('parse "score mate 0" through getBestMove', () {
    test('white is mated → BestMoveResult carries negative mate/eval',
        () async {
      final fen = mateFen(['f2f3', 'e7e5', 'g2g4', 'd8h4']);

      final future = service.getBestMove(fen: fen, depth: 3);
      await waitForListener();
      service.emitEngineLineForTesting('info depth 3 score mate 0');
      service.emitEngineLineForTesting('bestmove (none)');

      final result = await future.timeout(const Duration(seconds: 5));
      expect(result.mateIn, isNegative);
      // mate -1 → -10000 + 1*10 = -9990 centipawns.
      expect(result.evaluation, equals(-9990));
    });

    test('black is mated → BestMoveResult carries positive mate/eval',
        () async {
      final fen = mateFen(
        ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      );

      final future = service.getBestMove(fen: fen, depth: 3);
      await waitForListener();
      service.emitEngineLineForTesting('info depth 3 score mate 0');
      service.emitEngineLineForTesting('bestmove (none)');

      final result = await future.timeout(const Duration(seconds: 5));
      expect(result.mateIn, isPositive);
      // mate +1 → 10000 - 1*10 = 9990 centipawns.
      expect(result.evaluation, equals(9990));
    });
  });
}
