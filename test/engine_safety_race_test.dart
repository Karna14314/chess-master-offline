import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/models/chess_models.dart';

/// Phase 1 engine-safety regression tests.
///
/// The native Stockfish DLL is not loadable in the test environment, so the
/// service is driven through `setReadyForTesting` + `emitEngineLineForTesting`
/// (a fake engine). These tests prove the serialized command queue, stop-then
/// await-bestmove, generation tokens and dispose guards keep the engine safe
/// under race sequences that previously produced SIGSEGVs.
void main() {
  const startPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  late StockfishService service;

  setUp(() {
    service = StockfishService.instance;
    service.resetTestState();
  });

  tearDown(() async {
    try {
      await service.dispose();
    } catch (_) {}
    service.resetTestState();
  });

  test(
    'dispose mid-search does not crash and releases the engine',
    () async {
      service.setReadyForTesting(immediateReadyOk: true);
      service.searchTimeoutForTesting = const Duration(milliseconds: 100);

      final future =
          service.getBestMove(fen: startPos, depth: 3, thinkTimeMs: 100);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isEngineBusyForTesting, isTrue);

      // dispose must complete without throwing or hanging while a search is
      // in flight (in test mode the isolate is absent, so _killEngineIfRunning
      // is a no-op; the search still times out and falls back).
      await service.dispose();

      // The in-flight search times out and falls back instead of hanging.
      final result = await future.timeout(const Duration(seconds: 5));
      expect(result, isA<BestMoveResult>());

      // After a dispose + reset, new requests fall back instead of touching
      // a disposed engine.
      service.resetTestState();
      service.forceFallback = true;
      final res = await service.getBestMove(fen: startPos, depth: 1);
      expect(res, isA<BestMoveResult>());
      expect(res.bestMove.isNotEmpty, isTrue);
    },
  );

  test(
    'newGame waits for an in-flight search to complete before resetting',
    () async {
      service.setReadyForTesting(immediateReadyOk: true);
      service.searchTimeoutForTesting = const Duration(seconds: 3);

      final future =
          service.getBestMove(fen: startPos, depth: 3, thinkTimeMs: 100);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isEngineBusyForTesting, isTrue);

      // newGame is serialized behind the in-flight search and must not run
      // until the search releases the engine.
      final newGameFuture = service.newGame();

      service.emitEngineLineForTesting('bestmove e2e4');
      await future.timeout(const Duration(seconds: 5));
      expect(service.isEngineBusyForTesting, isFalse);

      await newGameFuture.timeout(const Duration(seconds: 5));
      expect(service.isEngineBusyForTesting, isFalse);
    },
  );

  test(
    'rapid undo / new-game spam stays stable',
    () async {
      service.forceFallback = true;

      for (var i = 0; i < 50; i++) {
        final moveFuture = service.getBestMove(fen: startPos, depth: 1);
        service.stopAnalysis();
        service.newGame();
        final result = await moveFuture.timeout(const Duration(seconds: 5));
        expect(result, isA<BestMoveResult>());
      }

      // Engine must still be usable after the spam.
      final res = await service.getBestMove(fen: startPos, depth: 1);
      expect(res, isA<BestMoveResult>());
      expect(res.bestMove.isNotEmpty, isTrue);
    },
  );

  test(
    'position request while engine busy falls back instead of blocking',
    () async {
      service.setReadyForTesting(immediateReadyOk: true);
      service.searchTimeoutForTesting = const Duration(milliseconds: 100);

      // Hold the engine busy with an in-flight search.
      final busy =
          service.getBestMove(fen: startPos, depth: 3, thinkTimeMs: 100);
      bool busySeen = false;
      for (var i = 0; i < 100 && !busySeen; i++) {
        if (service.isEngineBusyForTesting) {
          busySeen = true;
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      expect(busySeen, isTrue, reason: 'engine never entered busy state');

      // A concurrent request must not block waiting for the busy engine; it
      // falls back immediately.
      final fallback = service.getBestMove(fen: startPos, depth: 1);
      final fallbackResult = await fallback.timeout(const Duration(seconds: 5));
      expect(fallbackResult, isA<BestMoveResult>());

      // The busy search times out and falls back (its search id was
      // invalidated by the concurrent request, so it completes cancelled).
      await busy.timeout(const Duration(seconds: 5));
      expect(service.isEngineBusyForTesting, isFalse);
    },
  );

  test(
    're-init after dispose works (double init cycle)',
    () async {
      service.forceFallback = true;
      await service.initialize();
      expect(service.isReady, isTrue);
      await service.dispose();
      service.resetTestState();
      service.forceFallback = true;
      await service.initialize();
      expect(service.isReady, isTrue);
      final res = await service.getBestMove(fen: startPos, depth: 1);
      expect(res.bestMove.isNotEmpty, isTrue);
    },
  );
}
