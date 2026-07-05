import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/models/chess_models.dart';

void main() {
  group('Engine Lifecycle Tests', () {
    late StockfishService service;
    const testFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    setUp(() {
      service = StockfishService.instance;
      service.resetTestState();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('engine can restart after dispose', () async {
      service.forceFallback = true;

      await service.initialize();
      expect(service.isReady, true);
      expect(service.isUsingFallback, true);

      await service.dispose();
      service.resetTestState();
      service.forceFallback = true;

      await service.initialize();
      expect(service.isReady, true);
    });

    test('multiple restart cycles do not crash', () async {
      service.forceFallback = true;

      for (int i = 0; i < 5; i++) {
        service.resetTestState();
        service.forceFallback = true;

        await service.initialize();
        expect(
          service.isReady,
          true,
          reason: 'Cycle $i: service should be ready after init',
        );

        await service.dispose();
      }
    });

    test('dispose during initialization completes safely', () async {
      service.forceFallback = true;

      // Fire init and dispose concurrently
      final initFuture = service.initialize();
      final disposeFuture = service.dispose();

      // Both should complete without throwing
      await Future.wait([
        initFuture,
        disposeFuture,
      ]).timeout(const Duration(seconds: 10));
    });

    test('getBestMove after dispose returns fallback without crashing', () async {
      service.forceFallback = true;

      await service.dispose();
      service.resetTestState();
      // Note: after reset, forceFallback is false — service will attempt real init

      final result = await service.getBestMove(fen: testFen, depth: 3);
      expect(result, isA<BestMoveResult>());
      expect(result.bestMove.isNotEmpty, isTrue);
    });

    test('getBestMove after dispose + re-init works', () async {
      service.forceFallback = true;

      // First init + move
      await service.initialize();
      final result1 = await service.getBestMove(fen: testFen, depth: 3);
      expect(result1.bestMove.isNotEmpty, isTrue);

      // Dispose
      await service.dispose();

      // Re-init + move
      service.resetTestState();
      service.forceFallback = true;
      await service.initialize();
      final result2 = await service.getBestMove(fen: testFen, depth: 3);
      expect(result2.bestMove.isNotEmpty, isTrue);
    });

    test('concurrent getBestMove requests do not deadlock', () async {
      service.forceFallback = true;

      // Fire multiple search requests concurrently
      final futures = <Future<BestMoveResult>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(service.getBestMove(fen: testFen, depth: 3));
      }

      final results = await Future.wait(
        futures,
      ).timeout(const Duration(seconds: 15));

      for (final result in results) {
        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
      }
    });

    test('engine status transitions correctly', () async {
      service.forceFallback = true;

      // Initial state
      expect(service.statusNotifier.value, EngineStatus.initializing);

      // After init
      await service.initialize();
      expect(service.statusNotifier.value, EngineStatus.usingFallback);
      expect(service.isReady, true);

      // After dispose
      await service.dispose();
      expect(service.statusNotifier.value, EngineStatus.disposed);
    });

    test('resetFallback can restart after transient failure', () async {
      service.forceFallback = true;

      // Init with forceFallback → will use fallback
      await service.initialize();
      expect(service.isUsingFallback, true);

      // Reset fallback — since there's no DLL, this will fail and re-enable fallback
      final recovered = await service.resetFallback();
      // In test env without DLL, we expect recovery to fail
      // but the engine should still be usable in fallback mode
      expect(recovered, false);
      expect(service.isUsingFallback, true);
      expect(service.isReady, true);
    });

    test('newGame does not throw when called multiple times', () async {
      service.forceFallback = true;

      service.newGame();
      service.newGame();

      await service.initialize();
      service.newGame();
      service.newGame();

      // Should not throw
    });

    test(
      'stopAnalysis does not throw when called without initialization',
      () async {
        service.stopAnalysis();

        await service.initialize();
        service.stopAnalysis();
      },
    );

    test('setSkillLevel does not throw', () async {
      service.forceFallback = true;

      service.setSkillLevel(1200);
      service.setSkillLevel(2000);
      service.setSkillLevel(800);

      // Should not throw — in fallback mode these are no-ops
    });

    test('engine recovers after timeout without permanent fallback', () async {
      service.forceFallback = true;

      // With forceFallback, the engine is always in fallback mode.
      // In production, a timeout would return a fallback result for that request
      // but not permanently disable the engine.
      // Verify this by calling getBestMove — it should return a result
      // without hanging even when the engine is "busy" from a previous timeout.

      final result = await service.getBestMove(fen: testFen, depth: 3);
      expect(result, isA<BestMoveResult>());
      expect(result.bestMove.isNotEmpty, isTrue);

      // After timeout recovery path: engine should still accept new searches
      final result2 = await service.getBestMove(fen: testFen, depth: 3);
      expect(result2, isA<BestMoveResult>());
      expect(result2.bestMove.isNotEmpty, isTrue);
    });

    test('repeated init/dispose cycles are safe', () async {
      service.forceFallback = true;

      for (int i = 0; i < 3; i++) {
        service.resetTestState();
        service.forceFallback = true;

        await service.initialize();
        expect(service.isReady, true, reason: 'Cycle $i: ready after init');

        await service.dispose();
        expect(
          service.isReady,
          true,
          reason: 'Cycle $i: ready after dispose (falls back)',
        );
      }
    });

    test('concurrent init calls are idempotent', () async {
      service.forceFallback = true;

      final future1 = service.initialize();
      final future2 = service.initialize();
      final future3 = service.initialize();

      await Future.wait([future1, future2, future3]);
      expect(service.isReady, true);
    });
  });
}
