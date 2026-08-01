import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

/// P2 regression tests: every `_outputController` subscription must be
/// cancelled on every exit path (timeout, error, early-return) so broadcast
/// listeners never leak. The native Stockfish DLL is not loadable in tests, so
/// the service is driven through `setReadyForTesting` + injected timeouts.
void main() {
  const startPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  late StockfishService service;

  setUp(() {
    service = StockfishService.instance;
    service.resetTestState();
  });

  tearDown(() async {
    await service.dispose();
  });

  test('search timeout leaves zero listeners and does not wedge the engine',
      () async {
    service.setReadyForTesting(immediateReadyOk: true);
    service.searchTimeoutForTesting = const Duration(milliseconds: 50);

    final result = await service
        .getBestMove(fen: startPos, depth: 3, thinkTimeMs: 10)
        .timeout(const Duration(seconds: 10));

    expect(result, isA<BestMoveResult>());
    expect(result.bestMove, isNotEmpty);
    expect(service.hasOutputListenersForTesting, isFalse);
    expect(service.isEngineBusyForTesting, isFalse);
  });

  test('ready-ok timeout leaves zero listeners on the output stream', () async {
    service.setReadyForTesting(immediateReadyOk: false);
    service.searchTimeoutForTesting = const Duration(seconds: 5);

    // No "readyok" is ever emitted, so the position-ready wait times out and
    // the call falls back — proving the _waitForReadyOk subscription is
    // cancelled even on the timeout path.
    final result = await service
        .getBestMove(fen: startPos, depth: 3, thinkTimeMs: 10)
        .timeout(const Duration(seconds: 10));

    expect(result, isA<BestMoveResult>());
    expect(result.bestMove, isNotEmpty);
    expect(service.hasOutputListenersForTesting, isFalse);
    expect(service.isEngineBusyForTesting, isFalse);
  });

  test('analysis timeout leaves zero listeners and does not wedge the engine',
      () async {
    service.setReadyForTesting(immediateReadyOk: true);
    service.analysisTimeoutForTesting = const Duration(milliseconds: 50);

    final result = await service
        .analyzePosition(fen: startPos, depth: 5)
        .timeout(const Duration(seconds: 10));

    expect(result, isA<AnalysisResult>());
    expect(service.hasOutputListenersForTesting, isFalse);
    expect(service.isEngineBusyForTesting, isFalse);
  });

  test('20× forced timeouts leak no listeners and never crash', () async {
    service.setReadyForTesting(immediateReadyOk: true);
    service.searchTimeoutForTesting = const Duration(milliseconds: 20);

    for (var i = 0; i < 20; i++) {
      final result = await service
          .getBestMove(fen: startPos, depth: 3, thinkTimeMs: 10)
          .timeout(const Duration(seconds: 10));
      expect(result, isA<BestMoveResult>());
      expect(result.bestMove, isNotEmpty);
      expect(
        service.hasOutputListenersForTesting,
        isFalse,
        reason: 'iteration $i leaked an output listener',
      );
      expect(
        service.isEngineBusyForTesting,
        isFalse,
        reason: 'iteration $i left the engine busy/wedged',
      );
    }
  });
}
