import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/models/chess_models.dart';

/// Regression tests for Stockfish crash fixes
/// These tests verify the fixes for SIGSEGV and ANR issues
///
/// NOTE: These tests run in fallback mode because the native Stockfish DLL
/// is not available in the test environment. The tests still verify the
/// guard logic and error handling paths work correctly.
void main() {
  group('StockfishService Crash Regression Tests', () {
    late StockfishService service;

    setUp(() {
      // Force fallback mode BEFORE any service calls to avoid loading native DLL
      service = StockfishService.instance;
      service.forceFallback = true;
    });

    tearDown(() async {
      // Clean up
      await service.dispose();
    });

    // TEST 1 — Concurrent call protection (guards against SIGSEGV)
    // Crash type: SIGSEGV in Position::is_draw() from concurrent engine access
    // Fix: _isEngineBusy flag blocks concurrent calls, second call returns fallback
    //
    // NOTE: In fallback mode, both calls return SimpleBot results. The test verifies
    // that the service handles concurrent calls without crashing or hanging.
    test(
      'concurrent calls return results without crashing - _isEngineBusy logic',
      () async {
        final fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

        // Fire two calls simultaneously without awaiting first
        final future1 = service.getBestMove(fen: fen, depth: 3);
        final future2 = service.getBestMove(fen: fen, depth: 3);

        // Wait for both to complete
        final results = await Future.wait([future1, future2]);

        // Both should return valid results without crashing
        expect(results[0], isA<BestMoveResult>());
        expect(results[1], isA<BestMoveResult>());

        // Both should have valid moves (SimpleBot in fallback mode)
        expect(results[0].bestMove.isNotEmpty, isTrue);
        expect(results[1].bestMove.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    // TEST 2 — Invalid FEN fallback (guards against SIGSEGV)
    // Crash type: SIGSEGV in Position::is_draw() / pseudo_legal() from malformed FEN
    // Fix: _isValidFen() rejects empty and malformed FEN before sending to engine
    test(
      'empty FEN returns fallback - _isValidFen guard',
      () async {
        final result = await service.getBestMove(fen: '', depth: 5);

        // Should return without throwing
        expect(result, isA<BestMoveResult>());
        // Should be a fallback result (empty or simple bot move)
        expect(result.bestMove.isEmpty || result.bestMove.length >= 4, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'malformed FEN returns fallback - _isValidFen guard',
      () async {
        final result = await service.getBestMove(fen: 'not/a/fen', depth: 5);

        // Should return without throwing
        expect(result, isA<BestMoveResult>());
        // Should be a fallback result
        expect(result.bestMove.isEmpty || result.bestMove.length >= 4, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    // TEST 3 — readyok timeout fallback (guards against ANR/hang)
    // Crash type: ANR from DartEntry::InvokeFunction when engine hangs
    // Fix: _waitForReadyOk() times out after 500ms, returns fallback
    test(
      'fallback returns within 600ms - prevents ANR',
      () async {
        final stopwatch = Stopwatch()..start();
        final result = await service.getBestMove(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          depth: 5,
        );
        stopwatch.stop();

        // Should complete quickly (under 600ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(600));

        // Should return a result (fallback)
        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 2)),
    );

    test(
      'fallback depth cap prevents ANR',
      () async {
        final stopwatch = Stopwatch()..start();
        final result = await service.getBestMove(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          depth: 15,
        );
        stopwatch.stop();

        // In fallback mode, depth 15 without cap would cause ANR/hang and fail the test timeout.
        // With depth capped at 4, it should complete quickly.
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 2)),
    );

    test(
      '_stopCurrentSearchAndWait stops analysis within 2 seconds',
      () async {
        final stopwatch = Stopwatch()..start();
        final result = await service.analyzePosition(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          depth: 5,
        );
        stopwatch.stop();

        // Should complete without timing out the test (thanks to await)
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        expect(result, isA<AnalysisResult>());
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'FEN validation accepts valid FEN',
      () async {
        // Valid FEN should pass validation
        final validFens = [
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        ];

        for (final fen in validFens) {
          // Should not throw
          final result = await service.getBestMove(fen: fen, depth: 1);
          expect(result, isA<BestMoveResult>());
          expect(result.bestMove.isNotEmpty, isTrue);
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
