import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

/// Regression tests for the P0-2 listener race in the search pipeline.
///
/// The native Stockfish DLL is not loadable in the test environment, so the
/// service is driven through `setReadyForTesting` + injected output lines.
void main() {
  const startPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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

  /// Starts a search and waits for its listener to be attached before the
  /// caller injects engine output.
  Future<void> waitForListener() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test(
    'bestmove (none) parsed through the service pipeline is flagged no-move',
    () async {
      final future = service.getBestMove(fen: startPos, depth: 3);
      await waitForListener();
      service.emitEngineLineForTesting('bestmove (none)');

      final result = await future.timeout(const Duration(seconds: 5));
      expect(result.isNoMove, isTrue);
      expect(result.isValid, isFalse);
      expect(result.bestMove, '(none)');
      expect(result.parsedMove, ('', '', null));
    },
  );

  test('overlapping getBestMove calls do not cross-contaminate '
      '(second call returns fallback, first keeps its own move)', () async {
    final first = service.getBestMove(fen: startPos, depth: 3);
    final second = service.getBestMove(fen: startPos, depth: 3);

    await waitForListener();
    service.emitEngineLineForTesting('bestmove a2a3');

    final firstResult = await first.timeout(const Duration(seconds: 5));
    final secondResult = await second.timeout(const Duration(seconds: 5));

    // The first call completes with its own injected bestmove.
    expect(firstResult.bestMove, 'a2a3');
    expect(firstResult.isValid, isTrue);

    // The second call is rejected by the busy guard (fallback) and does NOT
    // consume the first search's stale bestmove.
    expect(secondResult, isA<BestMoveResult>());
    expect(secondResult.bestMove, isNotEmpty);
  });

  test('a stale bestmove line does not corrupt the next search', () async {
    // First search completes with its own move.
    final first = service.getBestMove(fen: startPos, depth: 3);
    await waitForListener();
    service.emitEngineLineForTesting('bestmove a2a3');
    final firstResult = await first.timeout(const Duration(seconds: 5));
    expect(firstResult.bestMove, 'a2a3');

    // A late/duplicate bestmove arrives with no live search — it must be
    // ignored and must not be replayed to the next search.
    service.emitEngineLineForTesting('bestmove b2b3');

    final second = service.getBestMove(fen: startPos, depth: 3);
    await waitForListener();
    service.emitEngineLineForTesting('bestmove c2c4');
    final secondResult = await second.timeout(const Duration(seconds: 5));

    expect(secondResult.bestMove, 'c2c4');
    expect(secondResult.bestMove, isNot('b2b3'));
    expect(secondResult.bestMove, isNot('a2a3'));
  });

  test('overlapping analyzePosition calls do not hang', () async {
    final first = service.analyzePosition(fen: startPos, depth: 5);
    final second = service.analyzePosition(fen: startPos, depth: 5);

    await waitForListener();
    service.emitEngineLineForTesting('bestmove d2d4');

    final firstResult = await first.timeout(const Duration(seconds: 5));
    final secondResult = await second.timeout(const Duration(seconds: 5));

    expect(firstResult, isA<AnalysisResult>());
    expect(secondResult, isA<AnalysisResult>());
  });

  test('completed search leaves no leaked output listener', () async {
    final future = service.getBestMove(fen: startPos, depth: 3);
    await waitForListener();
    service.emitEngineLineForTesting('bestmove e2e4');
    await future.timeout(const Duration(seconds: 5));

    expect(service.hasOutputListenersForTesting, isFalse);
  });
}
