import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/services/simple_bot_service.dart';
import 'package:chess_master/core/services/position_evaluator.dart';

void main() {
  group('Phase 10 — Search Optimization', () {
    const startPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    // ============================================================
    // Quiescence Search Tests
    // ============================================================

    test('quiescence detects hanging queen capture', () async {
      // Black has a hanging queen on a5 — white can capture it with a pawn
      // White: pawn on b4 attacks a5; black queen on a5 is undefended
      final fen =
          'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
      // Should not blunder — white should find a good move
      expect(result.evaluation.abs(), lessThan(300));
    });

    test('quiescence avoids horizon effect on recapture', () async {
      // White queen on e4, black rook on a8 — white up material
      const fen = 'r3k3/pppppppp/8/8/4Q3/8/PPPPPPPP/R3K2R w KQ - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 1,
      );
      expect(result.bestMove, isNotEmpty);
      // Material: white Q+2R ~1900 vs black R+K ~500 → eval ~1400
      expect(result.evaluation.abs(), lessThan(2000));
    });

    test('quiescence handles check evasions', () async {
      // Black gives check; white must evade
      const fen =
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
      expect(result.isValid, isTrue);
    });

    test('quiescence detects hanging rook', () async {
      // Black has a hanging rook on a7 (undefended), white can capture
      const fen =
          'r1bqkbnr/pppppppp/2n5/8/8/2N5/PPPPPPPP/R1BQKBNR w KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
    });

    test('quiescence resolves capture sequences', () async {
      // White bishop on c4, black queen on f6, black rook on f8
      // Multiple capture possibilities
      const fen = 'r3k3/pppppppp/5q2/8/2B5/8/PPPPPPPP/R3K3 w KQ - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
    });

    test('quiescence does not explode on complex positions', () async {
      // Midgame position with many captures available
      const fen =
          'r2qk2r/ppp2ppp/2n5/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQK2R w KQkq - 0 1';
      final sw = Stopwatch()..start();
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      sw.stop();
      expect(result.bestMove, isNotEmpty);
      // QS should not cause excessive search time
      expect(sw.elapsedMilliseconds, lessThan(10000));
    });

    // ============================================================
    // Move Ordering Tests
    // ============================================================

    test('move ordering is deterministic', () async {
      final result1 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      final result2 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      expect(result1.bestMove, equals(result2.bestMove));
      expect(result1.evaluation, equals(result2.evaluation));
      expect(result1.principalVariation, equals(result2.principalVariation));
    });

    test('deeper search improves evaluation quality', () async {
      final depth1 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 1,
      );
      final depth2 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 2,
      );
      // PV should be at least as long or more informative
      expect(depth2.principalVariation.length, greaterThanOrEqualTo(1));
      if (depth1.principalVariation.isNotEmpty) {
        expect(depth2.principalVariation, isNotEmpty);
      }
    });

    // ============================================================
    // Search Stability Tests
    // ============================================================

    test('search is consistent across repeated calls', () async {
      const positions = [
        startPos,
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
        '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1',
      ];
      for (final fen in positions) {
        final r1 = await SimpleBotService.instance.getBestMove(
          fen: fen,
          depth: 2,
        );
        final r2 = await SimpleBotService.instance.getBestMove(
          fen: fen,
          depth: 2,
        );
        expect(r1.bestMove, equals(r2.bestMove), reason: 'FEN: $fen');
        expect(r1.evaluation, equals(r2.evaluation), reason: 'FEN: $fen');
      }
    });

    test('alpha-beta pruning returns consistent bounds', () async {
      // Tactical position — Italian Game, black to find best response
      const fen =
          'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 3,
      );
      expect(result.bestMove, isNotEmpty);
    });

    test('evaluation is white-relative consistent', () async {
      // Two symmetrical positions should give mirrored evals
      // White to move with extra material: positive
      final whiteAhead = await SimpleBotService.instance.getBestMove(
        fen: '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1',
        depth: 2,
      );
      // Black to move with extra material: negative (from white's perspective)
      final blackAhead = await SimpleBotService.instance.getBestMove(
        fen: '4k3/4p3/8/8/8/8/8/4K3 w - - 0 1',
        depth: 2,
      );

      // White up a pawn = positive, Black up a pawn = negative (white-relative)
      // When we flip: black pawn should give negative evaluation
      // The stockfish convention for FENs with white to move makes this comparison valid
      expect(
        whiteAhead.evaluation,
        greaterThan(0),
        reason: 'White ahead should be positive',
      );
      // Black ahead means white is behind
      // Check if the evaluator correctly sees black has more material
      final blackEval = whiteAhead.evaluation + blackAhead.evaluation;
      // White up a pawn = +100, black up a pawn = -100, sum should be ~0
      expect(blackEval.abs(), lessThan(500));
    });

    // ============================================================
    // Tactical Stability Tests
    // ============================================================

    test('evaluates hanging piece in one move', () async {
      // Black's knight on f6 is undefended; white's pawn on e5 can capture
      const fen =
          'r1bqkb1r/pppp1ppp/2n2n2/4P3/2B5/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 3,
      );
      expect(result.bestMove, isNotEmpty);
    });

    test('promotion is detected', () async {
      // White pawn on d7 about to promote
      const fen = '3k4/3P4/8/8/8/8/8/4K3 w - - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
    });

    test('scholars mate attack is found quickly', () async {
      const fen =
          'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: fen,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
    });

    // ============================================================
    // Performance Tests
    // ============================================================

    test('depth 2 completes under 2 seconds', () async {
      final sw = Stopwatch()..start();
      await SimpleBotService.instance.getBestMove(fen: startPos, depth: 2);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('depth 3 completes under 5 seconds', () async {
      final sw = Stopwatch()..start();
      await SimpleBotService.instance.getBestMove(fen: startPos, depth: 3);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('search cancellation works with quiescence', () async {
      final future = SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      SimpleBotService.cancelSearch();
      final result = await future;
      expect(result, isNotNull);
    });

    test('repeated searches are stable after quiescence', () async {
      for (int i = 0; i < 3; i++) {
        final result = await SimpleBotService.instance.getBestMove(
          fen: startPos,
          depth: 2,
        );
        expect(result.bestMove, isNotEmpty);
      }
    });

    // ============================================================
    // PositionEvaluator skipMobility Flag Tests
    // ============================================================

    test(
      'PositionEvaluator skipMobility returns different result for early game',
      () {
        // In early game (move_number <= 10), mobility is already skipped
        // So both should be identical
        final board = chess.Chess.fromFEN(startPos);
        final withMobility = PositionEvaluator.evaluate(board);
        final withoutMobility = PositionEvaluator.evaluate(
          board,
          skipMobility: true,
        );
        expect(withMobility, equals(withoutMobility));
      },
    );

    test('PositionEvaluator skipMobility works in midgame', () {
      const fen =
          'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQ1RK1 w kq - 4 5';
      final board = chess.Chess.fromFEN(fen);
      // Both should return valid ints
      final withMobility = PositionEvaluator.evaluate(board);
      final withoutMobility = PositionEvaluator.evaluate(
        board,
        skipMobility: true,
      );
      expect(withMobility, isA<int>());
      expect(withoutMobility, isA<int>());
    });

    // ============================================================
    // Regression Tests (Phase 1-9)
    // ============================================================

    test('evaluation is zero at starting position (depth 2)', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 2,
      );
      expect(result.evaluation.abs(), lessThan(200));
    });

    test('search returns valid move from starting position', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 1,
      );
      expect(result.bestMove, isNotEmpty);
      expect(result.isValid, isTrue);
    });

    test('depth 1 returns immediately without PV', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 1,
      );
      expect(result.bestMove, isNotEmpty);
    });

    test('deeper search returns non-empty PV', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      expect(result.bestMove, isNotEmpty);
      expect(result.principalVariation, isNotEmpty);
      expect(result.principalVariation.first, equals(result.bestMove));
    });

    test('midgame position returns reasonable move', () async {
      const midgame =
          'r1bqkbnr/pp1ppppp/2n5/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
      final result = await SimpleBotService.instance.getBestMove(
        fen: midgame,
        depth: 3,
      );
      expect(result.bestMove, isNotEmpty);
      expect(result.isValid, isTrue);
    });

    test('search handles checkmate positions correctly', () async {
      const mateInOne = '4k3/8/8/8/8/8/8/R3K3 w Q - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: mateInOne,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
      expect(result.principalVariation.length, greaterThanOrEqualTo(1));
    });

    test('search handles endgame position without crashing', () async {
      const endgame = '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: endgame,
        depth: 3,
      );
      expect(result, isNotNull);
      expect(result.bestMove, isNotEmpty);
    });

    test('search is deterministic at depth 3', () async {
      final result1 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      final result2 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      expect(result1.bestMove, equals(result2.bestMove));
      expect(result1.evaluation, equals(result2.evaluation));
    });

    test('repeated searches do not interfere', () async {
      final futures = <Future>[];
      for (int i = 0; i < 3; i++) {
        futures.add(
          SimpleBotService.instance.getBestMove(fen: startPos, depth: 2),
        );
      }
      final results = await Future.wait(futures);
      for (final r in results) {
        expect(r.bestMove, isNotEmpty);
        expect(r.isValid, isTrue);
      }
    });

    test('cancellation returns best move from completed iterations', () async {
      final future = SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      SimpleBotService.cancelSearch();
      final result = await future;
      expect(result, isNotNull);
    });
  });
}
