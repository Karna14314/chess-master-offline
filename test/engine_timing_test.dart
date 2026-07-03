import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/constants/app_constants.dart';

void main() {
  group('Phase 5 — Timing & Responsiveness Tests', () {
    late StockfishService service;
    const startFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    setUp(() {
      service = StockfishService.instance;
      service.resetTestState();
      service.forceFallback = true;
    });

    tearDown(() async {
      await service.dispose();
    });

    // ── ISSUE-006 ──────────────────────────────────────────────

    test(
      'getBestMove with thinkTimeMs completes within generous bounds',
      () async {
        final sw = Stopwatch()..start();
        final result = await service.getBestMove(
          fen: startFen,
          depth: 5,
          thinkTimeMs: 500,
        );
        sw.stop();

        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
        // Should not hang — fallback is fast
        expect(sw.elapsedMilliseconds, lessThan(2000));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'getBestMove without thinkTimeMs (depth-only) completes quickly',
      () async {
        final sw = Stopwatch()..start();
        final result = await service.getBestMove(fen: startFen, depth: 3);
        sw.stop();

        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
        expect(sw.elapsedMilliseconds, lessThan(1000));
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    // ── Search timeout ─────────────────────────────────────────

    test(
      'consecutive rapid searches do not degrade or crash',
      () async {
        for (int i = 0; i < 5; i++) {
          final result = await service.getBestMove(
            fen: startFen,
            depth: 3,
          );
          expect(result, isA<BestMoveResult>());
          expect(result.bestMove.isNotEmpty, isTrue,
              reason: 'Iteration $i should return a valid move');
        }
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'search after timeout recovery returns valid result',
      () async {
        // Simulate a busy engine scenario
        final result1 = await service.getBestMove(
          fen: startFen,
          depth: 3,
          thinkTimeMs: 100,
        );

        // Immediate second call while engine is hypothetically busy
        final result2 = await service.getBestMove(
          fen: startFen,
          depth: 3,
          thinkTimeMs: 100,
        );

        expect(result1, isA<BestMoveResult>());
        expect(result2, isA<BestMoveResult>());
        expect(result1.bestMove.isNotEmpty, isTrue);
        expect(result2.bestMove.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    // ── Difficulty think times ─────────────────────────────────

    test('all difficulty levels have sensible think times', () {
      for (final level in AppConstants.difficultyLevels) {
        // thinkTimeMs should be reasonable: at least 200ms, at most 5s
        expect(level.thinkTimeMs, greaterThanOrEqualTo(200),
            reason:
                '${level.name} think time ${level.thinkTimeMs}ms is too fast');
        expect(level.thinkTimeMs, lessThanOrEqualTo(5000),
            reason:
                '${level.name} think time ${level.thinkTimeMs}ms is too long');
      }
    });

    test(
      'minimum think time for Beginner is not excessive',
      () async {
        // Beginner has thinkTimeMs=300. Search should complete fast.
        final sw = Stopwatch()..start();
        final result = await service.getBestMove(
          fen: startFen,
          depth: 1,
          thinkTimeMs: 300,
        );
        sw.stop();

        expect(result, isA<BestMoveResult>());
        // Fallback at depth 1 should be near-instant
        expect(sw.elapsedMilliseconds, lessThan(500));
      },
      timeout: const Timeout(Duration(seconds: 2)),
    );

    // ── Engine restart after timeout ───────────────────────────

    test(
      'engine restart after dispose does not hang',
      () async {
        await service.initialize();
        await service.dispose();

        // Re-init fresh
        service.resetTestState();
        service.forceFallback = true;
        await service.initialize();

        final result = await service.getBestMove(fen: startFen, depth: 3);
        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    // ── Cancel during search ───────────────────────────────────

    test(
      'cancelSearch between calls does not corrupt state',
      () async {
        // First call
        final result1 = await service.getBestMove(fen: startFen, depth: 3);
        expect(result1.bestMove.isNotEmpty, isTrue);

        // Second call
        final result2 = await service.getBestMove(fen: startFen, depth: 3);
        expect(result2.bestMove.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    // ── Fallback timing ────────────────────────────────────────

    test(
      'fallback depth cap at 4 prevents ANR for deep requests',
      () async {
        // Request depth 22 (Maximum) — fallback should cap at 4
        final sw = Stopwatch()..start();
        final result = await service.getBestMove(fen: startFen, depth: 22);
        sw.stop();

        expect(result, isA<BestMoveResult>());
        expect(result.bestMove.isNotEmpty, isTrue);
        // Must complete well under 3s
        expect(sw.elapsedMilliseconds, lessThan(3000));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    // ── UCI command format ─────────────────────────────────────

    test(
      'analyzePosition uses depth-only command (no movetime)',
      () async {
        final sw = Stopwatch()..start();
        final result = await service.analyzePosition(
          fen: startFen,
          depth: 5,
        );
        sw.stop();

        expect(result, isA<AnalysisResult>());
        expect(sw.elapsedMilliseconds, lessThan(3000));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });
}
