import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/models/chess_models.dart';

void main() {
  group('Engine Initialization Tests', () {
    // Reset singleton state between tests
    setUp(() {
      StockfishService.instance.resetTestState();
    });

    tearDown(() async {
      final service = StockfishService.instance;
      await service.dispose();
    });

    test('should complete initialization without deadlock', () async {
      final service = StockfishService.instance;

      // In test environment Stockfish binary is not available,
      // but init should complete (via fallback) without hanging.
      await service.initialize().timeout(const Duration(seconds: 25));

      // After failed init in test env, the service should be in fallback mode
      expect(service.isReady, true);
      expect(service.isUsingFallback, true);
    });

    test('should handle engine initialization failure gracefully', () async {
      final service = StockfishService.instance;

      // Call methods that should not throw even if engine is not initialized
      service.setSkillLevel(1200);
      service.newGame();
      service.stopAnalysis();

      // Verify service is in valid state
      expect(service, isNotNull);
    });

    test('multiple initialize() calls return same result', () async {
      final service = StockfishService.instance;

      // Fire concurrent initialization requests
      final future1 = service.initialize();
      final future2 = service.initialize();
      final future3 = service.initialize();

      // All should complete without error
      await Future.wait([future1, future2, future3])
          .timeout(const Duration(seconds: 25));

      expect(service.isReady, true);
    });

    test('dispose does not crash after failed init', () async {
      final service = StockfishService.instance;

      await service.initialize().timeout(const Duration(seconds: 25));
      // Dispose is safe even when engine is in fallback state
      await service.dispose();
      // After dispose, _outputController is closed — service is no longer usable
    });

    test('getBestMove initializes engine if not ready', () async {
      final service = StockfishService.instance;

      // This should trigger initialize() internally, then fallback
      final result = await service.getBestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        depth: 3,
      );

      // Should return a valid fallback result without crashing
      expect(result, isA<BestMoveResult>());
      expect(result.bestMove.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('getBestMove returns valid move for both colors', () async {
      final service = StockfishService.instance;

      // White to move
      final whiteResult = await service.getBestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        depth: 3,
      );
      expect(whiteResult.bestMove.length >= 4, isTrue);

      // Black to move
      final blackResult = await service.getBestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        depth: 3,
      );
      expect(blackResult.bestMove.length >= 4, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
