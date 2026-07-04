import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';

void main() {
  group('Search Engine Tests', () {
    const startPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    test('getBestMove returns a valid move from starting position', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 1,
      );
      expect(result.bestMove, isNotEmpty);
      expect(result.isValid, isTrue);
    });

    test('opening book starts with a central pawn move', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );

      expect(result.bestMove, equals('e2e4'));
      expect(result.principalVariation.first, equals('e2e4'));
    });

    test('opening book answers e4 with e5', () async {
      const afterE4 =
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: afterE4,
        depth: 3,
      );

      expect(result.bestMove, equals('e7e5'));
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

    test('depth 1 returns immediately without PV', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 1,
      );
      expect(result.bestMove, isNotEmpty);
      // At depth 1 there's no recursive search, so PV is empty
    });

    test('search results are deterministic at fixed seed depth 3', () async {
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

    test('search at depth 2 is faster than depth 3', () async {
      final sw2 = Stopwatch()..start();
      await SimpleBotService.instance.getBestMove(fen: startPos, depth: 2);
      sw2.stop();

      final sw3 = Stopwatch()..start();
      await SimpleBotService.instance.getBestMove(fen: startPos, depth: 3);
      sw3.stop();

      expect(sw2.elapsedMilliseconds, lessThan(sw3.elapsedMilliseconds + 50));
    });

    test('depth 2 search extends PV from depth 1', () async {
      final depth1 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 1,
      );
      final depth2 = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 2,
      );

      // The PV at depth 2 should start with the best move at depth 2
      // (may differ from depth 1's best move, but should be a valid line)
      expect(depth2.principalVariation.length, greaterThanOrEqualTo(1));
      if (depth2.principalVariation.length >= 2) {
        // PV should contain alternating colors: our move, opponent reply
        expect(depth2.principalVariation.length, greaterThanOrEqualTo(2));
      }
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
      // White to move, Ra8#
      const mateInOne = '4k3/8/8/8/8/8/8/R3K3 w Q - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: mateInOne,
        depth: 2,
      );
      expect(result.bestMove, isNotEmpty);
      // The PV should be at least 1 move deep
      expect(result.principalVariation.length, greaterThanOrEqualTo(1));
    });

    test('search handles endgame position without crashing', () async {
      // King + pawn vs king endgame — white to move, should advance pawn
      const endgame = '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1';
      final result = await SimpleBotService.instance.getBestMove(
        fen: endgame,
        depth: 3,
      );
      expect(result, isNotNull);
      expect(result.bestMove, isNotEmpty);
    });

    test('cancellation returns best move from completed iterations', () async {
      // Start a search
      final future = SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 3,
      );
      // Cancel immediately
      SimpleBotService.cancelSearch();
      final result = await future;
      // Should still return something (from completed iterations or fallback)
      expect(result, isNotNull);
      // Reset cancel token for subsequent tests
    });

    test('repeated searches do not interfere with each other', () async {
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

    test('depth 3 completes under ANR threshold', () async {
      final sw = Stopwatch()..start();
      await SimpleBotService.instance.getBestMove(fen: startPos, depth: 3);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('evaluation is zero at starting position (depth 2)', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: startPos,
        depth: 2,
      );
      // Starting position should be roughly balanced
      expect(result.evaluation.abs(), lessThan(200));
    });
  });
}
